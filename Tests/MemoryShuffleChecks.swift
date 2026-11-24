import Foundation

@main
struct MemoryShuffleChecks {
    @MainActor
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 15))!
        func entry(_ day: String, note: String = "Original") -> MoodEntry {
            MoodEntry(dayKey: day, choice: .good, note: note)
        }
        let leap = entry("2024-02-29")
        let replacement = entry("2024-02-29", note: "Revised")
        replacement.updatedAt = leap.updatedAt.addingTimeInterval(1)
        let records = [leap, replacement, entry("2024-01-31"), entry("2023-12-31"),
                       entry("2024-03-01"), entry("2024-03-02"), entry("2023-02-29"),
                       entry("2024-02-30"), entry("2024-2-01"), entry("2024-13-01")]
        let memories = MemoryShuffle.memories(from: records, today: today, calendar: calendar)
        precondition(memories.map(\.id) == ["2024-02-29", "2024-01-31", "2023-12-31"],
                     "Only valid past calendar dates, across leap day/month/year boundaries")
        precondition(memories.first?.entry.note == "Revised", "Latest whole-day revision wins")
        precondition(MemoryShuffle.memories(from: records, hiddenDays: ["2024-02-29"],
                                           today: today, calendar: calendar).count == 2)
        let beforeMidnight = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 23, minute: 59))!
        precondition(!MemoryShuffle.memories(from: records, today: beforeMidnight, calendar: calendar).contains { $0.id == "2024-02-29" },
                     "Today stays excluded even at the end of a leap day")

        struct Seeded: RandomNumberGenerator {
            var state: UInt64 = 42
            mutating func next() -> UInt64 {
                state = 2862933555777941757 &* state &+ 3037000493
                return state
            }
        }
        var random = Seeded()
        let keys = memories.map(\.id)
        var counts: [String: Int] = [:]
        var previous: MemoryDraw?
        var repeats = 0
        for _ in 0..<12_000 {
            let draw = MemoryShuffle.draw(from: keys, using: &random)!
            precondition(keys.contains(draw.dayKey))
            if draw.dayKey == previous?.dayKey {
                repeats += 1
                precondition(draw.id != previous?.id,
                             "Repeated dates get a fresh presentation identity for animation and scroll reset")
            }
            previous = draw
            counts[draw.dayKey, default: 0] += 1
        }
        precondition(repeats > 0, "Independent draws allow immediate repeats without cycle limits")
        for key in keys {
            precondition((3_600...4_400).contains(counts[key, default: 0]),
                         "Seeded sample remains approximately uniform over all eligible dates")
        }
        var firstRandom = Seeded()
        var secondRandom = Seeded()
        let first = MemoryShuffle.draw(from: keys, using: &firstRandom)!
        let second = MemoryShuffle.draw(from: keys, using: &secondRandom)!
        precondition(first.dayKey == second.dayKey && first.id != second.id,
                     "The same random input can select the same date in consecutive fresh presentations")
        var duplicateRandom = Seeded()
        var uniqueRandom = Seeded()
        for _ in 0..<100 {
            precondition(MemoryShuffle.draw(from: keys + [keys[0]], using: &duplicateRandom)?.dayKey
                         == MemoryShuffle.draw(from: keys, using: &uniqueRandom)?.dayKey,
                         "Duplicate revisions do not increase a calendar day's probability")
        }
        precondition(MemoryShuffle.draw(from: [], using: &random) == nil)
        precondition(MemoryShuffle.draw(from: [keys[0]], using: &random)?.dayKey == keys[0])
        let remaining = Array(keys.dropFirst())
        for _ in 0..<100 {
            precondition(remaining.contains(MemoryShuffle.draw(from: remaining, using: &random)!.dayKey),
                         "Hidden or removed dates are never drawn")
        }

        let suite = "MoodCalendar.MemoryChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MemoryDiscoveryStore(defaults: defaults)
        store.hide("2024-02-29")
        store.hide("invalid")
        precondition(store.hiddenDays == ["2024-02-29"])
        let reopened = MemoryDiscoveryStore(defaults: defaults)
        precondition(reopened.hiddenDays == ["2024-02-29"], "Hidden choices reopen")
        let demo = MemoryDiscoveryStore(defaults: defaults, inMemory: true)
        precondition(demo.hiddenDays.isEmpty, "Demo never reads production choices")
        demo.hide("2024-01-31")
        precondition(MemoryDiscoveryStore(defaults: defaults).hiddenDays == ["2024-02-29"], "Demo never writes production choices")
        reopened.restore("2024-02-29")
        precondition(MemoryDiscoveryStore(defaults: defaults).hiddenDays.isEmpty)
        precondition(leap.note == "Original" && replacement.note == "Revised", "Rediscovery does not mutate entries")
        print("Memory rediscovery, independent uniform draws, repeat identities and hidden-date persistence checks passed")
    }
}
