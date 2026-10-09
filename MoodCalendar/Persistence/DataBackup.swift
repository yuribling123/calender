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
    static func makeArchive(entries: [MoodEntry], monthlyNotes: [MonthlyNote]) throws -> Data {
        let dateFormatter = ISO8601DateFormatter()
        let manifest = Manifest(
            appIdentifier: "com.qingqing.MoodCalendar",
            appName: "今日份",
            formatVersion: 1,
            exportedAt: dateFormatter.string(from: .now)
        )
        let payload = BackupPayload(
            entries: entries.sorted { $0.dayKey < $1.dayKey }.map {
                BackupEntry(
                    dayKey: $0.dayKey,
                    choiceID: $0.moodValue,
                    note: $0.note,
                    updatedAt: dateFormatter.string(from: $0.updatedAt)
                )
            },
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
        return try ZipArchive.make(files: [
            (name: "manifest.json", contents: manifestData),
            (name: "data.json", contents: payloadData)
        ])
    }
}

private struct Manifest: Encodable {
    let appIdentifier: String
    let appName: String
    let formatVersion: Int
    let exportedAt: String
}

private struct BackupPayload: Encodable {
    let entries: [BackupEntry]
    let monthlyNotes: [BackupMonthlyNote]
}

private struct BackupEntry: Encodable {
    let dayKey: String
    let choiceID: Int
    let note: String
    let updatedAt: String
}

private struct BackupMonthlyNote: Encodable {
    let monthKey: String
    let text: String
    let updatedAt: String
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

        for file in files {
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

    private enum ArchiveError: Error {
        case fileTooLarge
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
