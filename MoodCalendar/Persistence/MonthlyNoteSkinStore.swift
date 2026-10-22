import Foundation
import SwiftData

/// Separate from note text so a month can have a style without an empty note.
/// Defaults on every field keep the model compatible with CloudKit.
@Model
final class MonthlyNoteSkinSelection {
    var id: UUID = UUID()
    var monthKey: String = ""
    var skinID: String = "plain"
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(monthKey: String, skin: MonthlyNoteSkin, updatedAt: Date = .now) {
        self.monthKey = monthKey
        skinID = skin.rawValue
        self.updatedAt = updatedAt
    }
}

@MainActor
struct MonthlyNoteSkinStore {
    let context: ModelContext
    var defaults: UserDefaults = .standard
    private let legacyKey = "monthlyNoteSkins.v1"

    static func skin(for monthKey: String, in selections: [MonthlyNoteSkinSelection]) -> MonthlyNoteSkin {
        let latest = selections.filter { $0.monthKey == monthKey }.max(by: isOlder)
        return latest.flatMap { MonthlyNoteSkin(rawValue: $0.skinID) } ?? .plain
    }

    func backupSelections() throws -> [String: String] {
        let selections = try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>())
        return Dictionary(grouping: selections, by: \.monthKey).compactMapValues {
            $0.max(by: Self.isOlder)?.skinID
        }
    }

    func select(_ skin: MonthlyNoteSkin, for monthKey: String, isMember: Bool, now: Date = .now) throws {
        let selection = NoteMonthSelection(now: now)
        let allowsPastDates = defaults.object(forKey: "allowPastDateEditing") as? Bool ?? true
        guard let (year, month) = Self.components(of: monthKey),
              selection.isAllowed(year: year, month: month, allowPastDates: allowsPastDates) else {
            throw SkinStoreError.dateIsReadOnly
        }
        guard !skin.requiresMembership || isMember else { throw SkinStoreError.membershipRequired }
        let matches = try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>(
            predicate: #Predicate { $0.monthKey == monthKey }
        ))
        if let latest = matches.max(by: Self.isOlder) {
            latest.skinID = skin.rawValue
            latest.updatedAt = now
            matches.filter { $0.id != latest.id }.forEach(context.delete)
        } else {
            // Persist plain too: resetting a style must reach other devices.
            context.insert(MonthlyNoteSkinSelection(monthKey: monthKey, skin: skin, updatedAt: now))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Merge as part of the caller's backup-import transaction, without overwriting local choices.
    func restore(_ imported: [String: String], excluding existingMonths: Set<String>) throws {
        let existingSelections = Set(try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>()).map(\.monthKey))
        for (month, rawValue) in imported where !existingMonths.contains(month) && !existingSelections.contains(month) {
            guard Self.components(of: month) != nil, let skin = MonthlyNoteSkin(rawValue: rawValue) else { continue }
            context.insert(MonthlyNoteSkinSelection(monthKey: month, skin: skin))
        }
    }

    /// A successful save retires the old preferences. Old devices' migrations must
    /// rank below later explicit selections when their records eventually sync.
    func migrateLegacySelections() throws {
        guard let legacy = defaults.dictionary(forKey: legacyKey) as? [String: String] else { return }
        let existingMonths = Set(try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>()).map(\.monthKey))
        for (month, rawValue) in legacy where !existingMonths.contains(month) {
            guard Self.components(of: month) != nil, let skin = MonthlyNoteSkin(rawValue: rawValue) else { continue }
            context.insert(MonthlyNoteSkinSelection(monthKey: month, skin: skin,
                                                  updatedAt: Date(timeIntervalSince1970: 0)))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        defaults.removeObject(forKey: legacyKey)
    }

    func reconcileDuplicates() throws {
        let all = try context.fetch(FetchDescriptor<MonthlyNoteSkinSelection>())
        var removedDuplicate = false
        for matches in Dictionary(grouping: all, by: \.monthKey).values where matches.count > 1 {
            guard let latest = matches.max(by: Self.isOlder) else { continue }
            matches.filter { $0.id != latest.id }.forEach(context.delete)
            removedDuplicate = true
        }
        if removedDuplicate { try context.save() }
    }

    private static func isOlder(_ lhs: MonthlyNoteSkinSelection, than rhs: MonthlyNoteSkinSelection) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func components(of key: String) -> (Int, Int)? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]),
              NoteMonthSelection().date(year: year, month: month) != nil else { return nil }
        return (year, month)
    }

    private enum SkinStoreError: LocalizedError {
        case dateIsReadOnly, membershipRequired

        var errorDescription: String? {
            switch self {
            case .dateIsReadOnly: localized("此日期不可修改，请检查「允许修改往日」设置。")
            case .membershipRequired: localized("解锁永久会员后才能使用这套表情。")
            }
        }
    }
}
