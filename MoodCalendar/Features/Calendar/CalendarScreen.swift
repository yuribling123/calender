import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [MoodEntry]
    @State private var displayedMonth = MonthLayout(containing: Date()).monthStart
    @State private var selectedDay = Date()
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
                        .padding(.bottom, 12)
                    monthHeader
                        .padding(.bottom, 22)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("心情日历")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("每天一点记录，慢慢看见自己。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            .overlay {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(calendar.component(.year, from: displayedMonth)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.month, from: displayedMonth))月")
                        .font(.system(size: 20, weight: .semibold))
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
