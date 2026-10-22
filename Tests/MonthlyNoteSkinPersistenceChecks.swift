import Foundation
import SwiftData

/// Standalone persistence checks; see run-monthly-note-skin-checks.sh.
@main
struct MonthlyNoteSkinPersistenceChecks {
    @MainActor
    static func main() throws {
        let mode = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let schema = mode == "seed"
            ? Schema([MoodEntry.self, MonthlyNote.self])
            : Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let suite = "MoodCalendar.SkinChecks.\(url.deletingLastPathComponent().lastPathComponent)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = MonthlyNoteSkinStore(context: context, defaults: defaults)
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20))!

        func selections() throws -> [MonthlyNoteSkinSelection] {
            try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>())
        }
        func skin(_ month: String) throws -> MonthlyNoteSkin {
            MonthlyNoteSkinStore.skin(for: month, in: try selections())
        }
        func expect(_ condition: @autoclosure () throws -> Bool) rethrows {
            let result = try condition()
            precondition(result)
        }
        func rejects(_ operation: () throws -> Void) {
            do { try operation(); preconditionFailure("Expected a read-only or membership rejection") }
            catch { }
        }

        if mode == "seed" {
            context.insert(MoodEntry(dayKey: "2024-02-29", choice: .good, note: "Leap-day entry"))
            context.insert(MonthlyNote(monthKey: "2024-02", text: "Original monthly note"))
            try context.save()
            print("PASS: created original two-model store")
            return
        }

        if mode == "reopen" {
            try expect(try skin("2026-10") == .plain)
            try expect(try skin("2024-02") == .lace)
            try expect(try context.fetchCount(FetchDescriptor<MonthlyNote>()) == 1)
            try expect(try context.fetchCount(FetchDescriptor<MoodEntry>()) == 1)
            try expect(try selections().filter { $0.monthKey == "2026-10" }.count == 1)
            defaults.removePersistentDomain(forName: suite)
            print("PASS: reopened saved selections, plain reset and existing records")
            return
        }

        // Adding the style model must preserve the original on-disk records.
        try expect(try context.fetch(FetchDescriptor<MoodEntry>()).first?.dayKey == "2024-02-29")
        try expect(try context.fetch(FetchDescriptor<MonthlyNote>()).first?.text == "Original monthly note")
        defaults.set(["2024-02": "lace", "2025-12": "grid", "invalid": "ticket"], forKey: "monthlyNoteSkins.v1")
        try store.migrateLegacySelections()
        try store.migrateLegacySelections()
        precondition(defaults.object(forKey: "monthlyNoteSkins.v1") == nil)
        try expect(try skin("2024-02") == .lace)
        try expect(try selections().count == 2)

        // A migrated choice arriving later must not replace a newer user choice.
        try store.select(.ticket, for: "2026-10", isMember: true, now: now)
        context.insert(MonthlyNoteSkinSelection(monthKey: "2026-10", skin: .grid,
                                               updatedAt: Date(timeIntervalSince1970: 0)))
        try context.save()
        try expect(try skin("2026-10") == .ticket)
        try store.reconcileDuplicates()
        try expect(try selections().filter { $0.monthKey == "2026-10" }.count == 1)
        try store.select(.plain, for: "2026-10", isMember: false, now: now.addingTimeInterval(1))
        try expect(try store.backupSelections()["2026-10"] == "plain")
        defaults.set(["2026-10": "ticket"], forKey: "monthlyNoteSkins.v1")
        try store.migrateLegacySelections()
        try expect(try skin("2026-10") == .plain)
        // No fabricated empty monthly notes, even for a style-only month.
        try expect(try context.fetchCount(FetchDescriptor<MonthlyNote>()) == 1)

        let temporaryNote = MonthlyNote(monthKey: "2026-10", text: "Temporary note")
        context.insert(temporaryNote)
        try context.save()
        context.delete(temporaryNote)
        try context.save()
        try expect(try skin("2026-10") == .plain)

        // Month boundaries, invalid months, past editing and membership restrictions.
        let january = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        try store.select(.grid, for: "2025-12", isMember: false, now: january)
        rejects { try store.select(.grid, for: "2026-02", isMember: false, now: january) }
        try store.select(.grid, for: "2025-12", isMember: false, now: now)
        rejects { try store.select(.grid, for: "2026-11", isMember: false, now: now) }
        rejects { try store.select(.grid, for: "2026-13", isMember: false, now: now) }
        rejects { try store.select(.lace, for: "2026-10", isMember: false, now: now) }
        defaults.set(false, forKey: "allowPastDateEditing")
        rejects { try store.select(.plain, for: "2024-02", isMember: true, now: now) }
        try store.select(.plain, for: "2026-10", isMember: false, now: now.addingTimeInterval(2))
        defaults.set(true, forKey: "allowPastDateEditing")

        // Backup merge preserves local choices and months with existing note text.
        try store.restore(["2026-10": "ticket", "2024-02": "grid", "2023-01": "ticket", "2023-02": "lace"],
                          excluding: ["2023-01"])
        try context.save()
        try expect(try skin("2026-10") == .plain)
        try expect(try skin("2024-02") == .lace)
        try expect(try skin("2023-02") == .lace)
        try expect(try store.backupSelections()["2023-01"] == nil)
        let backup = try store.backupSelections()
        let memory = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let memoryContext = ModelContext(memory)
        let memoryStore = MonthlyNoteSkinStore(context: memoryContext, defaults: defaults)
        try memoryStore.restore(backup, excluding: [])
        try memoryContext.save()
        try expect(try memoryStore.backupSelections() == backup)
        try memoryStore.select(.ticket, for: "2026-10", isMember: true, now: now)
        try expect(try skin("2026-10") == .plain)
        print("PASS: additive migration, legacy preferences, duplicates, date rules, backup merge and memory isolation")
    }
}
