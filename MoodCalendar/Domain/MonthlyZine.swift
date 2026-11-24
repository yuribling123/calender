import Foundation

/// A layout draft only. Source memories and their editing permissions stay untouched.
struct MonthlyZineDraft: Codable, Equatable, Sendable {
    var title = ""
    var introduction = ""
    var selectedDayKeys: [String] = []
    var photoDayKey: String?
    var showsWriting = false
    var showsPhoto = false
    var showsMusic = false
    var showsWatch = false
}

enum MonthlyZine {
    static let maximumMemories = 3
    static let titleLimit = 32
    static let introductionLimit = 160

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 1, parts.month ?? 1)
    }

    static func date(for key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), (1...9999).contains(year),
              let month = Int(parts[1]), (1...12).contains(month),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12)),
              monthKey(date, calendar: calendar) == key else { return nil }
        return date
    }

    static func memories(in month: Date, entries: [MoodEntry], today: Date = .now,
                         calendar: Calendar = .current) -> [MoodEntry] {
        let key = monthKey(month, calendar: calendar)
        let todayKey = DayKey(today, calendar: calendar).storageValue
        guard key <= monthKey(today, calendar: calendar) else { return [] }
        return Dictionary(grouping: entries, by: \.dayKey).values.compactMap { duplicates in
            guard let entry = duplicates.max(by: {
                $0.updatedAt == $1.updatedAt
                    ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt < $1.updatedAt
            }), entry.dayKey.hasPrefix(key + "-"), entry.dayKey <= todayKey,
                  entry.choice != nil, dayDate(entry.dayKey, calendar: calendar) != nil else { return nil }
            return entry
        }.sorted { $0.dayKey < $1.dayKey }
    }

    static func dayDate(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), (1...9999).contains(year),
              let month = Int(parts[1]), (1...12).contains(month),
              let day = Int(parts[2]), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              DayKey(date, calendar: calendar).storageValue == key else { return nil }
        return date
    }

    static func sanitized(_ draft: MonthlyZineDraft, availableDayKeys: [String], photoDayKeys: [String]) -> MonthlyZineDraft {
        var result = draft
        result.title = String(result.title.prefix(titleLimit))
        result.introduction = String(result.introduction.prefix(introductionLimit))
        var seen = Set<String>()
        result.selectedDayKeys = Array(result.selectedDayKeys.filter {
            availableDayKeys.contains($0) && seen.insert($0).inserted
        }.prefix(maximumMemories))
        if let key = result.photoDayKey, !photoDayKeys.contains(key) { result.photoDayKey = nil }
        return result
    }

    /// The visible ellipsis makes the poster's intentional excerpt explicit.
    static func excerpt(_ text: String, limit: Int) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        return String(text.prefix(max(0, limit - 1))) + "…"
    }
}
