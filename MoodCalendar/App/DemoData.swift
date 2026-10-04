import Foundation
import SwiftData

/// Launch with -demoData in Debug to use disposable examples instead of the user's store.
enum DemoData {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-demoData")
        #else
        false
        #endif
    }

    #if DEBUG
    @MainActor
    static func seed(into context: ModelContext) throws {
        guard try context.fetch(FetchDescriptor<MoodEntry>()).isEmpty else { return }
        let examples: [(Int, Mood, String)] = [
            (-1, .good, "今天散了步，吹到晚风，心情轻松了很多。"),
            (-3, .bad, ""),
            (-8, .veryGood, "和朋友见面，聊了很久。"),
            (-15, .okay, "平静的一天。")
        ]

        for (offset, mood, note) in examples {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
                continue
            }
            context.insert(MoodEntry(dayKey: DayKey(date).storageValue, mood: mood, note: note))
        }
        try context.save()
    }
    #endif
}
