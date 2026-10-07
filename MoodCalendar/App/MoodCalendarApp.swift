import SwiftUI
import SwiftData

@main
struct MoodCalendarApp: App {
    @StateObject private var membershipStore = MembershipStore()
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.heart.rawValue

    private let container: ModelContainer = {
        let schema = Schema([MoodEntry.self, MonthlyNote.self])
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
            do {
                let localConfiguration = modelConfiguration(schema: schema, useCloudKit: false)
                return try ModelContainer(for: schema, configurations: localConfiguration)
            } catch {
                fatalError("Unable to create the local mood store: \(error)")
            }
        }
    }()

    private static func modelConfiguration(schema: Schema, useCloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: DemoData.isEnabled,
            cloudKitDatabase: useCloudKit ? .private("iCloud.com.qingqing.MoodCalendar") : .none
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                CalendarScreen()
                    .tabItem { Label("日历", systemImage: "calendar") }
                MonthlyGoalScreen()
                    .tabItem { Label("月便签", systemImage: "note.text") }
                PersonalizationScreen()
                    .tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
                .environmentObject(membershipStore)
                .environment(\.appTheme, AppTheme(rawValue: storedTheme) ?? .pink)
                .environment(\.selectionShape, SelectionShape(rawValue: storedSelectionShape) ?? .heart)
                .tint((AppTheme(rawValue: storedTheme) ?? .pink).palette.strongAccent)
                .task {
                    #if DEBUG
                    if DemoData.isEnabled {
                        try? await MainActor.run { try DemoData.seed(into: container.mainContext) }
                    } else {
                        try? await MainActor.run {
                            let context = container.mainContext
                            try MonthlyNoteStore(context: context).migrateLegacyNotes()
                            try EntryStore(context: context).reconcileDuplicates()
                            try MonthlyNoteStore(context: context).reconcileDuplicates()
                        }
                    }
                    #else
                    try? await MainActor.run {
                        let context = container.mainContext
                        try MonthlyNoteStore(context: context).migrateLegacyNotes()
                        try EntryStore(context: context).reconcileDuplicates()
                        try MonthlyNoteStore(context: context).reconcileDuplicates()
                    }
                    #endif
                }
        }
        .modelContainer(container)
    }
}
