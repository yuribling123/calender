import Foundation

struct MonthLayout {
    let monthStart: Date
    let days: [Date?]
    private let calendar: Calendar

    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
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

    func weekdayNames(locale: Locale) -> [String] {
        // Language changes the names, while the grid's calendar owns their order.
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        let symbols = localizedCalendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
}
