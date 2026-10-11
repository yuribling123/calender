import SwiftUI
import SwiftData

@main
struct MoodCalendarApp: App {
    @StateObject private var membershipStore = MembershipStore()
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.circle.rawValue

    @AppStorage("icloudEnableFailurePending") private var isICloudFailurePending = false
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @State private var requestedCalendarMonth: Date?

    init() {
        AppLanguage.prepareSelection()
    }

    private let container: ModelContainer = {
        let schema = Schema([MoodEntry.self, MonthlyNote.self])
        #if ICLOUD_SYNC_ENABLED
        let cloudSyncWasRequested = !DemoData.isEnabled
            && UserDefaults.standard.bool(forKey: "icloudSyncEnabled")

        do {
            let configuration = modelConfiguration(schema: schema, useCloudKit: cloudSyncWasRequested)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            guard cloudSyncWasRequested else {
                fatalError("Unable to create the mood store: \(error)")
            }

            UserDefaults.standard.set(false, forKey: "icloudSyncEnabled")
            UserDefaults.standard.set(true, forKey: "icloudEnableFailurePending")
            do {
                let localConfiguration = modelConfiguration(schema: schema, useCloudKit: false)
                return try ModelContainer(for: schema, configurations: localConfiguration)
            } catch {
                fatalError("Unable to create the local mood store: \(error)")
            }
        }
        #else
        // Personal Team testing: retain the same local store, without CloudKit.
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration(schema: schema, useCloudKit: false))
        } catch {
            fatalError("Unable to create the mood store: \(error)")
        }
        #endif
    }()

    private static func modelConfiguration(schema: Schema, useCloudKit: Bool) -> ModelConfiguration {
        #if ICLOUD_SYNC_ENABLED
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: DemoData.isEnabled,
            cloudKitDatabase: useCloudKit ? .private("iCloud.com.qingqing.MoodCalendar") : .none
        )
        #else
        return ModelConfiguration(schema: schema, isStoredInMemoryOnly: DemoData.isEnabled, cloudKitDatabase: .none)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CalendarScreen(requestedMonth: $requestedCalendarMonth)
                    .tag(0)
                    .tabItem { Label(localized("日历"), systemImage: "calendar") }
                MonthlyGoalScreen(onOpenMonth: { date in
                    requestedCalendarMonth = date
                    selectedTab = 0
                })
                    .tag(1)
                    .tabItem { Label(localized("月便签"), systemImage: "note.text") }
                PersonalizationScreen()
                    .tag(2)
                    .tabItem { Label(localized("我的"), systemImage: "person.crop.circle") }
            }
                .id(storedLanguage)
                .environment(\.locale, AppLanguage.locale)
                .environmentObject(membershipStore)
                .environment(\.appTheme, AppTheme(rawValue: storedTheme) ?? .pink)
                .environment(\.selectionShape, SelectionShape(rawValue: storedSelectionShape) ?? .circle)
                .tint((AppTheme(rawValue: storedTheme) ?? .pink).palette.strongAccent)
                .alert(localized("未能开启 iCloud 同步"), isPresented: $isICloudFailurePending) {
                    Button(localized("确定"), role: .cancel) { isICloudFailurePending = false }
                } message: {
                    Text(localized("这次未能开启同步，记录仍保存在本机。可以稍后在「我的」重新开启 iCloud 同步。"))
                }
                .task {
                    try? await MainActor.run { try prepareStore() }
                }
        }
        .modelContainer(container)
    }

    @MainActor
    private func prepareStore() throws {
        let context = container.mainContext
        #if DEBUG
        if DemoData.isEnabled {
            try DemoData.seed(into: context)
            return
        }
        #endif
        try MonthlyNoteStore(context: context).migrateLegacyNotes()
        try EntryStore(context: context).reconcileDuplicates()
        try MonthlyNoteStore(context: context).reconcileDuplicates()
    }
}
