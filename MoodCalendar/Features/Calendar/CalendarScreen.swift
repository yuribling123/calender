import SwiftUI
import SwiftData
import UIKit

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.selectionShape) private var selectionShape
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @AppStorage("dailyReminderEnabled") private var isDailyReminderEnabled = true
    @Query private var entries: [MoodEntry]
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
    @State private var pendingRevealDayKey: String?
    @State private var animatedDayKey: String?
    @State private var saveError: String?

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

    private var recordedDayKeys: Set<String> {
        Set(entries.filter { $0.choice != nil }.map(\.dayKey))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                        .padding(.bottom, 4)
                    if isChoosingMonth {
                        monthChooser
                    } else {
                        monthHeader
                            .padding(.bottom, 30)
                            .simultaneousGesture(monthSwipeGesture)
                        MonthGrid(
                            layout: MonthLayout(containing: displayedMonth),
                            entries: entriesByDay,
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
                        .offset(y: -8)
                        .padding(.bottom, 8)
                        .simultaneousGesture(monthSwipeGesture)
                        SelectedDateDetail(
                            date: selectedDay,
                            entry: selectedEntry,
                            onRecordMood: saveMood,
                            onEditToday: {
                                if DayKey(selectedDay).relationToToday == .today {
                                    presentEditor(for: selectedDay, group: selectedEntry?.choice?.group ?? .mood)
                                }
                            }
                        )
                    }
                }
                .padding(24)
            }
            .background(theme.palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: entries.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
                try? EntryStore(context: modelContext).reconcileDuplicates()
            }
            .task {
                await DailyFragmentReminder.refresh(
                    recordedDayKeys: recordedDayKeys,
                    isEnabled: isDailyReminderEnabled
                )
            }
            .onChange(of: recordedDayKeys.sorted()) { _, _ in
                Task {
                    await DailyFragmentReminder.refresh(
                        recordedDayKeys: recordedDayKeys,
                        isEnabled: isDailyReminderEnabled
                    )
                }
            }
            .onAppear {
                refreshSelectedDayIfNeeded()
                scheduleMidnightCheck()
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
                        isEnabled: isDailyReminderEnabled
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
            .alert("保存失败", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("好", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "请稍后再试。")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(storedCalendarTitle.isEmpty ? "今日份" : storedCalendarTitle)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.black)
                Button {
                    if !isChoosingMonth {
                        chooserYear = calendar.component(.year, from: displayedMonth)
                    }
                    isChoosingMonth.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text(verbatim: "\(isChoosingMonth ? chooserYear : calendar.component(.year, from: displayedMonth))年")
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.gray)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(isChoosingMonth ? "关闭月份选择" : "选择月份")
                Spacer()

                if !isChoosingMonth && !isDisplayingCurrentMonth {
                    todayButton
                }
            }

            HStack {

                if isChoosingMonth {
                    Spacer()
                    Button { chooserYear -= 1 } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("上一年")
                    Button { chooserYear += 1 } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("下一年")
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(yearSwipeGesture)
            #if DEBUG
            if DemoData.isEnabled {
                Text("演示数据")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.top, 4)
    }

    private var monthChooser: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 32) {
            ForEach(1...12, id: \.self) { month in
                Button {
                    chooseMonth(month)
                } label: {
                    Text("\(month)月")
                        .font(.system(size: 18, weight: isDisplayedMonth(month) ? .semibold : .medium))
                        .foregroundStyle(isDisplayedMonth(month) ? theme.palette.onSelection : Color.primary)
                        .frame(minWidth: 68, minHeight: 44)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background {
                            if isDisplayedMonth(month) {
                                SelectionShapeIcon(
                                    shape: selectionShape,
                                    color: theme.palette.selectionFill,
                                    size: 66
                                )
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: "\(chooserYear)年\(month)月"))
                .accessibilityAddTraits(isDisplayedMonth(month) ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 22)
    }

    private func isDisplayedMonth(_ month: Int) -> Bool {
        chooserYear == calendar.component(.year, from: displayedMonth)
            && month == calendar.component(.month, from: displayedMonth)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onEnded { value in
                guard let step = swipeStep(for: value) else { return }
                moveMonth(step)
            }
    }

    private var yearSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onEnded { value in
                guard isChoosingMonth, let step = swipeStep(for: value) else { return }
                chooserYear += step
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

    private var monthHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("上个月")

                Spacer()

                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("下个月")
            }
            .padding(.horizontal, 10)
            .overlay {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(calendar.component(.month, from: displayedMonth))月")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .allowsHitTesting(false)
            }

        }
        .buttonStyle(.plain)
    }

    private var todayButton: some View {
        Button("今天") { showCurrentMonth() }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.palette.onStrongAccent)
            .frame(minWidth: 44, minHeight: 44)
            .background(theme.palette.todayButtonFill)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityLabel("回到今天")
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
        let key = DayKey(date).storageValue
        editingDayKey = key
        editingChoiceRawValue = entriesByDay[key]?.choice?.rawValue
        selectedDay = date
        editorInitialGroup = group
        isEditorPresented = true
    }

    private func handleEditorSaved(_ choice: DailyChoice) {
        guard let key = editingDayKey,
              choice.rawValue != editingChoiceRawValue else { return }
        pendingRevealDayKey = key
    }

    private func handleEditorDismissed() {
        editingDayKey = nil
        editingChoiceRawValue = nil
        guard let key = pendingRevealDayKey else { return }

        // Keep the saved artwork hidden until the sheet has finished closing.
        animatedDayKey = key
        SaveFeedback.play()
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
    CalendarScreen()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
