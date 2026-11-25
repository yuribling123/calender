import Foundation
import SwiftData

#if os(macOS)
// Only raw IDs are needed by the importer. The actual iOS palette depends on UIKit.
enum CardPaper: String {
    case original, pink, apricot, yellow, green, blue, purple, caramel, black, hearts, stars, silverStars, creamStars, roseStars
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
        func expect(_ condition: @autoclosure () -> Bool, line: UInt = #line) {
            let result = condition()
            precondition(result, line: line)
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
        expect(imported.futureLetters.isEmpty && imported.monthlyZineDrafts.isEmpty)
        #if !LEGACY_IMPORT_CHECK
        let appearanceSchema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self, CalendarAppearanceSelection.self])
        let appearance = ["appTheme": "sage", "selectionShape": "sakura", "calendarBookmarkStyle": "highlighter"]
        let appearanceArchive = try DataBackupExporter.makeArchive(entries: [], monthlyNotes: [],
            appearance: appearance.merging(["futureOption": "value"]) { current, _ in current })
        let appearancePlan = try DataBackupImporter.makePlan(from: appearanceArchive,
            existingDayKeys: [], existingMonthKeys: [])
        expect(appearancePlan.appearance == appearance && appearancePlan.entriesToImport.isEmpty)
        expect(imported.appearance.isEmpty)
        let emptyLegacyArchive = try DataBackupExporter.makeArchive(entries: [], monthlyNotes: [])
        let emptyLegacyPlan = try DataBackupImporter.makePlan(from: emptyLegacyArchive, existingDayKeys: [], existingMonthKeys: [])
        let appearanceURL = directory.appendingPathComponent("appearance.store")
        do {
            let previousSchema = Schema([MoodEntry.self, MonthlyNote.self,
                                         MonthlyNoteSkinSelection.self, StarredDaySelection.self])
            let store = try ModelContainer(for: previousSchema, configurations:
                ModelConfiguration(schema: previousSchema, url: appearanceURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            context.insert(MoodEntry(dayKey: "2024-02-29", choice: .good, note: "existing entry"))
            try context.save()
        }
        do {
            let store = try ModelContainer(for: appearanceSchema, configurations:
                ModelConfiguration(schema: appearanceSchema, url: appearanceURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            let preferences = CalendarAppearanceStore(context: context)
            let defaultsBeforeMigration = try preferences.backupValues()
            expect(defaultsBeforeMigration == ["appTheme": "black", "selectionShape": "sakura",
                                               "calendarBookmarkStyle": "dateColor"])
            let suite = "MoodCalendarAppearanceChecks." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set("pink", forKey: "appTheme")
            defaults.set("circle", forKey: "selectionShape")
            try preferences.migrateLegacySelections(defaults: defaults)
            let migrated = try preferences.backupValues()
            expect(migrated == ["appTheme": "pink", "selectionShape": "circle", "calendarBookmarkStyle": "dateColor"])
            expect(defaults.object(forKey: "appTheme") == nil)
            _ = try DataBackupImporter.restore(appearancePlan, into: context)
            let originalCount = try context.fetchCount(FetchDescriptor<CalendarAppearanceSelection>())
            _ = try DataBackupImporter.restore(appearancePlan, into: context)
            _ = try DataBackupImporter.restore(emptyLegacyPlan, into: context)
            let finalCount = try context.fetchCount(FetchDescriptor<CalendarAppearanceSelection>())
            expect(finalCount == originalCount)
            context.insert(CalendarAppearanceSelection(key: "appTheme", value: "pink",
                                                       updatedAt: Date(timeIntervalSince1970: 0)))
            try context.save()
        }
        do {
            let store = try ModelContainer(for: appearanceSchema, configurations:
                ModelConfiguration(schema: appearanceSchema, url: appearanceURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            let restored = try CalendarAppearanceStore(context: context).backupValues()
            expect(restored == appearance)
            let entries = try context.fetch(FetchDescriptor<MoodEntry>())
            expect(entries.count == 1 && entries.first?.note == "existing entry")
        }
        if CommandLine.arguments.contains("--appearance-only") {
            print("Calendar appearance backup and migration checks passed")
            return
        }
        #endif
        // Local letters and editorial drafts travel with a ZIP, including a
        // letters-only archive. Restoring never replaces an existing local ID.
        let letter = FutureLetter(id: UUID(), title: "给以后", body: "一段私人的正文",
            writtenDay: DayKey(Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 28, hour: 12))!),
            deliveryDay: DayKey(Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12))!),
            createdAt: Date(timeIntervalSince1970: 1_709_078_400),
            updatedAt: Date(timeIntervalSince1970: 1_709_078_400), openedAt: nil)
        var zine = MonthlyZineDraft()
        zine.title = "二月的小刊"
        zine.selectedDayKeys = ["2024-02-29"]
        zine.introduction = "想留下的二月"
        let localArchive = try DataBackupExporter.makeArchive(entries: [], monthlyNotes: [],
            futureLetters: [letter], monthlyZineDrafts: ["2024-02": zine])
        let localPlan = try DataBackupImporter.makePlan(from: localArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(localPlan.futureLetters == [letter])
        expect(localPlan.monthlyZineDrafts == ["2024-02": zine])
        let lettersURL = directory.appendingPathComponent("future-letters.json")
        let letters = FutureLetterStore(fileURL: lettersURL)
        try letters.importLetters(localPlan.futureLetters)
        try letters.open(letter.id)
        try letters.importLetters(localPlan.futureLetters)
        let reopenedLetters = FutureLetterStore(fileURL: lettersURL)
        expect(reopenedLetters.letters.count == 1 && reopenedLetters.letters[0].isOpened)
        let draftsURL = directory.appendingPathComponent("zine-drafts.json")
        let drafts = MonthlyZineDraftStore(fileURL: draftsURL)
        try drafts.mergeImportedDrafts(localPlan.monthlyZineDrafts)
        var localDraft = zine
        localDraft.title = "本机修改的标题"
        try drafts.save(localDraft, for: "2024-02")
        try drafts.mergeImportedDrafts(localPlan.monthlyZineDrafts)
        expect(MonthlyZineDraftStore(fileURL: draftsURL).draft(for: "2024-02")?.title == localDraft.title)
        expect(filtered.entriesToImport.isEmpty && filtered.monthlyNotesToImport.isEmpty)
        expect(filtered.existingEntryCount == 1 && filtered.existingMonthlyNoteCount == 1)
        rejects("conflicting-photos.zip")
        rejects("corrupt-crc.zip")
        rejects("invalid-letter.zip")
        rejects("invalid-zine.zip")
        rejects("invalid-date.zip")
        rejects("invalid-bookmark.zip")
        expect(imported.starredDays.isEmpty)

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
        func entryPlan(for entries: [MoodEntry]) throws -> DataBackupImportPlan {
            let archive = try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: [])
            return try DataBackupImporter.makePlan(from: archive, existingDayKeys: [], existingMonthKeys: [])
        }
        func withEntryStore(
            at url: URL,
            schema: Schema,
            perform: (ModelContext) throws -> Void
        ) throws {
            let container = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            try perform(ModelContext(container))
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

        // New member stickers must round-trip without changing any saved IDs.
        let everydayEntries = [
            MoodEntry(dayKey: "2024-02-29", choice: .cooking, note: "做饭"),
            MoodEntry(dayKey: "2024-03-01", choice: .gaming, note: "打游戏"),
            MoodEntry(dayKey: "2024-03-02", choice: .tastyFood, note: "吃好吃的"),
            MoodEntry(dayKey: "2024-03-03", choice: .watchingShows, note: "看剧"),
            MoodEntry(dayKey: "2024-03-04", choice: .walking, note: "散步"),
            MoodEntry(dayKey: "2024-03-05", choice: .shopping, note: "逛街")
        ]
        let everydayPlan = try entryPlan(for: everydayEntries)
        expect(Set(everydayPlan.entriesToImport.map(\.choiceID)) == [31, 32, 33, 34, 35, 36])
        expect(DailyChoice.choices(in: .everyday) == [.cooking, .gaming, .tastyFood, .watchingShows, .shopping])
        expect(DailyChoice(rawValue: 35) == .walking) // Historical walks stay readable.
        expect(DailyChoice.cooking.group == .everyday && DailyChoice.gaming.group == .everyday)

        let weather = DailyChoice.choices(in: .weather)
        expect(weather == [.rainbow, .sunshine, .rain, .snow, .wind])
        expect(weather.map(\.rawValue) == [37, 38, 39, 40, 41])
        expect(weather.allSatisfy { $0.group == .weather && $0.group.requiresMembership })
        let weatherEntries = weather.enumerated().map { index, choice in
            MoodEntry(dayKey: "2024-03-0\(index + 1)", choice: choice, note: choice.title)
        }
        let weatherText = DataBackupExporter.readableText(entries: weatherEntries, monthlyNotes: [])
        expect(weather.allSatisfy { weatherText.contains($0.title) })
        let weatherPlan = try entryPlan(for: weatherEntries)
        expect(Set(weatherPlan.entriesToImport.map(\.choiceID)) == Set(37...41))
        let weatherStoreURL = directory.appendingPathComponent("weather.store")
        let weatherSchema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self])
        try withEntryStore(at: weatherStoreURL, schema: weatherSchema) { context in
            _ = try DataBackupImporter.restore(weatherPlan, into: context)
            _ = try DataBackupImporter.restore(weatherPlan, into: context)
            let restoredWeatherCount = try context.fetchCount(FetchDescriptor<MoodEntry>())
            expect(restoredWeatherCount == 5)
            for choice in weather {
                do {
                    try EntryStore(context: context).save(day: DayKey(Date()), choice: choice, note: "blocked")
                    preconditionFailure("Weather sticker accepted without membership")
                } catch {
                    expect(error.localizedDescription == localized("解锁永久会员后才能使用这套表情。"))
                }
                try EntryStore(context: context).save(day: DayKey(Date()), choice: choice, note: "member", isMember: true)
            }
        }
        try withEntryStore(at: weatherStoreURL, schema: weatherSchema) { context in
            let records = try context.fetch(FetchDescriptor<MoodEntry>())
            expect(records.count == 6) // Five imported days and one updated today.
            expect(Set(records.compactMap(\.choice)) == Set(weather))
            expect(records.first { $0.dayKey == DayKey(Date()).storageValue }?.choice == .wind)
        }
        print("PASS: weather membership gate, stable IDs, backup round trip and reopened records")

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
        expect(DataBackupExporter.readableText(entries: entries, monthlyNotes: []).contains("电影 · 测试电影"))
        let seriesEntry = MoodEntry(dayKey: "2024-03-01", choice: .good, note: "追剧")
        seriesEntry.watchTitle = "测试剧集"
        seriesEntry.watchKind = WatchKind.series.rawValue
        seriesEntry.watchNote = "下一集继续"
        let seriesArchive = try DataBackupExporter.makeArchive(entries: [seriesEntry], monthlyNotes: [])
        let seriesPlan = try DataBackupImporter.makePlan(from: seriesArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(seriesPlan.entriesToImport.first?.watchTitle == "测试剧集")
        expect(seriesPlan.entriesToImport.first?.watchKind == "series")
        expect(seriesPlan.entriesToImport.first?.watchNote == "下一集继续")
        expect(DataBackupExporter.readableText(entries: [seriesEntry], monthlyNotes: []).contains("剧集 · 测试剧集"))
        expect(DataBackupExporter.readableText(entries: entries, monthlyNotes: []).contains("测试电影"))
        entries[0].watchKind = nil
        entries[0].watchNote = nil
        let titleOnlyArchive = try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: [])
        let titleOnlyPlan = try DataBackupImporter.makePlan(from: titleOnlyArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(titleOnlyPlan.entriesToImport.first?.watchTitle == "测试电影")
        expect(titleOnlyPlan.entriesToImport.first?.watchKind == nil)
        expect(titleOnlyPlan.entriesToImport.first?.watchNote == nil)

        for paperID in ["hearts", "stars", "silverStars", "creamStars", "roseStars"] {
            let patterned = MoodEntry(dayKey: "2024-02-29", choice: .good, note: "纸上的文字")
            patterned.cardPaperID = paperID
            let archive = try DataBackupExporter.makeArchive(entries: [patterned], monthlyNotes: [])
            let plan = try DataBackupImporter.makePlan(from: archive, existingDayKeys: [], existingMonthKeys: [])
            expect(plan.entriesToImport.first?.cardPaperID == paperID)
        }

        let schema = Schema([MoodEntry.self, MonthlyNote.self, MonthlyNoteSkinSelection.self, StarredDaySelection.self])
        // Import must preserve premium appearance without granting membership.
        let paperStoreURL = directory.appendingPathComponent("premium-papers.store")
        let premiumIDs = ["silverStars", "creamStars", "roseStars"]
        do {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: paperStoreURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            for (index, id) in premiumIDs.enumerated() {
                let record = MoodEntry(dayKey: "2024-02-\(27 + index)", choice: .good, note: id)
                record.cardPaperID = id
                let archive = try DataBackupExporter.makeArchive(entries: [record], monthlyNotes: [])
                let plan = try DataBackupImporter.makePlan(from: archive, existingDayKeys: [], existingMonthKeys: [])
                _ = try DataBackupImporter.restore(plan, into: context)
            }
        }
        do {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: paperStoreURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            let records = try context.fetch(FetchDescriptor<MoodEntry>())
            expect(Set(records.compactMap(\.cardPaperID)) == Set(premiumIDs))
            expect(!CardPaperAccess.requiresMembership("stars"))
            for id in premiumIDs {
                expect(CardPaperAccess.requiresMembership(id))
                do {
                    try EntryStore(context: context).save(day: DayKey(Date()), choice: .good,
                        note: "blocked", cardPaperID: id, updatesCardPaper: true)
                    fatalError("Premium paper accepted without membership")
                } catch { }
            }
            try EntryStore(context: context).save(day: DayKey(Date()), choice: .good,
                note: "member", isMember: true, cardPaperID: "roseStars", updatesCardPaper: true)
            try EntryStore(context: context).save(day: DayKey(Date()), choice: .good,
                note: "retain existing paper", cardPaperID: "roseStars", updatesCardPaper: true)
        }
        let bookmarkArchive = try DataBackupExporter.makeArchive(entries: [], monthlyNotes: [],
            starredDays: ["2024-02-29": true, "2025-12-31": false, "2027-01-01": true])
        let bookmarkPlan = try DataBackupImporter.makePlan(from: bookmarkArchive, existingDayKeys: [], existingMonthKeys: [])
        expect(bookmarkPlan.starredDays.count == 3 && bookmarkPlan.entriesToImport.isEmpty)
        let bookmarkURL = directory.appendingPathComponent("bookmarks.store")
        do {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: bookmarkURL, cloudKitDatabase: .none))
            let context = ModelContext(store)
            context.insert(StarredDaySelection(dayKey: "2024-02-29", isStarred: false))
            try context.save()
            _ = try DataBackupImporter.restore(bookmarkPlan, into: context)
            _ = try DataBackupImporter.restore(bookmarkPlan, into: context)
            let bookmarkCount = try context.fetchCount(FetchDescriptor<StarredDaySelection>())
            expect(bookmarkCount == 3)
        }
        do {
            let store = try ModelContainer(for: schema, configurations:
                ModelConfiguration(schema: schema, url: bookmarkURL, cloudKitDatabase: .none))
            let restored = try StarredDayPersistence(context: ModelContext(store)).backupSelections()
            expect(restored == ["2024-02-29": false, "2025-12-31": false, "2027-01-01": true])
        }
        expect(DataBackupExporter.readableText(entries: [], monthlyNotes: [], starredDays: ["2024-02-29": true]).contains("2024-02-29"))
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
