import Foundation
import SwiftData

@main
struct EntryDeletionChecks {
    @MainActor
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let schema = Schema([MoodEntry.self, MonthlyNote.self])
        let container = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let store = EntryStore(context: context)
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "allowPastDateEditing")
        defer {
            if let previous { defaults.set(previous, forKey: "allowPastDateEditing") }
            else { defaults.removeObject(forKey: "allowPastDateEditing") }
        }
        func expect(_ condition: @autoclosure () throws -> Bool) throws {
            let result = try condition()
            precondition(result)
        }
        func count(_ key: String) throws -> Int {
            try context.fetchCount(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.dayKey == key }))
        }
        if CommandLine.arguments[1] == "reopen" {
            try expect(try count("2024-02-29") == 0)
            try expect(try count("2024-03-01") == 1)
            print("Deletion remains saved after reopening")
            return
        }
        defaults.set(true, forKey: "allowPastDateEditing")
        let calendar = Calendar.current
        func day(_ year: Int, _ month: Int, _ date: Int) -> DayKey {
            DayKey(calendar.date(from: DateComponents(year: year, month: month, day: date))!)
        }
        let leapDay = day(2024, 2, 29)
        let nextMonth = day(2024, 3, 1)
        let choice = DailyChoice.allCases.first!
        for memberChoice in [DailyChoice.cooking, .gaming, .tastyFood, .watchingShows, .walking, .shopping] {
            do {
                try store.save(day: leapDay, choice: memberChoice, note: "locked")
                fatalError("New everyday stickers must require membership")
            } catch {
                try expect(error.localizedDescription == localized("解锁永久会员后才能使用这套表情。"))
            }
            try store.save(day: leapDay, choice: memberChoice, note: "member", isMember: true)
            let key = leapDay.storageValue
            let saved = try context.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.dayKey == key }))
            try expect(saved.count == 1 && saved.first?.choice == memberChoice)
        }
        try store.save(day: leapDay, choice: choice, note: "first")
        try store.save(day: leapDay, choice: choice, note: "updated")
        try expect(try count(leapDay.storageValue) == 1)
        try store.save(day: nextMonth, choice: choice, note: "keep")
        // Also remove any legacy duplicates for the selected day.
        context.insert(MoodEntry(dayKey: leapDay.storageValue, choice: choice, note: "duplicate"))
        try context.save()
        defaults.set(false, forKey: "allowPastDateEditing")
        do {
            try store.delete(day: leapDay)
            fatalError("Past date deletion should be blocked")
        } catch { }
        try expect(try count(leapDay.storageValue) == 2)
        let today = DayKey(Date())
        try store.save(day: today, choice: choice, note: "today")
        try store.delete(day: today)
        try expect(try count(today.storageValue) == 0)
        defaults.set(true, forKey: "allowPastDateEditing")
        let future = DayKey(calendar.date(byAdding: .day, value: 1, to: Date())!)
        do {
            try store.delete(day: future)
            fatalError("Future date deletion should be blocked")
        } catch { }
        try store.delete(day: leapDay)
        try store.delete(day: leapDay)
        try expect(try count(leapDay.storageValue) == 0)
        try expect(try count(nextMonth.storageValue) == 1)
        print("Deletion permissions, leap day, month boundary and duplicate checks passed")
    }
}
