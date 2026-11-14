import Foundation
import SwiftData

@main
struct WatchRecordingChecks {
    @MainActor
    static func main() throws {
        func expect(_ condition: @autoclosure () throws -> Bool, _ message: String = "Check failed") rethrows {
            let result = try condition()
            precondition(result, message)
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let container = try ModelContainer(for: MoodEntry.self, configurations:
            ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let store = EntryStore(context: context)
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "allowPastDateEditing")
        defer {
            if let previous { defaults.set(previous, forKey: "allowPastDateEditing") }
            else { defaults.removeObject(forKey: "allowPastDateEditing") }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func day(_ month: Int, _ day: Int) -> DayKey {
            DayKey(calendar.date(from: DateComponents(year: 2024, month: month, day: day, hour: 12))!, calendar: calendar)
        }
        func records() throws -> [MoodEntry] { try context.fetch(FetchDescriptor<MoodEntry>()) }
        func saved(_ key: String) throws -> MoodEntry { try records().first { $0.dayKey == key }! }
        let leapDay = day(2, 29)
        let march = day(3, 1)
        if CommandLine.arguments[1] == "reopen" {
            let entries = try records()
            precondition(entries.count == 2)
            try expect(try saved(leapDay.storageValue).watchKind == WatchKind.movie.rawValue)
            try expect(try saved(march.storageValue).watchKind == WatchKind.series.rawValue)
            precondition(EntryCollection.watches(from: entries).count == 2)
            print("Movie and series types survived a separate-process reopen")
            return
        }
        defaults.set(true, forKey: "allowPastDateEditing")
        try store.save(day: leapDay, choice: .good, note: "闰日", watchTitle: "同名作品",
                       watchKind: WatchKind.movie.rawValue, watchNote: "电影感受", updatesWatch: true)
        try store.save(day: march, choice: .good, note: "月初", watchTitle: "同名作品",
                       watchKind: WatchKind.series.rawValue, updatesWatch: true)
        try expect(EntryCollection.watches(from: try records()).count == 2, "Different types stay separate")
        try store.save(day: leapDay, choice: .good, note: "闰日", watchTitle: "同名作品",
                       watchKind: WatchKind.series.rawValue, updatesWatch: true)
        let merged = EntryCollection.watches(from: try records())
        precondition(merged.count == 1 && merged[0].memories.map(\.id) == [march.storageValue, leapDay.storageValue])
        try expect(try records().count == 2, "Type changes update the existing day")
        try store.save(day: leapDay, choice: .good, note: "闰日", watchTitle: "同名作品",
                       watchKind: WatchKind.movie.rawValue, updatesWatch: true)
        try store.save(day: leapDay, choice: .good, note: "只改文字")
        try expect(try saved(leapDay.storageValue).watchKind == "movie", "Unrelated edits preserve the type")
        defaults.set(false, forKey: "allowPastDateEditing")
        do {
            try store.save(day: leapDay, choice: .good, note: "禁止", watchTitle: "不能改",
                           watchKind: "series", updatesWatch: true)
            preconditionFailure("Past edits must respect the preference")
        } catch { }
        defaults.set(true, forKey: "allowPastDateEditing")
        let future = DayKey(calendar.date(byAdding: .day, value: 1, to: .now)!, calendar: calendar)
        do {
            try store.save(day: future, choice: .good, note: "禁止", watchTitle: "未来", watchKind: "movie", updatesWatch: true)
            preconditionFailure("Future dates must remain read-only")
        } catch { }
        try store.save(day: march, choice: .good, note: "移除", watchTitle: "", watchKind: "series", updatesWatch: true)
        let cleared = try saved(march.storageValue)
        precondition(cleared.watchTitle == nil && cleared.watchKind == nil && cleared.watchNote == nil)
        try store.save(day: march, choice: .good, note: "恢复", watchTitle: "同名作品", watchKind: "series", updatesWatch: true)
        print("Movie/series save, update, permissions, collection history and removal checks passed")
    }
}
