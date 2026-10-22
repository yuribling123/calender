import Foundation
import SwiftData

#if os(macOS)
// Only raw IDs are needed by the importer. The actual iOS palette depends on UIKit.
enum CardPaper: String {
    case original, pink, apricot, yellow, green, blue, purple, caramel, black
}
#endif

@main
struct DataBackupChecks {
    @MainActor
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        func plan(_ name: String, days: Set<String> = [], months: Set<String> = []) throws -> DataBackupImportPlan {
            try DataBackupImporter.makePlan(from: Data(contentsOf: directory.appendingPathComponent(name)),
                                            existingDayKeys: days, existingMonthKeys: months)
        }
        func expect(_ condition: @autoclosure () -> Bool) {
            let result = condition()
            precondition(result)
        }
        func rejects(_ name: String) {
            do { _ = try plan(name); preconditionFailure("Expected invalid backup rejection: \(name)") }
            catch { }
        }

        #if LEGACY_IMPORT_CHECK
        // The repaired copy must also work with the import code from before this fix.
        rejects("legacy-duplicates.zip")
        let repaired = try plan("normalized.zip")
        expect(repaired.entriesToImport.count == 1 && repaired.monthlyNotesToImport.count == 1)
        if CommandLine.arguments.count == 4 {
            let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
            do {
                _ = try DataBackupImporter.makePlan(from: original, existingDayKeys: [], existingMonthKeys: [])
                preconditionFailure("Expected supplied original to reproduce the pre-fix failure")
            } catch { }
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
            _ = try DataBackupImporter.makePlan(from: data, existingDayKeys: [], existingMonthKeys: [])
        }
        print("PASS: pre-fix importer reproduces failure and accepts normalized backups")
        #else
        let imported = try plan("legacy-duplicates.zip")
        expect(imported.entriesToImport.count == 1)
        expect(imported.entriesToImport.first?.note == "new")
        expect(imported.photoCount == 1)
        expect(imported.monthlyNotesToImport.count == 1)
        expect(imported.monthlyNotesToImport.first?.text == "new month")
        let filtered = try plan("legacy-duplicates.zip", days: ["2024-02-29"], months: ["2024-02"])
        expect(filtered.entriesToImport.isEmpty && filtered.monthlyNotesToImport.isEmpty)
        expect(filtered.existingEntryCount == 1 && filtered.existingMonthlyNoteCount == 1)
        rejects("conflicting-photos.zip")
        rejects("corrupt-crc.zip")
        rejects("invalid-date.zip")

        func models(_ plan: DataBackupImportPlan) -> ([MoodEntry], [MonthlyNote]) {
            let entries = plan.entriesToImport.map { item in
                let entry = MoodEntry(dayKey: item.dayKey, choice: DailyChoice(rawValue: item.choiceID)!, note: item.note)
                entry.updatedAt = item.updatedAt
                entry.cardPaperID = item.cardPaperID
                entry.photoData = item.photoData
                entry.songTitle = item.songTitle
                entry.songArtist = item.songArtist
                entry.watchTitle = item.watchTitle
                entry.watchKind = item.watchKind
                entry.watchNote = item.watchNote
                return entry
            }
            let notes = plan.monthlyNotesToImport.map { item in
                let note = MonthlyNote(monthKey: item.monthKey, text: item.text)
                note.updatedAt = item.updatedAt
                return note
            }
            return (entries, notes)
        }
        let (entries, notes) = models(imported)
        let stale = MoodEntry(dayKey: "2024-02-29", choice: .bad, note: "stale")
        stale.updatedAt = .distantPast
        stale.photoData = Data([0xff, 0xd8, 0, 0xff, 0xd9])
        let oldNote = MonthlyNote(monthKey: "2024-02", text: "stale month")
        oldNote.updatedAt = .distantPast
        let normalized = try DataBackupExporter.makeArchive(entries: entries + [stale], monthlyNotes: notes + [oldNote],
                                                           monthlyNoteSkins: imported.monthlyNoteSkins)
        try normalized.write(to: directory.appendingPathComponent("normalized.zip"))
        let roundTrip = try DataBackupImporter.makePlan(from: normalized, existingDayKeys: [], existingMonthKeys: [])
        expect(roundTrip.entriesToImport.count == 1 && roundTrip.entriesToImport.first?.note == "new")
        expect(roundTrip.entriesToImport.first?.photoData == entries.first?.photoData)
        expect(roundTrip.monthlyNotesToImport.count == 1 && roundTrip.monthlyNotesToImport.first?.text == "new month")
        expect(roundTrip.monthlyNoteSkins == imported.monthlyNoteSkins)

        // New optional fields must survive export/import, while old backups stay readable.
        expect(imported.entriesToImport.first?.watchTitle == nil)
        entries[0].watchTitle = "测试电影"
        entries[0].watchKind = "movie"
        entries[0].watchNote = "想再看一次"
        let watchedArchive = try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: [])
        let watchedPlan = try DataBackupImporter.makePlan(from: watchedArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(watchedPlan.entriesToImport.first?.watchTitle == "测试电影")
        expect(watchedPlan.entriesToImport.first?.watchKind == "movie")
        expect(watchedPlan.entriesToImport.first?.watchNote == "想再看一次")
        expect(DataBackupExporter.readableText(entries: entries, monthlyNotes: []).contains("测试电影"))
        entries[0].watchKind = nil
        entries[0].watchNote = nil
        let titleOnlyArchive = try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: [])
        let titleOnlyPlan = try DataBackupImporter.makePlan(from: titleOnlyArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(titleOnlyPlan.entriesToImport.first?.watchTitle == "测试电影")
        expect(titleOnlyPlan.entriesToImport.first?.watchKind == nil)
        expect(titleOnlyPlan.entriesToImport.first?.watchNote == nil)

        let schema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self])
        let watchStoreURL = directory.appendingPathComponent("watch-restore.store")
        func restoreWatchToDisk() throws {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: watchStoreURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            let result = try DataBackupImporter.restore(watchedPlan, into: context)
            expect(result.entries == 1)
        }
        try restoreWatchToDisk()
        do {
            let reopened = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: watchStoreURL, cloudKitDatabase: .none))
            let context = ModelContext(reopened)
            let record = try context.fetch(FetchDescriptor<MoodEntry>()).first!
            expect(record.watchTitle == "测试电影")
            expect(record.watchKind == "movie")
            expect(record.watchNote == "想再看一次")
            record.watchTitle = "本机改过的片名"
            try context.save()
            let repeated = try DataBackupImporter.restore(watchedPlan, into: context)
            expect(repeated.entries == 0)
            expect(record.watchTitle == "本机改过的片名")
            let watchCount = try context.fetchCount(FetchDescriptor<MoodEntry>())
            expect(watchCount == 1)

            // Export only surviving records, including no orphaned photo for a deleted day.
            let previous = UserDefaults.standard.object(forKey: "allowPastDateEditing")
            UserDefaults.standard.set(true, forKey: "allowPastDateEditing")
            defer {
                if let previous { UserDefaults.standard.set(previous, forKey: "allowPastDateEditing") }
                else { UserDefaults.standard.removeObject(forKey: "allowPastDateEditing") }
            }
            let date = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
            try EntryStore(context: context).delete(day: DayKey(date))
            let remaining = try context.fetch(FetchDescriptor<MoodEntry>())
            let deletedArchive = try DataBackupExporter.makeArchive(entries: remaining, monthlyNotes: [])
            let deletedPlan = try DataBackupImporter.makePlan(from: deletedArchive, existingDayKeys: [], existingMonthKeys: [])
            expect(deletedPlan.entriesToImport.isEmpty && deletedPlan.photoCount == 0)
            expect(!DataBackupExporter.readableText(entries: remaining, monthlyNotes: []).contains("2024-02-29"))
            try deletedArchive.write(to: directory.appendingPathComponent("after-deletion.zip"))

            // Import is a deliberate restore: an older backup can bring a deleted day back.
            let oldBackup = try DataBackupImporter.makePlan(from: watchedArchive, existingDayKeys: [], existingMonthKeys: [])
            let recovered = try DataBackupImporter.restore(oldBackup, into: context)
            expect(recovered.entries == 1)
            let recoveredRecord = try context.fetch(FetchDescriptor<MoodEntry>()).first!
            expect(recoveredRecord.photoData == entries[0].photoData)
            expect(recoveredRecord.watchTitle == "测试电影")
        }
        do {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let context = ModelContext(store)
            _ = try DataBackupImporter.restore(titleOnlyPlan, into: context)
            let record = try context.fetch(FetchDescriptor<MoodEntry>()).first!
            expect(record.watchTitle == "测试电影")
            expect(record.watchKind == nil && record.watchNote == nil)
        }
        let container = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        // Every registered style must survive archive encoding and SwiftData restore.
        for style in MonthlyNoteSkin.allCases {
            let styleContainer = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let styleContext = ModelContext(styleContainer)
            let selections = ["2024-02": style.rawValue]
            let archive = try DataBackupExporter.makeArchive(entries: [], monthlyNotes: [], monthlyNoteSkins: selections)
            let stylePlan = try DataBackupImporter.makePlan(from: archive, existingDayKeys: [], existingMonthKeys: [])
            expect(stylePlan.monthlyNoteSkins == selections)
            _ = try DataBackupImporter.restore(stylePlan, into: styleContext)
            let restoredSelections = try MonthlyNoteSkinStore(context: styleContext).backupSelections()
            expect(restoredSelections == selections)
        }
        print("PASS: all monthly note styles survive archive export, import and persistence")
        let context = ModelContext(container)
        let restored = try DataBackupImporter.restore(imported, into: context)
        expect(restored.entries == 1 && restored.monthlyNotes == 1)
        let savedEntries = try context.fetch(FetchDescriptor<MoodEntry>())
        expect(savedEntries.count == 1 && savedEntries.first?.note == "new")
        expect(savedEntries.first?.photoData == entries.first?.photoData)
        let skin = try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>()).first!
        skin.skinID = "plain"
        try context.save()
        let repeated = try DataBackupImporter.restore(imported, into: context)
        expect(repeated.entries == 0 && repeated.monthlyNotes == 0)
        expect(skin.skinID == "plain")
        let savedCount = try context.fetchCount(FetchDescriptor<MoodEntry>())
        expect(savedCount == 1)

        if CommandLine.arguments.count == 4 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
            let actual = try DataBackupImporter.makePlan(from: data, existingDayKeys: [], existingMonthKeys: [])
            let (actualEntries, actualNotes) = models(actual)
            let repaired = try DataBackupExporter.makeArchive(entries: actualEntries, monthlyNotes: actualNotes,
                                                             monthlyNoteSkins: actual.monthlyNoteSkins)
            try repaired.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
            let result = try DataBackupImporter.makePlan(from: repaired, existingDayKeys: [], existingMonthKeys: [])
            expect(result.entriesToImport.count == actual.entriesToImport.count)
            expect(result.monthlyNotesToImport.count == actual.monthlyNotesToImport.count)
            expect(result.monthlyNoteSkins == actual.monthlyNoteSkins)
            expect(result.photoCount == actual.photoCount)
            print("PASS: supplied backup normalized: \(result.entriesToImport.count) days, \(result.monthlyNotesToImport.count) notes, \(result.photoCount) photos, \(result.monthlyNoteSkins.count) styles")
        }
        print("PASS: duplicate recovery, latest records, photo consistency, CRC rejection, export round trip and idempotent restore")
        #endif
    }
}
