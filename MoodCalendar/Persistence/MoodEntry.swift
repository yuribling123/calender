import Foundation
import SwiftData

@Model
final class MoodEntry {
    var id: UUID = UUID()
    var dayKey: String = ""
    // Keep the original field for SwiftData compatibility; it stores DailyChoice IDs 1–20.
    var moodValue: Int = DailyChoice.veryGood.rawValue
    var note: String = ""
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(dayKey: String, choice: DailyChoice, note: String) {
        self.dayKey = dayKey
        moodValue = choice.rawValue
        self.note = note
        updatedAt = .now
    }

    var choice: DailyChoice? { DailyChoice(rawValue: moodValue) }
}

@Model
final class MonthlyNote {
    var id: UUID = UUID()
    var monthKey: String = ""
    var text: String = ""
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(monthKey: String, text: String) {
        self.monthKey = monthKey
        self.text = text
        updatedAt = .now
    }
}
