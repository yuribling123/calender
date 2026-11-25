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

    @AppStorage("icloudEnableFailurePending") private var isICloudFailurePending = false
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @State private var requestedCalendarMonth: Date?
    @State private var isGuidePresented = false
    @State private var isGuidePending = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        let schema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self, CalendarAppearanceSelection.self])
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
            CalendarAppearanceContent(hasMembershipAccess: membershipStore.hasMembershipAccess) { theme in
                tabs(theme: theme)
            }
        }
        .modelContainer(container)
    }

    private func tabs(theme: AppTheme) -> some View {
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
            .foregroundStyle(.primary)
            .accessibilityHidden(isGuidePresented || shouldShowReleaseHighlights)
            .overlay {
                if isGuidePresented {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            Text(localized("这样翻翻日历"))
                                .font(.headline)
                                .foregroundStyle(theme == .black ? Color.white : theme.palette.onStrongAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 24)
                                .background(theme == .black ? theme.palette.selectionFill : theme.palette.todayButtonFill)
                                .accessibilityAddTraits(.isHeader)

                            VStack(alignment: .leading, spacing: 20) {
                                guideRow("Ⅰ", text: localized("点顶部年份，可切换年份"))
                                guideRow("Ⅱ", text: localized("手指在日历上左右滑动，切换月份"))
                                guideRow("Ⅲ", text: localized("点日历中今天的日期，记录今日份"))
                            }
                            .font(.subheadline)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 26)
                            .padding(.bottom, 24)

                            Button {
                                UserDefaults.standard.set(true, forKey: guideKey)
                                isGuidePresented = false
                            } label: {
                                Text(localized("知道了"))
                                    .font(.headline)
                                    .foregroundStyle(theme == .black ? Color.white : theme.palette.onStrongAccent)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 44)
                                    .background(theme == .black ? theme.palette.selectionFill : theme.palette.todayButtonFill, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                        .frame(maxWidth: 340)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24)
                        .accessibilityAddTraits(.isModal)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isGuidePresented)
            .overlay {
                if shouldShowReleaseHighlights {
                    ReleaseHighlightsOverlay(
                        release: .current,
                        theme: theme
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
                if !DemoData.isEnabled {
                    try? await MainActor.run {
                        try CalendarAppearanceStore(context: container.mainContext).migrateLegacySelections()
                    }
                }
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
                        isGuidePending = true
                    }
                }
            }
            .task(id: canCheckForUpdates) {
                guard canCheckForUpdates else { return }
                // Allow the last onboarding overlay to finish disappearing.
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                guard canCheckForUpdates, !Task.isCancelled else { return }
                await updateChecker.checkIfNeeded()
            }
            .task(id: isGuidePending && isStartupReady && scenePhase == .active && !updateChecker.isChecking) {
                guard isGuidePending, isStartupReady, scenePhase == .active, !updateChecker.isChecking else { return }
                // Present onboarding independently of network availability.
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                isGuidePending = false
                isGuidePresented = true
            }
            .alert(localized("有新版本啦"), isPresented: Binding(
                get: {
                    isStartupReady && updateChecker.availableUpdate != nil && !isGuidePresented && !isGuidePending
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

    private var canCheckForUpdates: Bool {
        isStartupReady && scenePhase == .active && !isGuidePending && !isGuidePresented
            && !shouldShowReleaseHighlights && !isICloudFailurePending
    }

    private var shouldShowReleaseHighlights: Bool {
        isStartupReady
            && !DemoData.isEnabled
            && !isGuidePresented
            && !isGuidePending
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

private struct CalendarAppearanceContent<Content: View>: View {
    @Query private var selections: [CalendarAppearanceSelection]
    let hasMembershipAccess: Bool
    @ViewBuilder let content: (AppTheme) -> Content

    var body: some View {
        let values = CalendarAppearanceStore.latestValues(in: selections)
        let selectedTheme = values[CalendarAppearanceKey.theme.rawValue].flatMap(AppTheme.init(rawValue:))
        let selectedShape = values[CalendarAppearanceKey.shape.rawValue].flatMap(SelectionShape.init(rawValue:))
        let theme = selectedTheme.flatMap { hasMembershipAccess || !$0.requiresMembership ? $0 : nil }
            ?? .defaultTheme
        let shape = selectedShape.flatMap { hasMembershipAccess || !$0.requiresMembership ? $0 : nil }
            ?? .defaultShape
        let bookmarkStyle = values[CalendarAppearanceKey.bookmark.rawValue]
            .flatMap(CalendarBookmarkStyle.init(rawValue:)) ?? .dateColor
        content(theme)
            .environment(\.appTheme, theme)
            .environment(\.selectionShape, shape)
            .environment(\.calendarBookmarkStyle, bookmarkStyle)
            .tint(theme.palette.strongAccent)
    }
}
