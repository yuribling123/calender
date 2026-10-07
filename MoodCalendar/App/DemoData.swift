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
        let year = Calendar.current.component(.year, from: Date())

        let seededMonthKeys = Set(try context.fetch(FetchDescriptor<MonthlyNote>()).map(\.monthKey))
        if !seededMonthKeys.contains("\(year)-07") {
            context.insert(MonthlyNote(monthKey: "\(year)-07", text: "慢一点，也没关系。"))
        }
        if !seededMonthKeys.contains("\(year)-08") {
            context.insert(MonthlyNote(monthKey: "\(year)-08", text: "把喜欢的事，留一点给自己。"))
        }

        guard try context.fetch(FetchDescriptor<MoodEntry>()).isEmpty else { return }
        let examples: [(Int, Int, DailyChoice, String)] = [
            // June: 5 records, covering all three choice groups.
            (6, 3, .good, "天气很好，心里亮了一点。"),
            (6, 9, .bad, ""),
            (6, 15, .coffee, ""),
            (6, 21, .exercise, "动一动，状态回来啦。"),
            (6, 27, .study, ""),
            // August: 6 records, covering all three choice groups.
            (8, 2, .veryGood, ""),
            (8, 8, .okay, ""),
            (8, 14, .music, ""),
            (8, 19, .cake, "吃到了喜欢的甜点。"),
            (8, 24, .work, ""),
            (8, 29, .relax, ""),
            // September: 10 records, covering all three choice groups.
            (9, 1, .good, "早上出门走了一圈，风很舒服。"),
            (9, 4, .veryGood, ""),
            (9, 7, .bad, "事情有点多，先允许自己慢下来。"),
            (9, 10, .clover, ""),
            (9, 13, .heart, "见到喜欢的人，心情亮了一下。"),
            (9, 16, .coffee, ""),
            (9, 19, .exercise, "动一动之后，状态真的回来了。"),
            (9, 22, .work, ""),
            (9, 25, .study, "终于把一直没弄懂的地方想明白了。"),
            (9, 28, .gather, "")
        ]

        for (month, day, choice, note) in examples {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else { continue }
            context.insert(MoodEntry(dayKey: DayKey(date).storageValue, choice: choice, note: note))
        }
        try context.save()
    }
    #endif
}
