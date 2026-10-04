import SwiftUI

struct MonthGrid: View {
    let layout: MonthLayout
    let entries: [String: MoodEntry]
    let selectedDay: DayKey
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdayNames[index])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(layout.days.enumerated()), id: \.offset) { item in
                    if let date = item.element {
                        let key = DayKey(date)
                        let relation = key.relationToToday
                        let mood = relation == .future ? nil : entries[key.storageValue]?.mood
                        Button { onSelect(date) } label: {
                            DayCell(date: date, mood: mood,
                                    isSelected: key == selectedDay,
                                    isFuture: relation == .future)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityText(for: date, relation: relation, mood: mood))
                    } else {
                        Color.clear.frame(height: 90)
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

    private func accessibilityText(for date: Date, relation: DayRelation, mood: Mood?) -> String {
        let dateText = date.formatted(.dateTime.year().month().day())
        if relation == .future { return "\(dateText)，还没到来" }
        return mood.map { "\(dateText)，\($0.title)" } ?? "\(dateText)，未记录"
    }
}
