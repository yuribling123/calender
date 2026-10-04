import Foundation
import SwiftData

@MainActor
struct EntryStore {
    let context: ModelContext

    func save(day: DayKey, mood: Mood, note: String) throws {
        guard day == DayKey(Date()) else { throw EntryStoreError.onlyTodayIsEditable }
        let key = day.storageValue
        let descriptor = FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.dayKey == key })
        if let existing = try context.fetch(descriptor).first {
            existing.moodValue = mood.rawValue
            existing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            context.insert(MoodEntry(dayKey: key, mood: mood,
                                     note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        try context.save()
    }
}

private enum EntryStoreError: LocalizedError {
    case onlyTodayIsEditable

    var errorDescription: String? {
        "只能记录或修改今天的心情。"
    }
}
