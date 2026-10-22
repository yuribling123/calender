import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum DataBackupExporter {
    static func makeArchive(entries: [MoodEntry], monthlyNotes: [MonthlyNote], monthlyNoteSkins: [String: String] = [:]) throws -> Data {
        // CloudKit can deliver duplicate records before the normal reconciliation
        // runs. Export one whole, latest record per day/month, including its photo.
        let entries = Dictionary(grouping: entries, by: \.dayKey).values.compactMap {
            $0.max {
                $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt < $1.updatedAt
            }
        }
        let monthlyNotes = Dictionary(grouping: monthlyNotes, by: \.monthKey).values.compactMap {
            $0.max {
                $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt < $1.updatedAt
            }
        }
        let dateFormatter = ISO8601DateFormatter()
        let manifest = Manifest(
            appIdentifier: "com.qingqing.MoodCalendar",
            appName: localized("今日份"),
            formatVersion: 2,
            exportedAt: dateFormatter.string(from: .now)
        )
        let payload = BackupPayload(
            entries: entries.sorted { $0.dayKey < $1.dayKey }.map {
                BackupEntry(
                    dayKey: $0.dayKey,
                    choiceID: $0.moodValue,
                    note: $0.note,
                    cardPaperID: $0.cardPaperID,
                    songTitle: $0.songTitle,
                    songArtist: $0.songArtist,
                    watchTitle: $0.watchTitle,
                    watchKind: $0.watchKind,
                    watchNote: $0.watchNote,
                    photoPath: $0.photoData == nil ? nil : "photos/\($0.dayKey).jpg",
                    updatedAt: dateFormatter.string(from: $0.updatedAt)
                )
            },
            monthlyNoteSkins: monthlyNoteSkins,
            monthlyNotes: monthlyNotes.sorted { $0.monthKey < $1.monthKey }.map {
                BackupMonthlyNote(
                    monthKey: $0.monthKey,
                    text: $0.text,
                    updatedAt: dateFormatter.string(from: $0.updatedAt)
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        let payloadData = try encoder.encode(payload)
        var files: [(name: String, contents: Data)] = [
            (name: "manifest.json", contents: manifestData),
            (name: "data.json", contents: payloadData),
            (name: localized("记录.txt"), contents: Data(readableText(entries: entries, monthlyNotes: monthlyNotes).utf8))
        ]
        files += entries.compactMap { entry in
            guard let data = entry.photoData else { return nil }
            return (name: "photos/\(entry.dayKey).jpg", contents: data)
        }
        return try ZipArchive.make(files: files)
    }
    static func readableText(entries: [MoodEntry], monthlyNotes: [MonthlyNote]) -> String {
        var lines = [localized("今日份 · 记录导出"), "", localized("每日记录"), ""]
        for entry in entries.sorted(by: { $0.dayKey < $1.dayKey }) {
            lines.append("\(entry.dayKey) · \(entry.choice?.title ?? localized("Unknown sticker (%@)", String(entry.moodValue)))")
            if !entry.note.isEmpty { lines.append(entry.note) }
            if let title = entry.watchTitle, !title.isEmpty {
                lines.append("\(localized("看了什么")) · \(title)")
                if let note = entry.watchNote, !note.isEmpty { lines.append(note) }
            }
            if let title = entry.songTitle, !title.isEmpty {
                let artist = entry.songArtist.flatMap { $0.isEmpty ? nil : $0 }
                lines.append("♫ \(title)" + (artist.map { " · \($0)" } ?? ""))
            }
            lines.append("")
        }
        if entries.isEmpty { lines.append(localized("暂无每日记录\n")) }
        lines.append(contentsOf: [localized("月便签"), ""])
        for note in monthlyNotes.sorted(by: { $0.monthKey < $1.monthKey }) {
            lines.append(note.monthKey)
            lines.append(note.text)
            lines.append("")
        }
        if monthlyNotes.isEmpty { lines.append(localized("暂无月便签")) }
        return lines.joined(separator: "\n") + "\n"
    }
}

private struct Manifest: Codable {
    let appIdentifier: String
    let appName: String
    let formatVersion: Int
    let exportedAt: String
}

private struct BackupPayload: Codable {
    let entries: [BackupEntry]
    let monthlyNoteSkins: [String: String]?
    let monthlyNotes: [BackupMonthlyNote]
}

private struct BackupEntry: Codable {
    let dayKey: String
    let choiceID: Int
    let note: String
    let cardPaperID: String?
    let songTitle: String?
    let songArtist: String?
    let watchTitle: String?
    let watchKind: String?
    let watchNote: String?
    let photoPath: String?
    let updatedAt: String
}

private struct BackupMonthlyNote: Codable {
    let monthKey: String
    let text: String
    let updatedAt: String
}

struct DataBackupImportPlan: Sendable {
    struct Entry: Sendable {
        let dayKey: String
        let choiceID: Int
        let note: String
        let cardPaperID: String?
        let songTitle: String?
        let songArtist: String?
        let watchTitle: String?
        let watchKind: String?
        let watchNote: String?
        let updatedAt: Date
        let photoData: Data?
    }

    struct MonthlyNote: Sendable {
        let monthKey: String
        let text: String
        let updatedAt: Date
    }

    let monthlyNoteSkins: [String: String]
    let entriesToImport: [Entry]
    let monthlyNotesToImport: [MonthlyNote]
    let existingEntryCount: Int
    let existingMonthlyNoteCount: Int

    var photoCount: Int { entriesToImport.filter { $0.photoData != nil }.count }
}

enum DataBackupImporter {
    private static let appIdentifier = "com.qingqing.MoodCalendar"
    private static let maximumArchiveSize = 100 * 1024 * 1024
    private static let maximumExpandedSize = 100 * 1024 * 1024
    private static let maximumFileCount = 65_535

    static func makePlan(
        from archiveData: Data,
        existingDayKeys: Set<String>,
        existingMonthKeys: Set<String>
    ) throws -> DataBackupImportPlan {
        guard archiveData.count <= maximumArchiveSize else { throw ImportError.archiveTooLarge }
        let files: [String: Data]
        do {
            files = try ZipArchive.readFiles(
                from: archiveData,
                maximumExpandedSize: maximumExpandedSize,
                maximumFileCount: maximumFileCount
            )
        } catch {
            throw ImportError.invalidBackup
        }
        guard let manifestData = files["manifest.json"],
              let payloadData = files["data.json"] else {
            throw ImportError.invalidBackup
        }

        let decoder = JSONDecoder()
        let manifest: Manifest
        do {
            manifest = try decoder.decode(Manifest.self, from: manifestData)
        } catch {
            throw ImportError.invalidBackup
        }
        guard manifest.appIdentifier == appIdentifier else { throw ImportError.wrongApp }
        guard (1...2).contains(manifest.formatVersion) else { throw ImportError.unsupportedVersion }
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: payloadData)
        } catch {
            throw ImportError.invalidBackup
        }
        guard payload.entries.count <= maximumFileCount,
              payload.monthlyNotes.count <= maximumFileCount else { throw ImportError.invalidBackup }

        let importedSkins = payload.monthlyNoteSkins ?? [:]
        guard importedSkins.count <= maximumFileCount,
              importedSkins.allSatisfy({ isValidMonthKey($0.key) && $0.value.utf8.count <= 100 }) else {
            throw ImportError.invalidBackup
        }
        let skins = importedSkins.mapValues { MonthlyNoteSkin(rawValue: $0)?.rawValue ?? MonthlyNoteSkin.plain.rawValue }

        let entries = try payload.entries.map { item -> DataBackupImportPlan.Entry in
            guard isValidDayKey(item.dayKey),
                  (1...30).contains(item.choiceID),
                  item.note.utf8.count <= 1_000_000,
                  (item.cardPaperID?.utf8.count ?? 0) <= 100,
                  (item.songTitle?.utf8.count ?? 0) <= 1_000_000,
                  (item.songArtist?.utf8.count ?? 0) <= 1_000_000,
                  (item.watchTitle?.utf8.count ?? 0) <= 1_000_000,
                  (item.watchNote?.utf8.count ?? 0) <= 1_000_000,
                  ["movie", "series"].contains(item.watchKind ?? "movie"),
                  let updatedAt = parseDate(item.updatedAt) else {
                throw ImportError.invalidBackup
            }

            let photoData: Data?
            if let photoPath = item.photoPath {
                guard photoPath == "photos/\(item.dayKey).jpg",
                      let imageData = files[photoPath],
                      imageData.count <= 25 * 1024 * 1024,
                      imageData.starts(with: [0xff, 0xd8]),
                      imageData.suffix(2).elementsEqual([0xff, 0xd9]) else {
                    throw ImportError.invalidPhoto
                }
                photoData = imageData
            } else {
                photoData = nil
            }

            let songTitle = nonEmpty(item.songTitle)
            return DataBackupImportPlan.Entry(
                dayKey: item.dayKey,
                choiceID: item.choiceID,
                note: item.note,
                cardPaperID: item.cardPaperID.flatMap { CardPaper(rawValue: $0)?.rawValue },
                songTitle: songTitle,
                songArtist: songTitle == nil ? nil : nonEmpty(item.songArtist),
                watchTitle: nonEmpty(item.watchTitle),
                watchKind: nonEmpty(item.watchTitle) == nil ? nil : item.watchKind,
                watchNote: nonEmpty(item.watchTitle) == nil ? nil : nonEmpty(item.watchNote),
                updatedAt: updatedAt,
                photoData: photoData
            )
        }

        let notes = try payload.monthlyNotes.map { item -> DataBackupImportPlan.MonthlyNote in
            guard isValidMonthKey(item.monthKey),
                  !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.text.count <= 100,
                  let updatedAt = parseDate(item.updatedAt) else {
                throw ImportError.invalidBackup
            }
            return DataBackupImportPlan.MonthlyNote(
                monthKey: item.monthKey,
                text: item.text,
                updatedAt: updatedAt
            )
        }

        let referencedPhotos = Set(payload.entries.compactMap(\.photoPath))
        guard files.keys.allSatisfy({
            $0 == "manifest.json" || $0 == "data.json" || $0.hasSuffix(".txt") && !$0.contains("/") || referencedPhotos.contains($0)
        }), referencedPhotos.allSatisfy({ files[$0] != nil }) else {
            throw ImportError.invalidBackup
        }

        // Validate every member above, then recover older app-generated backups
        // using the latest whole record. Equal timestamps use the last occurrence.
        let latestEntries = entries.reduce(into: [String: DataBackupImportPlan.Entry]()) { result, entry in
            if let saved = result[entry.dayKey], saved.updatedAt > entry.updatedAt { return }
            result[entry.dayKey] = entry
        }
        let latestNotes = notes.reduce(into: [String: DataBackupImportPlan.MonthlyNote]()) { result, note in
            if let saved = result[note.monthKey], saved.updatedAt > note.updatedAt { return }
            result[note.monthKey] = note
        }
        let newEntries = latestEntries.values.filter { !existingDayKeys.contains($0.dayKey) }.sorted { $0.dayKey < $1.dayKey }
        let newNotes = latestNotes.values.filter { !existingMonthKeys.contains($0.monthKey) }.sorted { $0.monthKey < $1.monthKey }
        return DataBackupImportPlan(
            monthlyNoteSkins: skins.filter { !existingMonthKeys.contains($0.key) },
            entriesToImport: newEntries,
            monthlyNotesToImport: newNotes,
            existingEntryCount: latestEntries.count - newEntries.count,
            existingMonthlyNoteCount: latestNotes.count - newNotes.count
        )
    }

    @MainActor
    static func restore(_ plan: DataBackupImportPlan, into context: ModelContext) throws -> (entries: Int, monthlyNotes: Int) {
        let existingDayKeys = Set(try context.fetch(FetchDescriptor<MoodEntry>()).map(\.dayKey))
        let existingMonthKeys = Set(try context.fetch(FetchDescriptor<MonthlyNote>()).map(\.monthKey))
        let entries = plan.entriesToImport.filter { !existingDayKeys.contains($0.dayKey) }
        let notes = plan.monthlyNotesToImport.filter { !existingMonthKeys.contains($0.monthKey) }
        let preparedEntries = try entries.map { item -> (DataBackupImportPlan.Entry, DailyChoice) in
            guard let choice = DailyChoice(rawValue: item.choiceID) else { throw ImportError.invalidBackup }
            return (item, choice)
        }

        for (item, choice) in preparedEntries {
            let entry = MoodEntry(dayKey: item.dayKey, choice: choice, note: item.note)
            entry.updatedAt = item.updatedAt
            entry.photoData = item.photoData
            entry.cardPaperID = item.cardPaperID
            entry.songTitle = item.songTitle
            entry.songArtist = item.songArtist
            entry.watchTitle = item.watchTitle
            entry.watchKind = item.watchKind
            entry.watchNote = item.watchNote
            context.insert(entry)
        }
        for item in notes {
            let note = MonthlyNote(monthKey: item.monthKey, text: item.text)
            note.updatedAt = item.updatedAt
            context.insert(note)
        }

        do {
            try MonthlyNoteSkinStore(context: context).restore(plan.monthlyNoteSkins, excluding: existingMonthKeys)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return (entries.count, notes.count)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func isValidDayKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 10,
              bytes[4] == 45, bytes[7] == 45,
              bytes[0..<4].allSatisfy(isASCIIDigit),
              bytes[5..<7].allSatisfy(isASCIIDigit),
              bytes[8..<10].allSatisfy(isASCIIDigit),
              let year = Int(value.prefix(4)),
              let month = Int(value.dropFirst(5).prefix(2)),
              let day = Int(value.suffix(2)), (1...9999).contains(year) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return false }
        let result = calendar.dateComponents([.year, .month, .day], from: date)
        return result.year == year && result.month == month && result.day == day
    }

    private static func isValidMonthKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 7, bytes[4] == 45,
              bytes[0..<4].allSatisfy(isASCIIDigit),
              bytes[5..<7].allSatisfy(isASCIIDigit),
              let year = Int(value.prefix(4)),
              let month = Int(value.suffix(2)), (1...9999).contains(year), (1...12).contains(month) else { return false }
        return true
    }

    private static func isASCIIDigit(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    private enum ImportError: LocalizedError {
        case archiveTooLarge
        case invalidBackup
        case invalidPhoto
        case wrongApp
        case unsupportedVersion

        var errorDescription: String? {
            switch self {
            case .archiveTooLarge: "备份文件太大，无法导入。"
            case .invalidBackup: "备份文件内容不完整或格式有误。"
            case .invalidPhoto: "备份中的照片缺失或无法读取。"
            case .wrongApp: "这不是「今日份」导出的备份文件。"
            case .unsupportedVersion: "备份格式版本暂不支持。"
            }
        }
    }
}

private enum ZipArchive {
    private struct DirectoryEntry {
        let name: Data
        let checksum: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    static func make(files: [(name: String, contents: Data)]) throws -> Data {
        var archive = Data()
        var directoryEntries: [DirectoryEntry] = []
        var filenames = Set<String>()

        for file in files {
            guard filenames.insert(file.name).inserted else { throw ArchiveError.duplicateFilename }
            let name = Data(file.name.utf8)
            guard let size = UInt32(exactly: file.contents.count),
                  let offset = UInt32(exactly: archive.count) else {
                throw ArchiveError.fileTooLarge
            }
            let checksum = CRC32.checksum(file.contents)

            archive.appendLE(UInt32(0x04034b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800)) // UTF-8 filenames
            archive.appendLE(UInt16(0)) // Stored without compression
            archive.appendLE(UInt16(0)) // DOS time
            archive.appendLE(UInt16(33)) // January 1, 1980
            archive.appendLE(checksum)
            archive.appendLE(size)
            archive.appendLE(size)
            archive.appendLE(UInt16(name.count))
            archive.appendLE(UInt16(0))
            archive.append(name)
            archive.append(file.contents)

            directoryEntries.append(DirectoryEntry(
                name: name,
                checksum: checksum,
                size: size,
                localHeaderOffset: offset
            ))
        }

        guard let directoryOffset = UInt32(exactly: archive.count) else {
            throw ArchiveError.fileTooLarge
        }
        let directoryStart = archive.count

        for entry in directoryEntries {
            archive.appendLE(UInt32(0x02014b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(33))
            archive.appendLE(entry.checksum)
            archive.appendLE(entry.size)
            archive.appendLE(entry.size)
            archive.appendLE(UInt16(entry.name.count))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt32(0))
            archive.appendLE(entry.localHeaderOffset)
            archive.append(entry.name)
        }

        guard let directorySize = UInt32(exactly: archive.count - directoryStart),
              let fileCount = UInt16(exactly: directoryEntries.count) else {
            throw ArchiveError.fileTooLarge
        }
        archive.appendLE(UInt32(0x06054b50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(fileCount)
        archive.appendLE(fileCount)
        archive.appendLE(directorySize)
        archive.appendLE(directoryOffset)
        archive.appendLE(UInt16(0))
        return archive
    }

    static func readFiles(
        from archive: Data,
        maximumExpandedSize: Int,
        maximumFileCount: Int
    ) throws -> [String: Data] {
        guard archive.count >= 22 else { throw ImportError.invalidArchive }
        let earliestEndRecord = max(0, archive.count - 65_557)
        var endRecordOffset: Int?
        for offset in stride(from: archive.count - 22, through: earliestEndRecord, by: -1) {
            guard archive.uint32(at: offset) == 0x06054b50,
                  let commentLength = archive.uint16(at: offset + 20),
                  offset + 22 + Int(commentLength) == archive.count else { continue }
            endRecordOffset = offset
            break
        }
        guard let endRecordOffset,
              archive.uint16(at: endRecordOffset + 4) == 0,
              archive.uint16(at: endRecordOffset + 6) == 0,
              let entriesOnDisk = archive.uint16(at: endRecordOffset + 8),
              let entryCount = archive.uint16(at: endRecordOffset + 10),
              entriesOnDisk == entryCount,
              Int(entryCount) <= maximumFileCount,
              let directorySizeValue = archive.uint32(at: endRecordOffset + 12),
              let directoryOffsetValue = archive.uint32(at: endRecordOffset + 16),
              directorySizeValue != UInt32.max,
              directoryOffsetValue != UInt32.max else {
            throw ImportError.invalidArchive
        }

        let directoryOffset = Int(directoryOffsetValue)
        let directoryEnd = directoryOffset + Int(directorySizeValue)
        guard directoryOffset >= 0, directoryEnd <= endRecordOffset else { throw ImportError.invalidArchive }

        var cursor = directoryOffset
        var expandedSize = 0
        var files: [String: Data] = [:]
        for _ in 0..<entryCount {
            guard archive.uint32(at: cursor) == 0x02014b50,
                  let flags = archive.uint16(at: cursor + 8),
                  let compressionMethod = archive.uint16(at: cursor + 10),
                  let checksum = archive.uint32(at: cursor + 16),
                  let compressedSizeValue = archive.uint32(at: cursor + 20),
                  let expandedSizeValue = archive.uint32(at: cursor + 24),
                  let nameLength = archive.uint16(at: cursor + 28),
                  let extraLength = archive.uint16(at: cursor + 30),
                  let commentLength = archive.uint16(at: cursor + 32),
                  let startDisk = archive.uint16(at: cursor + 34),
                  let localOffsetValue = archive.uint32(at: cursor + 42),
                  startDisk == 0,
                  flags & 0x0001 == 0,
                  flags & 0x0040 == 0,
                  flags & ~UInt16(0x0808) == 0,
                  compressionMethod == 0,
                  compressedSizeValue == expandedSizeValue,
                  compressedSizeValue != UInt32.max,
                  expandedSizeValue != UInt32.max,
                  localOffsetValue != UInt32.max else {
                throw ImportError.invalidArchive
            }

            let recordLength = 46 + Int(nameLength) + Int(extraLength) + Int(commentLength)
            guard cursor + recordLength <= directoryEnd,
                  let filenameData = archive.data(in: (cursor + 46)..<(cursor + 46 + Int(nameLength))),
                  let filename = String(data: filenameData, encoding: .utf8),
                  !filename.isEmpty else {
                throw ImportError.invalidArchive
            }
            cursor += recordLength

            if filename.hasSuffix("/") {
                guard expandedSizeValue == 0 else { throw ImportError.invalidArchive }
                continue
            }
            let fileSize = Int(expandedSizeValue)
            guard fileSize <= maximumExpandedSize - expandedSize else { throw ImportError.invalidArchive }
            expandedSize += fileSize

            let localOffset = Int(localOffsetValue)
            guard archive.uint32(at: localOffset) == 0x04034b50,
                  let localFlags = archive.uint16(at: localOffset + 6),
                  let localMethod = archive.uint16(at: localOffset + 8),
                  let localNameLength = archive.uint16(at: localOffset + 26),
                  let localExtraLength = archive.uint16(at: localOffset + 28),
                  localFlags == flags,
                  localMethod == compressionMethod,
                  Int(localNameLength) == Int(nameLength) else {
                throw ImportError.invalidArchive
            }
            let localNameStart = localOffset + 30
            let dataOffset = localNameStart + Int(localNameLength) + Int(localExtraLength)
            guard let localNameData = archive.data(in: localNameStart..<(localNameStart + Int(localNameLength))),
                  localNameData == filenameData,
                  let contents = archive.data(in: dataOffset..<(dataOffset + fileSize)),
                  dataOffset + fileSize <= directoryOffset,
                  CRC32.checksum(contents) == checksum else {
                throw ImportError.invalidArchive
            }
            if let existing = files[filename] {
                // Some earlier exports repeated the same photo. Accept only
                // byte-identical, individually CRC-checked copies.
                guard existing == contents else { throw ImportError.invalidArchive }
            } else {
                files[filename] = contents
            }
        }
        guard cursor == directoryEnd else { throw ImportError.invalidArchive }
        return files
    }

    private enum ArchiveError: Error {
        case fileTooLarge
        case duplicateFilename
    }

    private enum ImportError: Error {
        case invalidArchive
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
            }
        }
        return crc ^ UInt32.max
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= count - 2 else { return nil }
        let index = startIndex + offset
        return UInt16(self[index]) | (UInt16(self[index + 1]) << 8)
    }

    func uint32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= count - 4 else { return nil }
        let index = startIndex + offset
        return UInt32(self[index])
            | (UInt32(self[index + 1]) << 8)
            | (UInt32(self[index + 2]) << 16)
            | (UInt32(self[index + 3]) << 24)
    }

    func data(in range: Range<Int>) -> Data? {
        guard range.lowerBound >= 0, range.upperBound >= range.lowerBound, range.upperBound <= count else { return nil }
        let lower = startIndex + range.lowerBound
        let upper = startIndex + range.upperBound
        return subdata(in: lower..<upper)
    }

    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
