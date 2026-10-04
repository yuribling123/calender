import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [MoodEntry]
    @State private var displayedMonth = MonthLayout(containing: Date()).monthStart
    @State private var selectedDay = Date()
    @State private var isChoosingMonth = false
    @State private var chooserYear = Calendar.current.component(.year, from: Date())
    @State private var isEditorPresented = false
    @State private var saveError: String?

    private let calendar = Calendar.current

    private var selectedEntry: MoodEntry? {
        let key = DayKey(selectedDay).storageValue
        return entries.first { $0.dayKey == key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                        .padding(.bottom, 28)
                    if isChoosingMonth {
                        monthChooser
                    } else {
                        monthHeader
                            .padding(.bottom, 30)
                        MonthGrid(
                            layout: MonthLayout(containing: displayedMonth),
                            entries: Dictionary(uniqueKeysWithValues: entries.map { ($0.dayKey, $0) }),
                            selectedDay: DayKey(selectedDay),
                            onSelect: { selectedDay = $0 }
                        )
                        .padding(.bottom, 22)
                        SelectedDateDetail(
                            date: selectedDay,
                            entry: selectedEntry,
                            onRecordMood: saveMood,
                            onEditToday: {
                                if DayKey(selectedDay).relationToToday == .today {
                                    isEditorPresented = true
                                }
                            }
                        )
                    }
                }
                .padding(24)
            }
            .background(Color(red: 0.99, green: 0.98, blue: 0.97))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditorPresented) {
                EntryEditorScreen(day: selectedDay, entry: selectedEntry)
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
        VStack(alignment: .leading, spacing: 7) {
            Text("今日份")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.black)
            HStack {
                Button {
                    if !isChoosingMonth {
                        chooserYear = calendar.component(.year, from: displayedMonth)
                    }
                    isChoosingMonth.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text(verbatim: "\(isChoosingMonth ? chooserYear : calendar.component(.year, from: displayedMonth))年")
                        Image(systemName: isChoosingMonth ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.gray)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(isChoosingMonth ? "关闭月份选择" : "选择月份")

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
            #if DEBUG
            if DemoData.isEnabled {
                Text("演示数据")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.top, 8)
    }

    private var monthChooser: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
            ForEach(1...12, id: \.self) { month in
                Button {
                    chooseMonth(month)
                } label: {
                    Text("\(month)月")
                        .font(.system(size: 18, weight: isDisplayedMonth(month) ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background {
                            if isDisplayedMonth(month) {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Mood.veryGood.color.opacity(0.18))
                            }
                        }
                }
                .accessibilityLabel("\(chooserYear)年\(month)月")
                .accessibilityAddTraits(isDisplayedMonth(month) ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
    }

    private func isDisplayedMonth(_ month: Int) -> Bool {
        chooserYear == calendar.component(.year, from: displayedMonth)
            && month == calendar.component(.month, from: displayedMonth)
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

            if !isDisplayingCurrentMonth {
                HStack {
                    Spacer()
                    Button("今天") { showCurrentMonth() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Mood.veryGood.color.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
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
            try EntryStore(context: modelContext).save(day: DayKey(selectedDay), mood: mood, note: "")
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    CalendarScreen()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
