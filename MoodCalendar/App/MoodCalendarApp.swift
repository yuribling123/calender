import SwiftUI
import SwiftData
import UIKit

@main
struct MoodCalendarApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var updateChecker = AppUpdateChecker()
    @StateObject private var membershipStore = MembershipStore()
    @StateObject private var futureLetterStore = FutureLetterStore(isInMemory: DemoData.isEnabled)
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.circle.rawValue

    @AppStorage("icloudEnableFailurePending") private var isICloudFailurePending = false
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @State private var requestedCalendarMonth: Date?
    @State private var isGuidePresented = false
    @State private var isStartupReady = false
    @AppStorage("lastSeenReleaseHighlightsID") private var lastSeenReleaseHighlightsID = ""

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
        let schema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self])
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
                CollectionScreen(onOpenDay: { date in
                    requestedCalendarMonth = date
                    selectedTab = 0
                })
                    .tag(2)
                    .tabItem { Label(localized("收藏"), systemImage: "square.grid.2x2") }
                PersonalizationScreen()
                    .tag(3)
                    .tabItem {
                        Label(localized("我的"), systemImage: "person.crop.circle")
                            .environment(\.symbolVariants, .none)
                    }
            }
                .id(storedLanguage)
                .environment(\.locale, AppLanguage.locale)
                .environmentObject(membershipStore)
                .environmentObject(futureLetterStore)
                .environment(\.appTheme, AppTheme(rawValue: storedTheme) ?? .pink)
                .environment(\.selectionShape, SelectionShape(rawValue: storedSelectionShape) ?? .circle)
                .tint((AppTheme(rawValue: storedTheme) ?? .pink).palette.strongAccent)
                .foregroundStyle(.primary)
                .accessibilityHidden(isGuidePresented || shouldShowReleaseHighlights)
                .overlay {
                    if isGuidePresented {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            VStack(spacing: 20) {
                                Text(localized("这样翻翻日历"))
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)

                                VStack(alignment: .leading, spacing: 16) {
                                    guideRow("Ⅰ", text: localized("用手指在日历上左右滑动，切换月份"))
                                    guideRow("Ⅱ", text: localized("点顶部年份，可切换年份"))
                                    guideRow("Ⅲ", text: localized("点日历中今天的日期，记录今日份"))
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button(localized("知道了")) {
                                    UserDefaults.standard.set(true, forKey: guideKey)
                                    isGuidePresented = false
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .padding(24)
                            .frame(maxWidth: 340)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 24)
                            .accessibilityAddTraits(.isModal)
                        }
                    }
                }
                .overlay {
                    if shouldShowReleaseHighlights {
                        ReleaseHighlightsOverlay(
                            release: .current,
                            theme: AppTheme(rawValue: storedTheme) ?? .pink
                        ) {
                            lastSeenReleaseHighlightsID = ReleaseHighlights.current.id
                        }
                    }
                }
                .alert(localized("未能开启 iCloud 同步"), isPresented: $isICloudFailurePending) {
                    Button(localized("确定"), role: .cancel) { isICloudFailurePending = false }
                } message: {
                    Text(localized("这次未能开启同步，记录仍保存在本机。可以稍后在「我的」重新开启 iCloud 同步。"))
                }
                .task {
                    defer { isStartupReady = true }
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
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await updateChecker.checkIfNeeded()
                }
                .alert(localized("有新版本啦"), isPresented: Binding(
                    get: {
                        isStartupReady && updateChecker.availableUpdate != nil && !isGuidePresented
                            && !isICloudFailurePending && !shouldShowReleaseHighlights
                    },
                    set: { if !$0 { updateChecker.availableUpdate = nil } }
                ), presenting: updateChecker.availableUpdate) { update in
                    Button(localized("前往更新")) {
                        if let url = update.productURL { openURL(url) }
                    }
                    Button(localized("稍后"), role: .cancel) { updateChecker.dismiss(update) }
                }
        }
        .modelContainer(container)
    }

    private var shouldShowReleaseHighlights: Bool {
        isStartupReady
            && !DemoData.isEnabled
            && !isGuidePresented
            && !isICloudFailurePending
            && !ReleaseHighlights.current.pages.isEmpty
            && lastSeenReleaseHighlightsID != ReleaseHighlights.current.id
    }

    private func guideRow(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .frame(width: 20, alignment: .leading)
                .accessibilityHidden(true)
            Text(text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        try StarredDayPersistence(context: context).migrateLegacySelections()
        try MonthlyNoteStore(context: context).migrateLegacyNotes()
        try EntryStore(context: context).reconcileDuplicates()
        try MonthlyNoteStore(context: context).reconcileDuplicates()
        try MonthlyNoteSkinStore(context: context).migrateLegacySelections()
        try MonthlyNoteSkinStore(context: context).reconcileDuplicates()
    }
}
