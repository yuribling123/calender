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

/// Month selection shares the same local calendar and keys as saved monthly notes.
struct NoteMonthSelection {
    let calendar: Calendar
    let currentYear: Int
    let currentMonth: Int

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        currentYear = calendar.component(.year, from: now)
        currentMonth = calendar.component(.month, from: now)
    }

    func isAllowed(year: Int, month: Int, allowPastDates: Bool) -> Bool {
        guard year >= 1, (1...12).contains(month) else { return false }
        if year == currentYear && month == currentMonth { return true }
        return allowPastDates && (year < currentYear || year == currentYear && month < currentMonth)
    }

    func date(year: Int, month: Int) -> Date? {
        guard year >= 1, (1...12).contains(month),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month else { return nil }
        return date
    }

    func key(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    func monthName(_ month: Int, locale: Locale) -> String {
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        return localizedCalendar.monthSymbols[month - 1].uppercased()
    }

}
