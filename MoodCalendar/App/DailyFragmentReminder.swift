import Foundation
import UserNotifications

enum DailyFragmentReminder {
    private static let identifierPrefix = "daily-fragment-reminder-"
    private static let scheduledDayLimit = 60

    static func refresh(recordedDayKeys: Set<String>, isEnabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let existingRequests = await center.pendingNotificationRequests()
        let reminderIDs = existingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        guard isEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
            return
        }

        let settings = await center.notificationSettings()
        var isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        if settings.authorizationStatus == .notDetermined {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }

        center.removePendingNotificationRequests(withIdentifiers: reminderIDs)

        center.removeDeliveredNotifications(
            withIdentifiers: recordedDayKeys.map(notificationID(for:))
        )

        guard isAuthorized else { return }

        let otherPendingCount = existingRequests.count - reminderIDs.count
        let availableSlots = max(0, 64 - otherPendingCount)
        let scheduleCount = min(scheduledDayLimit, availableSlots)
        guard scheduleCount > 0 else { return }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        // iOS caps an app at 64 pending local notifications. Keep a rolling
        // two-month queue and refill it whenever the app becomes active or a
        // daily entry changes.
        for offset in 0..<365 where requests.count < scheduleCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayKey = DayKey(day).storageValue
            guard !recordedDayKeys.contains(dayKey),
                  let fireDate = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: day),
                  fireDate > now else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = 21
            components.minute = 30

            let content = UNMutableNotificationContent()
            content.title = "今天的零碎"
            content.body = "捡一件喜欢的回来"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            requests.append(UNNotificationRequest(
                identifier: notificationID(for: dayKey),
                content: content,
                trigger: trigger
            ))
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    private static func notificationID(for dayKey: String) -> String {
        identifierPrefix + dayKey
    }
}
