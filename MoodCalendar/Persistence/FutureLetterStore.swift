import Foundation
import Combine

/// Local-only, transactional letter storage. An unreadable archive is never overwritten.
@MainActor
final class FutureLetterStore: ObservableObject {
    @Published private(set) var letters: [FutureLetter] = []
    @Published private(set) var loadError: Error?
    private let fileURL: URL?
    private let calendar: Calendar
    private let now: () -> Date

    private struct Archive: Codable {
        var version = 1
        var letters: [FutureLetter]
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("MoodCalendar", isDirectory: true)
            .appendingPathComponent("future-letters-v1.json")
    }

    init(isInMemory: Bool = false, fileURL: URL? = nil,
         calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.fileURL = isInMemory ? nil : (fileURL ?? Self.defaultFileURL)
        self.calendar = calendar
        self.now = now
        reload()
    }

    func reload() {
        guard let fileURL else { return }
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                letters = []
                loadError = nil
                return
            }
            let archive = try Self.decode(Data(contentsOf: fileURL))
            letters = Self.sorted(archive)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    @discardableResult
    func save(id: UUID? = nil, title: String, body: String, deliveryDate: Date) throws -> FutureLetter {
        let date = now()
        let today = DayKey(date, calendar: calendar)
        let deliveryDay = DayKey(deliveryDate, calendar: calendar)
        guard FutureLetter.date(for: deliveryDay, calendar: calendar) != nil else { throw FutureLetterError.invalidDate }
        guard deliveryDay > today else { throw FutureLetterError.dateMustBeFuture }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { throw FutureLetterError.emptyBody }
        guard cleanTitle.count <= 40, cleanBody.count <= 3000 else { throw FutureLetterError.textTooLong }
        var updated = letters
        let letter: FutureLetter
        if let id {
            guard let index = updated.firstIndex(where: { $0.id == id }) else { throw FutureLetterError.letterMissing }
            guard !updated[index].isOpened else { throw FutureLetterError.alreadyOpened }
            var edited = updated[index]
            edited.title = cleanTitle
            edited.body = cleanBody
            edited.deliveryDay = deliveryDay
            edited.updatedAt = date
            updated[index] = edited
            letter = edited
        } else {
            letter = FutureLetter(id: UUID(), title: cleanTitle, body: cleanBody,
                                  writtenDay: today, deliveryDay: deliveryDay,
                                  createdAt: date, updatedAt: date, openedAt: nil)
            updated.append(letter)
        }
        try commit(updated)
        return letter
    }

    func open(_ id: UUID, allowEarly: Bool = false) throws {
        var updated = letters
        guard let index = updated.firstIndex(where: { $0.id == id }) else { throw FutureLetterError.letterMissing }
        guard !updated[index].isOpened else { return }
        let date = now()
        guard updated[index].hasArrived(on: DayKey(date, calendar: calendar)) || allowEarly else {
            throw FutureLetterError.earlyOpeningNeedsConfirmation
        }
        updated[index].openedAt = date
        updated[index].updatedAt = date
        try commit(updated)
    }

    func delete(_ id: UUID) throws {
        guard letters.contains(where: { $0.id == id }) else { throw FutureLetterError.letterMissing }
        try commit(letters.filter { $0.id != id })
    }

    /// Explicit export/import hooks keep letters portable without enabling network storage.
    func exportData() throws -> Data {
        if let loadError { throw loadError }
        return try JSONEncoder().encode(Archive(letters: letters))
    }

    func importData(_ data: Data) throws {
        try importLetters(Self.decode(data))
    }

    func importLetters(_ imported: [FutureLetter]) throws {
        try Self.validate(imported)
        let existing = Set(letters.map(\.id))
        try commit(letters + imported.filter { !existing.contains($0.id) })
    }

    nonisolated static func validate(_ letters: [FutureLetter]) throws {
        guard Set(letters.map(\.id)).count == letters.count,
              letters.allSatisfy({ letter in
                  !letter.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && letter.body.count <= 3000 && letter.title.count <= 40
                  && FutureLetter.date(for: letter.deliveryDay) != nil
                  && FutureLetter.date(for: letter.writtenDay) != nil
                  && letter.deliveryDay > letter.writtenDay
              }) else { throw FutureLetterError.damagedArchive }
    }

    private static func decode(_ data: Data) throws -> [FutureLetter] {
        let archive: Archive
        do { archive = try JSONDecoder().decode(Archive.self, from: data) }
        catch { throw FutureLetterError.damagedArchive }
        guard archive.version == 1 else { throw FutureLetterError.unsupportedArchive }
        try validate(archive.letters)
        return archive.letters
    }

    private static func sorted(_ letters: [FutureLetter]) -> [FutureLetter] {
        letters.sorted {
            if $0.deliveryDay != $1.deliveryDay { return $0.deliveryDay < $1.deliveryDay }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func commit(_ updated: [FutureLetter]) throws {
        if let loadError { throw loadError }
        if let fileURL {
            let data = try JSONEncoder().encode(Archive(letters: updated))
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
        }
        letters = Self.sorted(updated)
    }
}
