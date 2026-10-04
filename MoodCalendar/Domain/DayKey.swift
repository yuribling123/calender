import Foundation

/// A calendar day in the user's local Gregorian calendar, independent of time of day.
struct DayKey: Hashable, Comparable, Codable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    var storageValue: String { String(format: "%04d-%02d-%02d", year, month, day) }

    var relationToToday: DayRelation {
        let today = DayKey(Date())
        if self < today { return .past }
        if self > today { return .future }
        return .today
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum DayRelation: Equatable {
    case past
    case today
    case future
}
