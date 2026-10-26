import SwiftUI
import SwiftData
import UIKit

struct CalendarScreen: View {
    @Binding var requestedMonth: Date?
    var initialDate: Date? = nil
    var isSearchDestination = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.selectionShape) private var selectionShape
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @AppStorage("dailyReminderEnabled") private var isDailyReminderEnabled = true
    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @AppStorage("showMonthArrows") private var showMonthArrows = true
    @AppStorage("starredDays.v1") private var storedStarredDays = "[]"
    @State private var demoStarredDays: Set<String> = []
    @Query private var entries: [MoodEntry]
    @GestureState private var isHorizontalMonthSwipe = false
    @State private var displayedMonth = MonthLayout(containing: Date()).monthStart
    @State private var selectedDay = Date()
    @State private var lastObservedToday = DayKey(Date())
    @State private var lastObservedTimeZoneID = TimeZone.current.identifier
    @State private var midnightTimer: Timer?
    @State private var isChoosingMonth = false
    @State private var chooserYear = Calendar.current.component(.year, from: Date())
    @State private var isEditorPresented = false
    @State private var editorInitialGroup: ChoiceGroup = .mood
    @State private var editingDayKey: String?
    @State private var editingChoiceRawValue: Int?
    @State private var pendingSaveFeedback = false
    @State private var pendingRevealDayKey: String?
    @State private var animatedDayKey: String?
    @State private var saveError: String?
    @State private var searchPath: [SearchRoute] = []
    @State private var isSearchPresented = false
    @State private var didOpenInitialDate = false

    private enum SearchRoute: Hashable {
        case day(Date)
        case month(Date)
    }

    private var calendar: Calendar { .autoupdatingCurrent }

    private var selectedEntry: MoodEntry? {
        let key = DayKey(selectedDay).storageValue
        return entriesByDay[key]
    }

    private var entriesByDay: [String: MoodEntry] {
        Dictionary(grouping: entries, by: \.dayKey).compactMapValues { dayEntries in
            dayEntries.max { $0.updatedAt < $1.updatedAt }
        }
    }

    private var starredDayKeys: Set<String> {
        DemoData.isEnabled ? demoStarredDays : StarredDayStore.decode(storedStarredDays)
    }

    private func toggleSelectedDayStar() {
        let day = DayKey(selectedDay)
        guard StarredDayStore.canToggle(day, allowPastDates: allowPastDateEditing) else { return }
        let key = day.storageValue
        if DemoData.isEnabled {
            if !demoStarredDays.insert(key).inserted { demoStarredDays.remove(key) }
        } else {
            storedStarredDays = StarredDayStore.toggling(day, in: storedStarredDays, allowPastDates: allowPastDateEditing)
        }
    }

    private var recordedDayKeys: Set<String> {
        Set(entries.filter { $0.choice != nil }.map(\.dayKey))
    }

    var body: some View {
        if isSearchDestination {
            calendarContent
        } else {
            NavigationStack(path: $searchPath) {
                calendarContent
                    .navigationDestination(for: SearchRoute.self) { route in
                        switch route {
                        case .day(let date):
                            CalendarScreen(requestedMonth: .constant(nil), initialDate: date, isSearchDestination: true)
                        case .month(let date):
                            MonthlyGoalScreen(
                                onOpenMonth: { date in
                                    if !searchPath.isEmpty { searchPath.removeLast() }
                                    searchPath.append(.day(date))
                                },
                                initialMonth: date,
                                isSearchDestination: true
                            )
                        }
                    }
            }
            .allowsHitTesting(!isSearchPresented || !searchPath.isEmpty)
            .accessibilityHidden(isSearchPresented && searchPath.isEmpty)
            .overlay {
                if isSearchPresented {
                    // Keep the notebook mounted while a result is open so returning
                    // restores both the search text and its place on the page.
                    RecordSearchScreen(starredDayKeys: starredDayKeys, onClose: { isSearchPresented = false }) { result in
                        searchPath.append(result.source == .day ? .day(result.date) : .month(result.date))
                    }
                    .opacity(searchPath.isEmpty ? 1 : 0)
                    .allowsHitTesting(searchPath.isEmpty)
                    .accessibilityHidden(!searchPath.isEmpty)
                }
            }
            .toolbar(isSearchPresented ? .hidden : .visible, for: .tabBar)
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 0) {
            if isSearchDestination {
                SearchReturnButton()
                    .padding(.horizontal, 24)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                        .padding(.bottom, 4)
                    if isChoosingMonth {
                        monthChooser
                    } else {
                        monthHeader
                            .padding(.bottom, 22)
                            .contentShape(Rectangle())
                            .simultaneousGesture(monthSwipeGesture)
                        MonthGrid(
                            layout: MonthLayout(containing: displayedMonth),
                            entries: entriesByDay,
                            starredDayKeys: starredDayKeys,
                            selectedDay: DayKey(selectedDay),
                            pendingRevealDayKey: pendingRevealDayKey,
                            animatingDayKey: animatedDayKey,
                            onSelect: { date in
                                guard calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) else {
                                    return
                                }
                                selectedDay = date
                                if DayKey(date).relationToToday == .today {
                                    let key = DayKey(date).storageValue
                                    guard entriesByDay[key]?.choice == nil else { return }
                                    presentEditor(for: date, group: .mood)
                                }
                            }
                        )
                        .padding(.horizontal, -12)
                        .offset(y: -8)
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                        .simultaneousGesture(monthSwipeGesture)
                        SelectedDateDetail(
                            date: selectedDay,
                            entry: selectedEntry,
                            isStarred: starredDayKeys.contains(DayKey(selectedDay).storageValue),
                            onToggleStar: toggleSelectedDayStar,
                            onRecordMood: saveMood,
                            onEdit: {
                                if DayKey(selectedDay).isEditable(allowPastDates: allowPastDateEditing) {
                                    presentEditor(for: selectedDay, group: selectedEntry?.choice?.group ?? .mood)
                                }
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
        .scrollDisabled(isHorizontalMonthSwipe)
        .background(theme.palette.resolved(for: colorScheme).background)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: entries.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
            try? EntryStore(context: modelContext).reconcileDuplicates()
        }
        .task {
            await DailyFragmentReminder.refresh(
                recordedDayKeys: recordedDayKeys,
                isEnabled: isDailyReminderEnabled,
                mayRequestAuthorization: false
            )
        }
        .onChange(of: recordedDayKeys.sorted()) { _, _ in
            Task {
                await DailyFragmentReminder.refresh(
                    recordedDayKeys: recordedDayKeys,
                    isEnabled: isDailyReminderEnabled,
                mayRequestAuthorization: false
                )
            }
        }
        .onAppear {
            refreshSelectedDayIfNeeded()
            if !didOpenInitialDate, let date = initialDate {
                displayedMonth = MonthLayout(containing: date, calendar: calendar).monthStart
                selectedDay = calendar.startOfDay(for: date)
                didOpenInitialDate = true
            }
            openRequestedMonth()
            scheduleMidnightCheck()
        }
        .onChange(of: requestedMonth) { _, _ in
            openRequestedMonth()
        }
        .onDisappear {
            midnightTimer?.invalidate()
            midnightTimer = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                midnightTimer?.invalidate()
                midnightTimer = nil
                return
            }
            refreshSelectedDayIfNeeded()
            scheduleMidnightCheck()
            Task {
                await DailyFragmentReminder.refresh(
                    recordedDayKeys: recordedDayKeys,
                    isEnabled: isDailyReminderEnabled,
                mayRequestAuthorization: false
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            guard scenePhase == .active else { return }
            refreshSelectedDayIfNeeded()
            scheduleMidnightCheck()
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: handleEditorDismissed) {
            EntryEditorScreen(
                day: selectedDay,
                entry: selectedEntry,
                initialGroup: editorInitialGroup,
                onSaved: handleEditorSaved
            )
        }
        .alert(localized("保存失败"), isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(localized("确定"), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? localized("请稍后再试。"))
        }
    }

    private func openRequestedMonth() {
        guard let date = requestedMonth else { return }
        displayedMonth = MonthLayout(containing: date, calendar: calendar).monthStart
        selectedDay = calendar.startOfDay(for: date)
        isChoosingMonth = false
        requestedMonth = nil
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(storedCalendarTitle.isEmpty ? localized("今日份") : storedCalendarTitle)
                    .font(.system(size: 23, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
                if !isChoosingMonth {
                Button {
                    if !isChoosingMonth {
                        chooserYear = calendar.component(.year, from: displayedMonth)
                    }
                    isChoosingMonth.toggle()
                } label: {
                    HStack(spacing: 5) {
                        yearLabel(calendar.component(.year, from: displayedMonth), size: 14)
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.gray)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(localized("选择月份"))
                }
                Spacer()

                if !isSearchDestination {
                    Button { isSearchPresented = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(theme.palette.strongAccent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("搜索记录"))
                }

                if !isChoosingMonth && !isDisplayingCurrentMonth {
                    todayButton
                }
            }

            HStack {

                if isChoosingMonth {
                    Button { moveYear(-1) } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(theme.palette.strongAccent.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(localized("上一年"))
                    Spacer()
                    Button { isChoosingMonth = false } label: {
                        yearLabel(chooserYear, size: 18)
                            .foregroundStyle(.primary)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel(localized("关闭月份选择"))
                    Spacer()
                    Button { moveYear(1) } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(theme.palette.strongAccent.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(localized("下一年"))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .highPriorityGesture(yearSwipeGesture)
        }
        .padding(.top, 4)
    }

    private func yearLabel(_ year: Int, size: CGFloat) -> some View {
        (Text(verbatim: "\(year)")
            .font(.system(size: size, weight: .light, design: .rounded))
         + Text(localized("年"))
            .font(.system(size: size, weight: .regular)))
    }

    private var monthChooser: some View {
        VStack(alignment: .trailing, spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        chooseMonth(month)
                    } label: {
                        VStack(spacing: 4) {
                            Text(monthTitle(month, abbreviated: true))
                                .font(.body.weight(isDisplayedMonth(month) ? .semibold : .medium))
                                .foregroundStyle(isDisplayedMonth(month) ? theme.palette.onSelection : Color.primary)
                                .frame(minWidth: 68, minHeight: 56)
                                .frame(maxWidth: .infinity)
                                .background {
                                    if isDisplayedMonth(month) {
                                        SelectionShapeIcon(shape: selectionShape,
                                                           color: theme.palette.selectionFill, size: 50)
                                            .accessibilityHidden(true)
                                    }
                                }
                            Group {
                                if let choice = representativeChoice(in: month) {
                                    ChoiceArtwork(choice: choice)
                                        .scaledToFit()
                                        .frame(width: 58, height: 38)
                                        .scaleEffect(choice.group == .mood ? 1 : choice.group == .company ? 1.45 : 1.35)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(height: 44)
                            .accessibilityHidden(true)
                        }
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(verbatim: localized("%@年%@月", String(describing: chooserYear), String(describing: month))))
                    .accessibilityValue(representativeChoice(in: month).map { localized("代表表情，%@", String(describing: $0.title)) } ?? localized("无记录"))
                    .accessibilityAddTraits(isDisplayedMonth(month) ? .isSelected : [])
                }
            }
            HStack {
                Button(localized("今年")) {
                    let currentYear = calendar.component(.year, from: Date())
                    guard chooserYear != currentYear else { return }
                    chooserYear = currentYear
                    PageTurnFeedback.play()
                }
                .frame(minHeight: 44)
                Spacer()
                Button(localized("返回")) { isChoosingMonth = false }
                    .frame(minHeight: 44)
                    .accessibilityLabel(localized("返回日历"))
            }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.palette.strongAccent)
                .padding(.top, 28)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .padding(.top, 22)
        .contentShape(Rectangle())
        .highPriorityGesture(yearSwipeGesture)
    }

    private func representativeChoice(in month: Int) -> DailyChoice? {
        let prefix = String(format: "%04d-%02d-", chooserYear, month)
        let monthEntries = entriesByDay.values.filter { $0.dayKey.hasPrefix(prefix) }
        let grouped = Dictionary(grouping: monthEntries.filter { $0.choice != nil }) { $0.choice! }
        return grouped.keys.max { lhs, rhs in
            let left = grouped[lhs]!
            let right = grouped[rhs]!
            if left.count != right.count { return left.count < right.count }
            return (left.map(\.dayKey).max() ?? "") < (right.map(\.dayKey).max() ?? "")
        }
    }

    private func monthTitle(_ month: Int, abbreviated: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        let symbols = abbreviated ? formatter.shortStandaloneMonthSymbols! : formatter.standaloneMonthSymbols!
        return symbols[month - 1]
    }

    private func isDisplayedMonth(_ month: Int) -> Bool {
        chooserYear == calendar.component(.year, from: displayedMonth)
            && month == calendar.component(.month, from: displayedMonth)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($isHorizontalMonthSwipe) { value, isHorizontal, _ in
                let movement = value.translation
                if abs(movement.width) > abs(movement.height) {
                    isHorizontal = true
                }
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      let step = swipeStep(for: value) else { return }
                moveMonth(step)
            }
    }

    private var yearSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($isHorizontalMonthSwipe) { value, isHorizontal, _ in
                let movement = value.translation
                if abs(movement.width) > abs(movement.height) {
                    isHorizontal = true
                }
            }
            .onEnded { value in
                guard isChoosingMonth,
                      abs(value.translation.width) > abs(value.translation.height),
                      let step = swipeStep(for: value) else { return }
                moveYear(step)
            }
    }

    private func swipeStep(for value: DragGesture.Value) -> Int? {
        let translation = value.translation
        let horizontal = translation.width
        let predictedHorizontal = value.predictedEndTranslation.width
        let isHorizontalSwipe = abs(horizontal) >= abs(translation.height) * 0.5
        let isLongEnough = abs(horizontal) >= 6
        let isQuickFlick = abs(predictedHorizontal) >= 10

        guard isHorizontalSwipe, isLongEnough || isQuickFlick else {
            return nil
        }
        return horizontal < 0 ? 1 : -1
    }

    private func chooseMonth(_ month: Int) {
        guard let date = calendar.date(from: DateComponents(year: chooserYear, month: month, day: 1)) else {
            return
        }
        displayedMonth = MonthLayout(containing: date).monthStart
        selectedDay = isDisplayingCurrentMonth ? Date() : displayedMonth
        isChoosingMonth = false
    }

    private var monthHandwritingFont: Font {
        let candidates: [String]
        switch AppLanguage.selection {
        case "zh-Hans": candidates = ["MaShanZheng-Regular"]
        case "ja": candidates = ["Yomogi-Regular"]
        case "ko": candidates = ["NanumPen-Regular"]
        default: candidates = ["ChalkboardSE-Regular", "Noteworthy-Light"]
        }
        if let name = candidates.first(where: { UIFont(name: $0, size: 23) != nil }) {
            return .custom(name, size: 23, relativeTo: .title3)
        }
        return .system(size: 23, weight: .regular, design: .rounded)
    }

    private var monthHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(localized("上个月"))
                .opacity(showMonthArrows ? 1 : 0)
                .allowsHitTesting(showMonthArrows)
                .accessibilityHidden(!showMonthArrows)

                Spacer()

                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(localized("下个月"))
                .opacity(showMonthArrows ? 1 : 0)
                .allowsHitTesting(showMonthArrows)
                .accessibilityHidden(!showMonthArrows)
            }
            .padding(.horizontal, 10)
            .overlay {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(monthTitle(calendar.component(.month, from: displayedMonth)))
                        // .font(monthHandwritingFont)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)

                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(displayedMonth.formatted(.dateTime.locale(AppLanguage.locale).year().month(.wide)))
                .allowsHitTesting(false)
            }

        }
        .buttonStyle(.plain)
    }

    private var todayButton: some View {
        Button(localized("今天")) { showCurrentMonth() }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.palette.onStrongAccent)
            .frame(minWidth: 44, minHeight: 44)
            .background(theme.palette.todayButtonFill)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityLabel(localized("回到今天"))
    }

    private var isDisplayingCurrentMonth: Bool {
        isCurrentMonth(displayedMonth)
    }

    private func isCurrentMonth(_ month: Date) -> Bool {
        let displayed = DayKey(month)
        let today = DayKey(Date())
        return displayed.year == today.year && displayed.month == today.month
    }

    private func showCurrentMonth() {
        let today = Date()
        displayedMonth = MonthLayout(containing: today, calendar: calendar).monthStart
        selectedDay = today
    }

    private func refreshSelectedDayIfNeeded() {
        let now = Date()
        let today = DayKey(now, calendar: calendar)
        let timeZoneID = calendar.timeZone.identifier
        guard today != lastObservedToday || timeZoneID != lastObservedTimeZoneID else { return }
        lastObservedToday = today
        lastObservedTimeZoneID = timeZoneID
        displayedMonth = MonthLayout(containing: now, calendar: calendar).monthStart
        selectedDay = now
        chooserYear = today.year
        isChoosingMonth = false
    }

    private func scheduleMidnightCheck() {
        midnightTimer?.invalidate()
        guard scenePhase == .active else { return }
        let now = Date()
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1,
                                               to: calendar.startOfDay(for: now)) else { return }
        let timer = Timer(timeInterval: max(1, nextMidnight.timeIntervalSince(now) + 0.2), repeats: false) { _ in
            refreshSelectedDayIfNeeded()
            scheduleMidnightCheck()
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }

    private func moveMonth(_ amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else {
            return
        }
        let nextMonth = MonthLayout(containing: next).monthStart
        displayedMonth = nextMonth
        selectedDay = isCurrentMonth(nextMonth) ? Date() : nextMonth
        PageTurnFeedback.play()
    }

    private func moveYear(_ amount: Int) {
        chooserYear += amount
        PageTurnFeedback.play()
    }

    private func saveMood(_ mood: Mood) {
        guard DayKey(selectedDay).relationToToday == .today else { return }
        do {
            guard let choice = DailyChoice(rawValue: mood.rawValue) else { return }
            try EntryStore(context: modelContext).save(day: DayKey(selectedDay), choice: choice, note: "")
            SaveFeedback.play()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func presentEditor(for date: Date, group: ChoiceGroup) {
        guard DayKey(date).isEditable(allowPastDates: allowPastDateEditing) else { return }
        let key = DayKey(date).storageValue
        editingDayKey = key
        editingChoiceRawValue = entriesByDay[key]?.choice?.rawValue
        selectedDay = date
        editorInitialGroup = group
        isEditorPresented = true
    }

    private func handleEditorSaved(_ choice: DailyChoice, hasChanges: Bool) {
        pendingSaveFeedback = hasChanges
        guard let key = editingDayKey,
              choice.rawValue != editingChoiceRawValue else { return }
        pendingRevealDayKey = key
    }

    private func handleEditorDismissed() {
        editingDayKey = nil
        editingChoiceRawValue = nil
        if pendingSaveFeedback {
            SaveFeedback.play()
            pendingSaveFeedback = false
        }
        guard let key = pendingRevealDayKey else { return }

        // Keep the saved artwork hidden until the sheet has finished closing.
        animatedDayKey = key
        DispatchQueue.main.async {
            pendingRevealDayKey = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if animatedDayKey == key {
                animatedDayKey = nil
            }
        }
    }

}

#Preview {
    CalendarScreen(requestedMonth: .constant(nil))
        .modelContainer(for: MoodEntry.self, inMemory: true)
}

