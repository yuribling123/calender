import Foundation

@main
enum AppUpdateChecks {
    static func main() throws {
        precondition(AppVersion.isNewer("1.0.10", than: "1.0.9"))
        precondition(!AppVersion.isNewer("1.0.9", than: "1.0.10"))
        precondition(AppVersion.isNewer("2.0", than: "1.99.99"))
        precondition(!AppVersion.isNewer("1.0.0", than: "1.0"))
        precondition(!AppVersion.isNewer("1.0", than: "1.0.0"))
        for invalid in ["", "1..2", "1.beta", "-1.0", "１.０", "99999999999999999999999"] {
            precondition(!AppVersion.isNewer(invalid, than: "1.0"))
            precondition(!AppVersion.isNewer("2.0", than: invalid))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = formatter.date(from: "2026-11-18T15:59:00Z")!
        let afterMidnight = formatter.date(from: "2026-11-18T16:01:00Z")!
        precondition(AppUpdatePolicy.shouldCheck(now: beforeMidnight, lastAttempt: nil, calendar: calendar))
        precondition(!AppUpdatePolicy.shouldCheck(now: beforeMidnight.addingTimeInterval(30), lastAttempt: beforeMidnight, calendar: calendar))
        precondition(AppUpdatePolicy.shouldCheck(now: afterMidnight, lastAttempt: beforeMidnight, calendar: calendar))
        precondition(!AppUpdatePolicy.shouldCheck(now: beforeMidnight, lastAttempt: afterMidnight, calendar: calendar))
        let data = Data(#"{"bundleId":"com.qingqing.MoodCalendar","version":"1.0.10","trackViewUrl":"https://apps.apple.com/cn/app/id123456789"}"#.utf8)
        let update = try JSONDecoder().decode(AppStoreUpdate.self, from: data)
        precondition(update.productURL?.host == "apps.apple.com")
        precondition(AppUpdatePolicy.shouldOffer(update, bundleID: update.bundleId, installed: "1.0.9", dismissed: []))
        precondition(!AppUpdatePolicy.shouldOffer(update, bundleID: update.bundleId, installed: "1.0.9", dismissed: ["1.0.10"]))
        precondition(AppUpdatePolicy.shouldOffer(update, bundleID: update.bundleId, installed: "1.0.9", dismissed: ["1.0.8"]))
        precondition(!AppUpdatePolicy.shouldOffer(update, bundleID: "other.app", installed: "1.0.9", dismissed: []))
        precondition(!AppUpdatePolicy.shouldOffer(update, bundleID: update.bundleId, installed: "1.0.10", dismissed: []))
        let invalid = AppStoreUpdate(bundleId: update.bundleId, version: update.version, trackViewUrl: URL(string: "https://example.com")!)
        precondition(invalid.productURL == nil)
        print("App update checks passed: numeric versions, invalid versions, daily limits, clock rollback and product URLs.")
    }
}
