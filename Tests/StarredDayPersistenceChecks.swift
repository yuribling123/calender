import Foundation
import SwiftData

@main
struct StarredDayPersistenceChecks {
    @MainActor
    static func main() throws {
        let mode = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let oldSchema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self])
        let schema = mode == "seed" ? oldSchema : Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self])
        let container = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let suite = "MoodCalendar.BookmarkChecks.\(url.deletingLastPathComponent().lastPathComponent)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = StarredDayPersistence(context: context, defaults: defaults)
        func expect(_ condition: @autoclosure () throws -> Bool) rethrows { let result = try condition(); precondition(result) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))!
        func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
            DayKey(calendar.date(from: DateComponents(year: year, month: month, day: day))!, calendar: calendar)
        }
        if mode == "seed" {
            context.insert(MoodEntry(dayKey: "2024-02-29", choice: .good, note: "Keep me"))
            context.insert(MonthlyNote(monthKey: "2024-02", text: "Keep note"))
            context.insert(MonthlyNoteSkinSelection(monthKey: "2024-02", skin: .grid))
            try context.save()
            print("PASS: seeded existing three-model store")
            return
        }
        try expect(try context.fetch(FetchDescriptor<MoodEntry>()).first?.note == "Keep me")
        try expect(try context.fetchCount(FetchDescriptor<MonthlyNote>()) == 1)
        try expect(try context.fetchCount(FetchDescriptor<MonthlyNoteSkinSelection>()) == 1)
        if mode == "reopen" {
            try expect(try store.backupSelections()["2024-02-29"] == false)
            try expect(try store.backupSelections()["2027-01-01"] == true)
            defaults.removePersistentDomain(forName: suite)
            print("PASS: reopened marks, unmarks and existing records in separate process")
            return
        }
        defaults.set("[\"2024-02-29\",\"2025-12-31\",\"2026-01-01\",\"2023-02-29\"]", forKey: "starredDays.v1")
        try store.migrateLegacySelections()
        try store.migrateLegacySelections()
        try expect(try store.backupSelections().count == 3)
        expect(defaults.object(forKey: "starredDays.v1") == nil)
        defaults.set(false, forKey: "allowPastDateEditing")
        do {
            try store.toggle(day(2024, 2, 29), now: now)
            preconditionFailure("Past-day restriction must be enforced in persistence")
        } catch { }
        try expect(try store.backupSelections()["2024-02-29"] == true)
        try store.toggle(DayKey(now), now: now)
        try store.toggle(day(2027, 1, 1), now: now)
        defaults.set(true, forKey: "allowPastDateEditing")
        try store.toggle(day(2024, 2, 29), now: now)
        // Simulate a delayed migration record arriving from an offline device.
        context.insert(StarredDaySelection(dayKey: "2024-02-29", isStarred: true, updatedAt: .init(timeIntervalSince1970: 0)))
        try context.save()
        try expect(try store.backupSelections()["2024-02-29"] == false)
        let memory = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let memoryStore = StarredDayPersistence(context: ModelContext(memory), defaults: defaults)
        try expect(try memoryStore.backupSelections().isEmpty)
        try memoryStore.toggle(day(2027, 1, 1), now: now)
        try memoryStore.toggle(day(2027, 1, 1), now: now)
        try expect(try memoryStore.backupSelections()["2027-01-01"] == false)
        try expect(try store.backupSelections()["2027-01-01"] == true)
        for key in ["2024-02-29", "2024-03-01", "2025-12-31", "2026-01-01"] {
            expect(StarredDayPersistence.isValidDayKey(key))
        }
        expect(!StarredDayPersistence.isValidDayKey("2023-02-29"))
        print("PASS: additive migration, legacy migration, date permissions, duplicate resolution, unmarks and Demo isolation")
    }
}
