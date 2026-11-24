import Foundation

struct RediscoveredMemory: Identifiable {
    let entry: MoodEntry
    let date: Date
    var id: String { entry.dayKey }
}

/// Rediscovery is read-only. A hidden date stays in the diary and its collections.
enum MemoryShuffle {
    /// Each eligible calendar day has equal probability on every independent draw.
    static func draw(from dayKeys: [String]) -> MemoryDraw? {
        var generator = SystemRandomNumberGenerator()
        return draw(from: dayKeys, using: &generator)
    }

    static func draw<Generator: RandomNumberGenerator>(from dayKeys: [String], using generator: inout Generator) -> MemoryDraw? {
        Set(dayKeys).sorted().randomElement(using: &generator).map { MemoryDraw(dayKey: $0) }
    }

    static func memories(from entries: [MoodEntry], hiddenDays: Set<String> = [],
                         today: Date = .now, calendar: Calendar = .current) -> [RediscoveredMemory] {
        let startOfToday = calendar.startOfDay(for: today)
        return Dictionary(grouping: entries, by: \.dayKey).values.compactMap { revisions in
            guard let entry = revisions.max(by: {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }), !hiddenDays.contains(entry.dayKey),
                  let date = date(for: entry.dayKey, calendar: calendar), date < startOfToday else { return nil }
            return RediscoveredMemory(entry: entry, date: date)
        }.sorted { $0.date > $1.date }
    }

    static func date(for dayKey: String, calendar: Calendar = .current) -> Date? {
        let components = dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3, components[0].count == 4,
              components[1].count == 2, components[2].count == 2,
              components.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(components[0]), year > 0,
              let month = Int(components[1]), (1...12).contains(month),
              let day = Int(components[2]), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              DayKey(date, calendar: calendar).storageValue == dayKey else { return nil }
        return calendar.startOfDay(for: date)
    }
}

/// A new presentation identity restarts transitions and scrolling even for the same day.
struct MemoryDraw: Identifiable {
    let id = UUID()
    let dayKey: String
}
