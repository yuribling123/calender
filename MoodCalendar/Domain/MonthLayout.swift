import Foundation

struct MonthLayout {
    let monthStart: Date
    let days: [Date?]

    init(containing date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let start = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: start) else {
            monthStart = date
            days = []
            return
        }
        monthStart = start
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        days = Array<Date?>(repeating: nil, count: offset) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }.map(Optional.some)
    }
}
