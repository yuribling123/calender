import Foundation
import SwiftData

/// Legacy local date bookmarks; past dates follow the past-editing preference.
enum StarredDayStore {
    static func decode(_ value: String) -> Set<String> {
        guard let data = value.data(using: .utf8),
              let days = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(days)
    }

    static func canToggle(_ day: DayKey, allowPastDates: Bool, today: DayKey = DayKey(Date())) -> Bool {
        allowPastDates || day >= today
    }

    static func toggling(_ day: DayKey, in value: String, allowPastDates: Bool,
                         today: DayKey = DayKey(Date())) -> String {
        guard canToggle(day, allowPastDates: allowPastDates, today: today) else { return value }
        let dayKey = day.storageValue
        var days = decode(value)
        if !days.insert(dayKey).inserted { days.remove(dayKey) }
        guard let data = try? JSONEncoder().encode(days.sorted()),
              let encoded = String(data: data, encoding: .utf8) else { return value }
        return encoded
    }
}

/// An explicit false value is retained so an unmark reaches other devices.
@Model
final class StarredDaySelection {
    var id: UUID = UUID()
    var dayKey: String = ""
    var isStarred: Bool = false
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(dayKey: String, isStarred: Bool, updatedAt: Date = .now) {
        self.dayKey = dayKey
        self.isStarred = isStarred
        self.updatedAt = updatedAt
    }
}

@MainActor
struct StarredDayPersistence {
    let context: ModelContext
    var defaults: UserDefaults = .standard

    static func selections(in records: [StarredDaySelection]) -> [String: Bool] {
        Dictionary(grouping: records, by: \.dayKey).compactMapValues {
            $0.max(by: isOlder)?.isStarred
        }
    }

    static func isValidDayKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              key.utf8.allSatisfy({ $0 == 45 || (48...57).contains($0) }),
              let year = Int(parts[0]), (1...9999).contains(year),
              let month = Int(parts[1]), let day = Int(parts[2]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        return DayKey(date, calendar: calendar).storageValue == key
    }

    func backupSelections() throws -> [String: Bool] {
        Self.selections(in: try context.fetch(FetchDescriptor<StarredDaySelection>()))
    }

    func toggle(_ day: DayKey, now: Date = .now) throws {
        let allowsPast = defaults.object(forKey: "allowPastDateEditing") as? Bool ?? true
        guard StarredDayStore.canToggle(day, allowPastDates: allowsPast, today: DayKey(now)) else {
            throw BookmarkError.dateIsReadOnly
        }
        let key = day.storageValue
        let matches = try context.fetch(FetchDescriptor<StarredDaySelection>(predicate: #Predicate { $0.dayKey == key }))
        if let latest = matches.max(by: Self.isOlder) {
            latest.isStarred.toggle()
            latest.updatedAt = now
            // Keep duplicate identities: an old offline device may still edit one.
            // Reads consistently choose the newest dated state.
        } else {
            context.insert(StarredDaySelection(dayKey: key, isStarred: true, updatedAt: now))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    /// Called within the backup transaction; preserve existing local states, even false.
    func restore(_ imported: [String: Bool]) throws {
        let existing = try backupSelections()
        for (day, marked) in imported where existing[day] == nil {
            guard Self.isValidDayKey(day) else { throw BookmarkError.invalidDate }
            context.insert(StarredDaySelection(dayKey: day, isStarred: marked))
        }
    }

    func migrateLegacySelections() throws {
        guard let legacy = defaults.string(forKey: "starredDays.v1") else { return }
        let existing = try backupSelections()
        for day in StarredDayStore.decode(legacy) where existing[day] == nil && Self.isValidDayKey(day) {
            context.insert(StarredDaySelection(dayKey: day, isStarred: true,
                                               updatedAt: Date(timeIntervalSince1970: 0)))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        defaults.removeObject(forKey: "starredDays.v1")
    }

    private static func isOlder(_ lhs: StarredDaySelection, _ rhs: StarredDaySelection) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private enum BookmarkError: LocalizedError {
        case dateIsReadOnly, invalidDate
        var errorDescription: String? {
            switch self {
            case .dateIsReadOnly: localized("此日期不可修改，请检查「允许修改往日」设置。")
            case .invalidDate: localized("备份文件内容不完整或格式有误。")
            }
        }
    }
}
