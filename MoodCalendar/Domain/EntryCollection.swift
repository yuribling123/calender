import Foundation

/// Pagination for collection lists. Clamp after records are removed from the last page.
struct CollectionPage {
    static let size = 6
    let itemCount: Int
    let requestedIndex: Int

    var count: Int { max(1, (itemCount + Self.size - 1) / Self.size) }
    var index: Int { min(max(0, requestedIndex), count - 1) }
    var range: Range<Int> {
        let start = index * Self.size
        return start..<min(start + Self.size, itemCount)
    }
}

struct CollectedMemory: Identifiable {
    let entry: MoodEntry
    let date: Date
    var id: String { entry.dayKey }
}

struct CollectedSong: Identifiable {
    struct Identity: Hashable {
        let title: String
        let artist: String
    }


    let id: Identity
    let title: String
    let artist: String
    let memories: [CollectedMemory]
}

/// Read-only collections derived from daily records; no duplicate storage or changes to edit rules.
enum EntryCollection {
    static func songs(from entries: [MoodEntry], today: Date = .now,
                      calendar: Calendar = .current) -> [CollectedSong] {
        let memories = memories(from: entries, today: today, calendar: calendar)
            .filter { !clean($0.entry.songTitle).isEmpty }

        return Dictionary(grouping: memories) {
            CollectedSong.Identity(title: normalized($0.entry.songTitle), artist: normalized($0.entry.songArtist))
        }.map { id, memories in
            let sorted = memories.sorted { $0.date > $1.date }
            return CollectedSong(id: id, title: clean(sorted[0].entry.songTitle),
                                 artist: clean(sorted[0].entry.songArtist), memories: sorted)
        }.sorted {
            if $0.memories[0].date != $1.memories[0].date { return $0.memories[0].date > $1.memories[0].date }
            return ($0.id.title, $0.id.artist) < ($1.id.title, $1.id.artist)
        }
    }

    static func watches(from entries: [MoodEntry], today: Date = .now,
                        calendar: Calendar = .current) -> [CollectedWatch] {
        let memories = memories(from: entries, today: today, calendar: calendar)
            .filter { !clean($0.entry.watchTitle).isEmpty }
        return Dictionary(grouping: memories) {
            CollectedWatch.Identity(title: normalized($0.entry.watchTitle), kind: normalized($0.entry.watchKind))
        }.map { id, memories in
            let sorted = memories.sorted { $0.date > $1.date }
            return CollectedWatch(id: id, title: clean(sorted[0].entry.watchTitle),
                                  kind: clean(sorted[0].entry.watchKind), memories: sorted)
        }.sorted {
            if $0.memories[0].date != $1.memories[0].date { return $0.memories[0].date > $1.memories[0].date }
            return ($0.id.title, $0.id.kind) < ($1.id.title, $1.id.kind)
        }
    }

    static func photos(from entries: [MoodEntry], today: Date = .now,
                       calendar: Calendar = .current) -> [CollectedMemory] {
        memories(from: entries, today: today, calendar: calendar)
            .filter { $0.entry.photoData?.isEmpty == false }
    }

    private static func memories(from entries: [MoodEntry], today: Date,
                                 calendar: Calendar) -> [CollectedMemory] {
        let latestEntries = Dictionary(grouping: entries, by: \.dayKey).values.compactMap {
            $0.max {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
        return latestEntries.compactMap { entry -> CollectedMemory? in
            guard let date = date(for: entry.dayKey, calendar: calendar),
                  date <= calendar.startOfDay(for: today) else { return nil }
            return CollectedMemory(entry: entry, date: date)
        }.sorted { $0.date > $1.date }
    }

    private static func clean(_ value: String?) -> String {
        (value ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func normalized(_ value: String?) -> String {
        clean(value).folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func date(for key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3, parts.map(\.count) == [4, 2, 2],
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), year > 0,
              let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              DayKey(date, calendar: calendar).storageValue == key else { return nil }
        return calendar.startOfDay(for: date)
    }
}

struct CollectedWatch: Identifiable {
    struct Identity: Hashable {
        let title: String
        let kind: String
    }

    let id: Identity
    let title: String
    let kind: String
    let memories: [CollectedMemory]
}
