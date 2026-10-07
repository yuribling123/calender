import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.selectionShape) private var selectionShape
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @Query private var entries: [MoodEntry]
    @State private var displayedMonth = MonthLayout(containing: Date()).monthStart
    @State private var selectedDay = Date()
    @State private var isChoosingMonth = false
    @State private var chooserYear = Calendar.current.component(.year, from: Date())
    @State private var isEditorPresented = false
    @State private var editorInitialGroup: ChoiceGroup = .mood
    @State private var saveError: String?

    private let calendar = Calendar.current

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
            ScrollViewReader { scrollProxy in
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
                                onSelect: { date in
                                    selectedDay = date
                                    if DayKey(date).relationToToday == .today {
                                        let key = DayKey(date).storageValue
                                        guard entriesByDay[key]?.choice == nil else { return }
                                        editorInitialGroup = .mood
                                        isEditorPresented = true
                                        return
                                    }
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scrollProxy.scrollTo("detailBottom", anchor: .bottom)
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
                                onChooseDaily: {
                                    guard DayKey(selectedDay).relationToToday == .today else { return }
                                    editorInitialGroup = .daily
                                    isEditorPresented = true
                                },
                                onEditToday: {
                                    if DayKey(selectedDay).relationToToday == .today {
                                        editorInitialGroup = selectedEntry?.choice?.group ?? .mood
                                        isEditorPresented = true
                                    }
                                }
                            )
                            Color.clear
                                .frame(height: 80)
                                .id("detailBottom")
                        }
                    }
                    .padding(24)
                }
            }
            .background(theme.palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: entries.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
                try? EntryStore(context: modelContext).reconcileDuplicates()
            }
            .task {
                await DailyFragmentReminder.refresh(recordedDayKeys: recordedDayKeys)
            }
            .onChange(of: recordedDayKeys.sorted()) { _, _ in
                Task {
                    await DailyFragmentReminder.refresh(recordedDayKeys: recordedDayKeys)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await DailyFragmentReminder.refresh(recordedDayKeys: recordedDayKeys)
                }
            }
            .sheet(isPresented: $isEditorPresented) {
                EntryEditorScreen(day: selectedDay, entry: selectedEntry, initialGroup: editorInitialGroup)
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
                        // Image(systemName: isChoosingMonth ? "chevron.up" : "chevron.down")
                        //     .font(.system(size: 10, weight: .medium))
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
                                Image(systemName: selectionShape.systemName)
                                    .font(.system(size: 66))
                                    .foregroundStyle(theme.palette.selectionFill)
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
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard let step = swipeStep(for: value.translation) else { return }
                moveMonth(step)
            }
    }

    private var yearSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard isChoosingMonth, let step = swipeStep(for: value.translation) else { return }
                chooserYear += step
            }
    }

    private func swipeStep(for translation: CGSize) -> Int? {
        let horizontal = translation.width
        guard abs(horizontal) >= 50,
              abs(horizontal) > abs(translation.height) * 1.2 else {
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
            .background(theme.palette.strongAccent)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityLabel("回到今天")
    }

    private var isDisplayingCurrentMonth: Bool {
        let displayed = DayKey(displayedMonth)
        let today = DayKey(Date())
        return displayed.year == today.year && displayed.month == today.month
    }

    private func showCurrentMonth() {
        let today = Date()
        displayedMonth = MonthLayout(containing: today).monthStart
        selectedDay = today
    }

    private func moveMonth(_ amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else {
            return
        }
        displayedMonth = MonthLayout(containing: next).monthStart
        if isDisplayingCurrentMonth {
            selectedDay = Date()
        } else {
            selectedDay = displayedMonth
        }
    }

    private func saveMood(_ mood: Mood) {
        guard DayKey(selectedDay).relationToToday == .today else { return }
        do {
            guard let choice = DailyChoice(rawValue: mood.rawValue) else { return }
            try EntryStore(context: modelContext).save(day: DayKey(selectedDay), choice: choice, note: "")
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    CalendarScreen()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
