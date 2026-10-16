import Foundation
import SwiftData

@MainActor
struct EntryStore {
    let context: ModelContext

    func save(day: DayKey, choice: DailyChoice, note: String, isMember: Bool = false, photoData: Data? = nil, updatesPhoto: Bool = false, cardPaperID: String? = nil, updatesCardPaper: Bool = false, songTitle: String? = nil, songArtist: String? = nil, updatesSong: Bool = false) throws {
        let allowsPastDates = UserDefaults.standard.object(forKey: "allowPastDateEditing") as? Bool ?? true
        guard day.isEditable(allowPastDates: allowsPastDates) else {
            throw EntryStoreError.dateIsReadOnly
        }
        var canUseChoice = choice.group == .mood || choice.group == .activity || choice.group == .company || isMember
        #if DEBUG
        canUseChoice = canUseChoice || DemoData.isEnabled
        #endif
        guard canUseChoice else {
            throw EntryStoreError.membershipRequired
        }
        let key = day.storageValue
        let descriptor = FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.dayKey == key })
        let matchingEntries = try context.fetch(descriptor)
        let title = songTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = songArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let existing = matchingEntries.max(by: { $0.updatedAt < $1.updatedAt }) {
            existing.moodValue = choice.rawValue
            existing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if updatesPhoto { existing.photoData = photoData }
            if updatesCardPaper { existing.cardPaperID = cardPaperID }
            if updatesSong {
                existing.songTitle = title.isEmpty ? nil : title
                existing.songArtist = title.isEmpty || artist.isEmpty ? nil : artist
            }
            existing.updatedAt = .now
            matchingEntries.filter { $0.id != existing.id }.forEach(context.delete)
        } else {
            let created = MoodEntry(dayKey: key, choice: choice,
                                    note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            created.photoData = photoData
            if updatesCardPaper { created.cardPaperID = cardPaperID }
            if updatesSong {
                created.songTitle = title.isEmpty ? nil : title
                created.songArtist = title.isEmpty || artist.isEmpty ? nil : artist
            }
            context.insert(created)
        }
        try context.save()
    }

    func reconcileDuplicates() throws {
        let allEntries = try context.fetch(FetchDescriptor<MoodEntry>())
        var removedDuplicate = false
        for entriesForDay in Dictionary(grouping: allEntries, by: \.dayKey).values where entriesForDay.count > 1 {
            guard let latest = entriesForDay.max(by: Self.isOlder) else { continue }
            entriesForDay.filter { $0.id != latest.id }.forEach(context.delete)
            removedDuplicate = true
        }
        if removedDuplicate { try context.save() }
    }

    private static func isOlder(_ lhs: MoodEntry, than rhs: MoodEntry) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor
struct MonthlyNoteStore {
    let context: ModelContext

    func save(monthKey: String, text: String) throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<MonthlyNote>(predicate: #Predicate { $0.monthKey == monthKey })
        let matchingNotes = try context.fetch(descriptor)

        if let existing = matchingNotes.max(by: { $0.updatedAt < $1.updatedAt }) {
            if value.isEmpty {
                matchingNotes.forEach(context.delete)
            } else {
                existing.text = value
                existing.updatedAt = .now
                matchingNotes.filter { $0.id != existing.id }.forEach(context.delete)
            }
        } else if !value.isEmpty {
            context.insert(MonthlyNote(monthKey: monthKey, text: value))
        }

        try context.save()
    }

    func reconcileDuplicates() throws {
        let allNotes = try context.fetch(FetchDescriptor<MonthlyNote>())
        var removedDuplicate = false
        for notesForMonth in Dictionary(grouping: allNotes, by: \.monthKey).values where notesForMonth.count > 1 {
            guard let latest = notesForMonth.max(by: Self.isOlder) else { continue }
            notesForMonth.filter { $0.id != latest.id }.forEach(context.delete)
            removedDuplicate = true
        }
        if removedDuplicate { try context.save() }
    }

    private static func isOlder(_ lhs: MonthlyNote, than rhs: MonthlyNote) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    func migrateLegacyNotes(from defaults: UserDefaults = .standard) throws {
        let prefix = "monthlyTheme-"
        let legacyNotes = defaults.dictionaryRepresentation().compactMap { key, value -> (key: String, monthKey: String, text: String)? in
            guard key.hasPrefix(prefix),
                  let text = value as? String,
                  key.count == prefix.count + 7 else {
                return nil
            }
            return (key, String(key.dropFirst(prefix.count)), text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard !legacyNotes.isEmpty else { return }

        let existingMonthKeys = Set(try context.fetch(FetchDescriptor<MonthlyNote>()).map(\.monthKey))
        for legacyNote in legacyNotes where !existingMonthKeys.contains(legacyNote.monthKey) {
            if !legacyNote.text.isEmpty {
                context.insert(MonthlyNote(monthKey: legacyNote.monthKey, text: legacyNote.text))
            }
        }
        try context.save()
        legacyNotes.forEach { defaults.removeObject(forKey: $0.key) }
    }
}

private enum EntryStoreError: LocalizedError {
    case dateIsReadOnly
    case membershipRequired

    var errorDescription: String? {
        switch self {
        case .dateIsReadOnly:
            localized("此日期不可修改，请检查「允许修改往日」设置。")
        case .membershipRequired:
            localized("解锁永久会员后才能使用这套表情。")
        }
    }
}
