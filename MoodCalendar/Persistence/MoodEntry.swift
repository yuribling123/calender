import Foundation
import SwiftData

@Model
final class MoodEntry {
    @Attribute(.unique) var dayKey: String
    var moodValue: Int
    var note: String

    init(dayKey: String, mood: Mood, note: String) {
        self.dayKey = dayKey
        moodValue = mood.rawValue
        self.note = note
    }

    var mood: Mood? { Mood(rawValue: moodValue) }
}
