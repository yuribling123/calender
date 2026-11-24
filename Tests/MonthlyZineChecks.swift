import Foundation

@main
struct MonthlyZineChecks {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 12))!
        let february = MonthlyZine.date(for: "2024-02", calendar: calendar)!
        precondition(MonthlyZine.date(for: "2024-13", calendar: calendar) == nil)
        precondition(MonthlyZine.date(for: "2024-2", calendar: calendar) == nil)
        precondition(MonthlyZine.dayDate("2024-02-29", calendar: calendar) != nil)
        precondition(MonthlyZine.dayDate("2023-02-29", calendar: calendar) == nil)
        precondition(MonthlyZine.dayDate("2024-02-30", calendar: calendar) == nil)
        func entry(_ day: String, _ note: String) -> MoodEntry {
            MoodEntry(dayKey: day, choice: .good, note: note)
        }
        let old = entry("2024-02-29", "old")
        let new = entry("2024-02-29", "new")
        new.updatedAt = old.updatedAt.addingTimeInterval(1)
        let all = [old, new, entry("2024-02-01", "first"), entry("2024-02-30", "invalid"),
                   entry("2024-03-01", "next month"), entry("2025-02-01", "future")]
        let selected = MonthlyZine.memories(in: february, entries: all, today: today, calendar: calendar)
        precondition(selected.map(\.dayKey) == ["2024-02-01", "2024-02-29"])
        precondition(selected.last?.note == "new", "Newest daily revision is used exactly once")
        precondition(old.note == "old", "Preparing a zine must never change source records")
        precondition(MonthlyZine.memories(in: MonthlyZine.date(for: "2025-02", calendar: calendar)!, entries: all,
                                         today: today, calendar: calendar).isEmpty)

        var draft = MonthlyZineDraft()
        precondition(!draft.showsWriting && !draft.showsPhoto && !draft.showsMusic && !draft.showsWatch,
                     "Private content requires an explicit opt-in")
        draft.title = "My February"
        draft.introduction = "Keep this copy, not the source note"
        draft.selectedDayKeys = ["2024-02-29", "2024-02-29", "2024-03-01", "2024-02-01"]
        draft.photoDayKey = "2024-02-10"
        let clean = MonthlyZine.sanitized(draft, availableDayKeys: selected.map(\.dayKey), photoDayKeys: [])
        precondition(clean.selectedDayKeys == ["2024-02-29", "2024-02-01"] && clean.photoDayKey == nil)
        precondition(MonthlyZine.excerpt(" 一段很长的文字 ", limit: 5) == "一段很长…")
        precondition(MonthlyZine.excerpt(" 👨‍👩‍👧‍👦🙂 ", limit: 2) == "👨‍👩‍👧‍👦🙂", "Excerpt keeps graphemes intact")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zine-check-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("drafts.json")
        let store = MonthlyZineDraftStore(fileURL: file)
        try store.save(clean, for: "2024-02", today: today, calendar: calendar)
        let reopened = MonthlyZineDraftStore(fileURL: file)
        precondition(reopened.loadError == nil)
        precondition(reopened.draft(for: "2024-02") == clean, "Draft survives reopening the store")
        var imported = MonthlyZineDraft()
        imported.title = "Imported"
        let count = try reopened.mergeImportedDrafts(["2024-02": imported, "2024-01": imported], today: today, calendar: calendar)
        precondition(count == 1 && reopened.draft(for: "2024-02") == clean, "Import never replaces a local month")
        precondition(reopened.draft(for: "2024-01") == imported)
        let encoded = try JSONEncoder().encode(reopened.exportDrafts())
        let decoded = try JSONDecoder().decode([String: MonthlyZineDraft].self, from: encoded)
        precondition(decoded["2024-02"] == clean)

        func mustReject(_ operation: () throws -> Void) {
            do { try operation(); preconditionFailure("Invalid draft accepted") }
            catch {}
        }
        mustReject { try store.save(clean, for: "2024-04", today: today, calendar: calendar) }
        mustReject { try store.save(clean, for: "2024-03", today: today, calendar: calendar) }
        var bad = clean
        bad.selectedDayKeys = ["2024-02-30"]
        mustReject { try MonthlyZineDraftStore.validate(["2024-02": bad], today: today, calendar: calendar) }
        bad = clean
        bad.selectedDayKeys = ["2024-02-29", "2024-02-29"]
        mustReject { try MonthlyZineDraftStore.validate(["2024-02": bad], today: today, calendar: calendar) }
        let original = try Data(contentsOf: file)
        try Data("corrupt".utf8).write(to: file)
        let unreadable = MonthlyZineDraftStore(fileURL: file)
        precondition(unreadable.loadError != nil)
        mustReject { try unreadable.save(clean, for: "2024-02", today: today, calendar: calendar) }
        let retainedFile = try Data(contentsOf: file)
        precondition(retainedFile == Data("corrupt".utf8), "Unreadable user file is not overwritten")
        try original.write(to: file)
        let ahead = MonthlyZine.monthKey(Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        let aheadFile = directory.appendingPathComponent("clock-correction.json")
        try JSONEncoder().encode([ahead: MonthlyZineDraft()]).write(to: aheadFile)
        let afterClockCorrection = MonthlyZineDraftStore(fileURL: aheadFile)
        precondition(afterClockCorrection.loadError == nil && afterClockCorrection.draft(for: ahead) != nil,
                     "Clock corrections preserve valid saved drafts even when their month temporarily lies ahead")
        mustReject { try afterClockCorrection.save(MonthlyZineDraft(), for: ahead) }
        let isolated = MonthlyZineDraftStore(fileURL: nil)
        precondition(isolated.draft(for: "2024-02") == nil)
        precondition(MonthlyZineDraftStore.applicationStore(isDemo: true) === MonthlyZineDraftStore.applicationStore(isDemo: true),
                     "Demo drafts survive closing a sheet but stay separate from the production file")
        print("Monthly zine checks passed")
    }
}
