import SwiftUI

struct MonthGrid: View {
    @ScaledMetric(relativeTo: .body) private var scaledWeekdaySize: CGFloat = 15

    let layout: MonthLayout
    let entries: [String: MoodEntry]
    let selectedDay: DayKey
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 26) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdayNames[index])
                        .font(.system(size: min(scaledWeekdaySize, 19), weight: .medium))
                        .foregroundStyle(Color.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(layout.days.enumerated()), id: \.offset) { item in
                    if let date = item.element {
                        let key = DayKey(date)
                        let relation = key.relationToToday
                        let entry = relation == .future ? nil : entries[key.storageValue]
                        let choice = entry?.choice
                        let hasNote = entry.map { !$0.note.isEmpty } ?? false
                        Button { onSelect(date) } label: {
                            DayCell(date: date, choice: choice, hasNote: hasNote,
                                    isToday: relation == .today,
                                    isSelected: key == selectedDay,
                                    isFuture: relation == .future)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityText(for: date, relation: relation, choice: choice, hasNote: hasNote))
                        .accessibilityAddTraits(key == selectedDay ? .isSelected : [])
                    } else {
                        Color.clear.frame(height: 74)
                    }
                }
            }
        }
    }

    private var weekdayNames: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private func accessibilityText(for date: Date, relation: DayRelation, choice: DailyChoice?, hasNote: Bool) -> String {
        let dateText = date.formatted(.dateTime.year().month().day())
        if relation == .future { return "\(dateText)，还没到来" }
        let entryText = choice.map { "\(dateText)，\($0.group.rawValue)，\($0.title)" } ?? "\(dateText)，未记录"
        let todayText = relation == .today ? "今天，\(entryText)" : entryText
        return hasNote ? "\(todayText)，有文字记录" : todayText
    }
}
