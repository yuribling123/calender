import Foundation

@main
struct StarredDayChecks {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = [(2024, 2, 29), (2024, 3, 1), (2025, 12, 31), (2026, 1, 1)]
        var stored = "[]"
        for (year, month, day) in days {
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
            let key = DayKey(date, calendar: calendar)
            stored = StarredDayStore.toggling(key, in: stored, allowPastDates: true)
        }
        precondition(StarredDayStore.decode(stored) == Set(["2024-02-29", "2024-03-01", "2025-12-31", "2026-01-01"]))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try stored.write(to: file, atomically: true, encoding: .utf8)
        let reopened = try String(contentsOf: file, encoding: .utf8)
        precondition(StarredDayStore.decode(reopened).count == 4)
        let leapDay = DayKey(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!, calendar: calendar)
        stored = StarredDayStore.toggling(leapDay, in: reopened, allowPastDates: true)
        precondition(!StarredDayStore.decode(stored).contains("2024-02-29"))
        stored = StarredDayStore.toggling(leapDay, in: stored, allowPastDates: true)
        precondition(StarredDayStore.decode(stored).count == 4)
        let today = DayKey(calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!, calendar: calendar)
        let future = DayKey(calendar.date(from: DateComponents(year: 2024, month: 3, day: 2))!, calendar: calendar)
        precondition(StarredDayStore.toggling(leapDay, in: stored, allowPastDates: false, today: today) == stored)
        precondition(StarredDayStore.toggling(leapDay, in: "[]", allowPastDates: false, today: today) == "[]")
        for day in [today, future] {
            let added = StarredDayStore.toggling(day, in: "[]", allowPastDates: false, today: today)
            precondition(StarredDayStore.decode(added).contains(day.storageValue))
            precondition(StarredDayStore.decode(StarredDayStore.toggling(day, in: added, allowPastDates: false, today: today)).isEmpty)
        }
        precondition(StarredDayStore.decode("invalid").isEmpty)
        print("Starred-day checks passed: leap day, month/year boundaries, reopening and toggle uniqueness.")
    }
}
