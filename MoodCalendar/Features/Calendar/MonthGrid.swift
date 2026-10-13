import SwiftUI

struct MonthGrid: View {
    @ScaledMetric(relativeTo: .body) private var scaledWeekdaySize: CGFloat = 15

    let layout: MonthLayout
    let entries: [String: MoodEntry]
    let selectedDay: DayKey
    let pendingRevealDayKey: String?
    let animatingDayKey: String?
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 16) {
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
                                    isFuture: relation == .future,
                                    isRevealPending: key.storageValue == pendingRevealDayKey,
                                    isAnimating: key.storageValue == animatingDayKey)
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
        var calendar = Calendar.current
        calendar.locale = AppLanguage.locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private func accessibilityText(for date: Date, relation: DayRelation, choice: DailyChoice?, hasNote: Bool) -> String {
        let dateText = date.formatted(.dateTime.locale(AppLanguage.locale).year().month().day())
        if relation == .future { return localized("%@，还没到来", String(describing: dateText)) }
        let entryText = choice.map { "\(dateText), \($0.group.title), \($0.title)" } ?? localized("%@，未记录", String(describing: dateText))
        let todayText = relation == .today ? localized("今天，%@", String(describing: entryText)) : entryText
        return hasNote ? localized("%@，有文字记录", String(describing: todayText)) : todayText
    }
}
