import Foundation

/// Local date bookmarks; past dates follow the past-editing preference.
enum StarredDayStore {
    static func decode(_ value: String) -> Set<String> {
        guard let data = value.data(using: .utf8),
              let days = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(days)
    }

    static func canToggle(_ day: DayKey, allowPastDates: Bool, today: DayKey = DayKey(Date())) -> Bool {
        allowPastDates || day >= today
    }

    static func toggling(_ day: DayKey, in value: String, allowPastDates: Bool,
                         today: DayKey = DayKey(Date())) -> String {
        guard canToggle(day, allowPastDates: allowPastDates, today: today) else { return value }
        let dayKey = day.storageValue
        var days = decode(value)
        if !days.insert(dayKey).inserted { days.remove(dayKey) }
        guard let data = try? JSONEncoder().encode(days.sorted()),
              let encoded = String(data: data, encoding: .utf8) else { return value }
        return encoded
    }
}
