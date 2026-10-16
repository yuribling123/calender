import SwiftUI
import SwiftData
import UIKit

@main
struct MoodCalendarApp: App {
    @StateObject private var membershipStore = MembershipStore()
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.circle.rawValue

    @AppStorage("icloudEnableFailurePending") private var isICloudFailurePending = false
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @State private var requestedCalendarMonth: Date?
    @State private var isGuidePresented = false

    private var guideKey: String { DemoData.isEnabled ? "demoHasSeenGuide" : "hasSeenGuide" }

    init() {
        AppLanguage.prepareSelection()
        let tabBar = UITabBar.appearance()
        let appearance = tabBar.standardAppearance.copy() as! UITabBarAppearance
        appearance.selectionIndicatorTintColor = UIColor.black.withAlphaComponent(0.035)
        tabBar.standardAppearance = appearance
        let scrollAppearance = (tabBar.scrollEdgeAppearance ?? appearance).copy() as! UITabBarAppearance
        scrollAppearance.selectionIndicatorTintColor = appearance.selectionIndicatorTintColor
        tabBar.scrollEdgeAppearance = scrollAppearance
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
        #if DEBUG
        let useInMemoryStore = DemoData.isEnabled
        #else
        let useInMemoryStore = false
        #endif
        #if ICLOUD_SYNC_ENABLED
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: useInMemoryStore,
            cloudKitDatabase: useCloudKit ? .private("iCloud.com.qingqing.MoodCalendar") : .none
        )
        #else
        return ModelConfiguration(schema: schema, isStoredInMemoryOnly: useInMemoryStore, cloudKitDatabase: .none)
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
                    .tabItem {
                        Label(localized("我的"), systemImage: "person.crop.circle")
                            .environment(\.symbolVariants, .none)
                    }
            }
                .id(storedLanguage)
                .environment(\.locale, AppLanguage.locale)
                .environmentObject(membershipStore)
                .environment(\.appTheme, AppTheme(rawValue: storedTheme) ?? .pink)
                .environment(\.selectionShape, SelectionShape(rawValue: storedSelectionShape) ?? .circle)
                .tint((AppTheme(rawValue: storedTheme) ?? .pink).palette.strongAccent)
                .alert(localized("这样翻翻日历"), isPresented: $isGuidePresented) {
                    Button(localized("知道了")) {
                        UserDefaults.standard.set(true, forKey: guideKey)
                    }
                } message: {
                    Text([
                        localized("用手指在日历上左右滑动，切换月份"),
                        localized("点顶部年份，可切换年份"),
                        localized("点日历中今天的日期，记录今日份")
                    ].joined(separator: "\n\n"))
                }
                .alert(localized("未能开启 iCloud 同步"), isPresented: $isICloudFailurePending) {
                    Button(localized("确定"), role: .cancel) { isICloudFailurePending = false }
                } message: {
                    Text(localized("这次未能开启同步，记录仍保存在本机。可以稍后在「我的」重新开启 iCloud 同步。"))
                }
                .task {
                    try? await MainActor.run { try prepareStore() }
                    let entries = (try? container.mainContext.fetch(FetchDescriptor<MoodEntry>())) ?? []
                    await DailyFragmentReminder.refresh(
                        recordedDayKeys: Set(entries.compactMap { $0.choice == nil ? nil : $0.dayKey }),
                        isEnabled: UserDefaults.standard.object(forKey: "dailyReminderEnabled") as? Bool ?? true
                    )
                    try? await MainActor.run {
                        guard !UserDefaults.standard.bool(forKey: guideKey) else { return }
                        let context = container.mainContext
                        let hasRecords = try context.fetchCount(FetchDescriptor<MoodEntry>()) > 0
                            || context.fetchCount(FetchDescriptor<MonthlyNote>()) > 0
                        if hasRecords && !DemoData.isEnabled {
                            UserDefaults.standard.set(true, forKey: guideKey)
                        } else {
                            isGuidePresented = true
                        }
                    }
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
