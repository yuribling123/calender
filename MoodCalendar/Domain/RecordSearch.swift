import Foundation

struct RecordSearchResult: Identifiable {
    enum Source: Hashable {
        case day
        case month
    }

    let id: String
    let source: Source
    let date: Date
    let choice: DailyChoice?
    let cardPaperID: String?
    let preview: String
}

/// Searches written daily notes and monthly notes without changing saved records or edit permissions.
enum RecordSearch {
    static func results(
        entries: [MoodEntry],
        monthlyNotes: [MonthlyNote],
        query: String,
        calendar: Calendar = .current
    ) -> [RecordSearchResult] {
        let query = singleLine(query)
        let today = calendar.startOfDay(for: .now)
        let currentMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today

        let dailyResults = Dictionary(grouping: entries, by: \.dayKey).values.compactMap { duplicates -> RecordSearchResult? in
            guard let entry = duplicates.max(by: {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }),
                  let date = date(from: entry.dayKey, isMonth: false, calendar: calendar),
                  date <= today else { return nil }

            let note = singleLine(entry.note)
            guard !note.isEmpty, query.isEmpty || contains(note, query: query) else { return nil }

            return RecordSearchResult(
                id: "day:\(entry.dayKey)",
                source: .day,
                date: date,
                choice: entry.choice,
                cardPaperID: entry.cardPaperID,
                preview: query.isEmpty ? note : snippet(note, query: query)
            )
        }

        let monthlyResults = Dictionary(grouping: monthlyNotes, by: \.monthKey).values.compactMap { duplicates -> RecordSearchResult? in
            guard let note = duplicates.max(by: {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }),
                  let date = date(from: note.monthKey, isMonth: true, calendar: calendar),
                  date <= currentMonth else { return nil }
            let text = singleLine(note.text)
            guard !text.isEmpty, query.isEmpty || contains(text, query: query) else { return nil }
            return RecordSearchResult(
                id: "month:\(note.monthKey)",
                source: .month,
                date: date,
                choice: nil,
                cardPaperID: nil,
                preview: query.isEmpty ? text : snippet(text, query: query)
            )
        }

        return (dailyResults + monthlyResults).sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            if $0.source != $1.source { return $0.source == .day }
            return $0.id < $1.id
        }
    }

    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func contains(_ text: String, query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: AppLanguage.locale) != nil
    }

    /// Keep a late match visible when the result row truncates its preview to one line.
    private static func snippet(_ text: String, query: String) -> String {
        guard let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: AppLanguage.locale
        ), text.distance(from: text.startIndex, to: range.lowerBound) > 16 else { return text }
        let start = text.index(range.lowerBound, offsetBy: -8, limitedBy: text.startIndex) ?? text.startIndex
        return "…" + text[start...]
    }

    private static func date(from key: String, isMonth: Bool, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == (isMonth ? 2 : 3),
              parts[0].count == 4,
              parts.dropFirst().allSatisfy({ $0.count == 2 }),
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), year > 0,
              let month = Int(parts[1]), (1...12).contains(month),
              let day = isMonth ? 1 : Int(parts[2]), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(
                year: year, month: month, day: day, hour: 12
              )) else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }
}
