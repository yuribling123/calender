import Foundation

@main
struct FutureLetterChecks {
    @MainActor
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--reopen" {
            let store = FutureLetterStore(fileURL: URL(fileURLWithPath: CommandLine.arguments[2]), calendar: calendar)
            precondition(store.loadError == nil && store.letters.count == 2)
            precondition(store.letters.first { $0.title == "Leap day" }?.body == "A real memory")
            precondition(store.letters.first { $0.title == "Leap day" }?.isOpened == true)
            precondition(store.letters.first { $0.title == "Year end" }?.deliveryDay.storageValue == "2025-01-01")
            print("Future letters reopened in an independent process")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("letter-checks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("letters.json")
        var clock = date(2024, 2, 28, 23)
        let store = FutureLetterStore(fileURL: file, calendar: calendar, now: { clock })
        let leap = try store.save(title: " Leap day ", body: " A real memory ", deliveryDate: date(2024, 2, 29, 1))
        precondition(leap.deliveryDay == DayKey(date(2024, 2, 29), calendar: calendar))
        precondition(leap.body == "A real memory" && leap.title == "Leap day")
        precondition(!leap.hasArrived(on: DayKey(clock, calendar: calendar)))
        expect(.dateMustBeFuture) { try store.save(title: "", body: "body", deliveryDate: clock) }
        expect(.dateMustBeFuture) { try store.save(title: "", body: "body", deliveryDate: date(2024, 2, 27)) }
        expect(.emptyBody) { try store.save(title: "", body: " \n ", deliveryDate: date(2024, 3, 1)) }
        expect(.textTooLong) { try store.save(title: String(repeating: "a", count: 41), body: "body", deliveryDate: date(2024, 3, 1)) }
        expect(.textTooLong) { try store.save(title: "", body: String(repeating: "a", count: 3001), deliveryDate: date(2024, 3, 1)) }
        expect(.earlyOpeningNeedsConfirmation) { try store.open(leap.id) }
        precondition(!store.letters[0].isOpened)
        clock = date(2024, 2, 29, 0)
        try store.open(leap.id)
        precondition(store.letters[0].isOpened)
        let firstOpenedAt = store.letters[0].openedAt
        clock = date(2024, 3, 1)
        try store.open(leap.id)
        precondition(store.letters[0].openedAt == firstOpenedAt)
        expect(.alreadyOpened) { try store.save(id: leap.id, title: "changed", body: "changed", deliveryDate: date(2024, 4, 1)) }
        let early = try store.save(title: "Early", body: "early", deliveryDate: date(2024, 4, 1))
        try store.open(early.id, allowEarly: true)
        precondition(store.letters.first { $0.id == early.id }!.isOpened)
        try store.delete(early.id)
        expect(.letterMissing) { try store.delete(early.id) }
        let editable = try store.save(title: "Draft", body: "first wording", deliveryDate: date(2024, 4, 1))
        let edited = try store.save(id: editable.id, title: "Revised", body: "second wording", deliveryDate: date(2024, 5, 1))
        precondition(edited.id == editable.id && edited.createdAt == editable.createdAt && edited.writtenDay == editable.writtenDay)
        precondition(edited.body == "second wording" && store.letters.filter { $0.id == editable.id }.count == 1)
        try store.delete(edited.id)
        let year = try store.save(title: "Year end", body: "next year", deliveryDate: date(2025, 1, 1))
        let archive = try store.exportData()
        let destination = FutureLetterStore(isInMemory: true, calendar: calendar, now: { clock })
        try destination.importData(archive)
        precondition(destination.letters == store.letters)
        var modified = leap
        modified.body = "should not overwrite"
        try destination.importLetters([modified])
        precondition(destination.letters.first { $0.id == leap.id }?.body == "A real memory")
        expect(.damagedArchive) { try destination.importLetters([year, year]) }
        let reopened = FutureLetterStore(fileURL: file, calendar: calendar, now: { clock })
        precondition(reopened.loadError == nil && reopened.letters == store.letters)
        let command = Process()
        command.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        command.arguments = ["--reopen", file.path]
        try command.run()
        command.waitUntilExit()
        precondition(command.terminationStatus == 0)

        let corrupt = directory.appendingPathComponent("corrupt.json")
        try Data("broken archive".utf8).write(to: corrupt)
        let corruptStore = FutureLetterStore(fileURL: corrupt, calendar: calendar, now: { clock })
        precondition(corruptStore.loadError != nil)
        do {
            try corruptStore.save(title: "", body: "must not overwrite", deliveryDate: date(2024, 4, 1))
            preconditionFailure("Unreadable files must be protected")
        } catch {}
        let protectedContents = try String(contentsOf: corrupt, encoding: .utf8)
        precondition(protectedContents == "broken archive")
        let blockingFile = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blockingFile)
        let blockedStore = FutureLetterStore(fileURL: blockingFile.appendingPathComponent("letters.json"), calendar: calendar, now: { clock })
        do {
            try blockedStore.save(title: "", body: "cannot commit", deliveryDate: date(2024, 4, 1))
            preconditionFailure("Expected disk error")
        } catch {}
        precondition(blockedStore.letters.isEmpty)
        let demoURL = directory.appendingPathComponent("demo-must-not-exist.json")
        let demo = FutureLetterStore(isInMemory: true, fileURL: demoURL, calendar: calendar, now: { clock })
        try demo.save(title: "Demo", body: "in memory only", deliveryDate: date(2024, 4, 1))
        precondition(!FileManager.default.fileExists(atPath: demoURL.path))
        print("Future letter date, opening, backup merge, atomic storage and Demo checks passed")
    }

    @MainActor
    static func expect<T>(_ expected: FutureLetterError, _ action: () throws -> T) {
        do {
            _ = try action()
            preconditionFailure("Expected \(expected)")
        } catch {
            precondition(error as? FutureLetterError == expected, "Unexpected error: \(error)")
        }
    }
}
