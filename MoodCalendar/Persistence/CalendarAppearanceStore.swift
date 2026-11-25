import Foundation
import SwiftData

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case black, pink, apricot, sage, blue, lavender, caramel, creamYellow
    static let defaultTheme: Self = .black
    var id: String { rawValue }
}

enum SelectionShape: String, CaseIterable, Identifiable, Sendable {
    case circle, star, sakura, leaf, cat, heart
    static let defaultShape: Self = .sakura
    var id: String { rawValue }
}

enum CalendarBookmarkStyle: String, CaseIterable, Identifiable, Sendable {
    case dateColor, highlighter
    var id: String { rawValue }
}

enum CalendarAppearanceKey: String, CaseIterable {
    case theme = "appTheme"
    case shape = "selectionShape"
    case bookmark = "calendarBookmarkStyle"

    var defaultValue: String {
        switch self {
        case .theme: AppTheme.defaultTheme.rawValue
        case .shape: SelectionShape.defaultShape.rawValue
        case .bookmark: CalendarBookmarkStyle.dateColor.rawValue
        }
    }

    func accepts(_ value: String) -> Bool {
        switch self {
        case .theme: AppTheme(rawValue: value) != nil
        case .shape: SelectionShape(rawValue: value) != nil
        case .bookmark: CalendarBookmarkStyle(rawValue: value) != nil
        }
    }

    static func supportedValues(in values: [String: String]) -> [String: String] {
        values.filter { key, value in Self(rawValue: key)?.accepts(value) == true }
    }
}

/// Each setting has its own history so simultaneous changes to different
/// settings can merge across devices. All fields have CloudKit-compatible defaults.
@Model
final class CalendarAppearanceSelection {
    var id: UUID = UUID()
    var key: String = ""
    var value: String = ""
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(key: String, value: String, updatedAt: Date) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

@MainActor
struct CalendarAppearanceStore {
    let context: ModelContext

    static func latestValues(in selections: [CalendarAppearanceSelection]) -> [String: String] {
        let valid = selections.filter { CalendarAppearanceKey(rawValue: $0.key)?.accepts($0.value) == true }
        return Dictionary(grouping: valid, by: \.key).compactMapValues { versions in
            versions.max { first, second in
                if first.updatedAt != second.updatedAt { return first.updatedAt < second.updatedAt }
                return first.id.uuidString < second.id.uuidString
            }?.value
        }
    }

    func backupValues() throws -> [String: String] {
        let values = Self.latestValues(in: try context.fetch(FetchDescriptor<CalendarAppearanceSelection>()))
        return Dictionary(uniqueKeysWithValues: CalendarAppearanceKey.allCases.map {
            ($0.rawValue, values[$0.rawValue] ?? $0.defaultValue)
        })
    }

    func select(_ value: String, for key: CalendarAppearanceKey) throws {
        do {
            try restore([key.rawValue: value])
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Stages supported changes in the caller's backup transaction.
    func restore(_ values: [String: String]) throws {
        let values = CalendarAppearanceKey.supportedValues(in: values)
        guard !values.isEmpty else { return }
        let selections = try context.fetch(FetchDescriptor<CalendarAppearanceSelection>())
        let current = Self.latestValues(in: selections)
        let newestDate = selections.map(\.updatedAt).max() ?? .distantPast
        let updatedAt = max(.now, newestDate.addingTimeInterval(0.001))
        for (key, value) in values where current[key] != value {
            context.insert(CalendarAppearanceSelection(key: key, value: value, updatedAt: updatedAt))
        }
    }

    func migrateLegacySelections(defaults: UserDefaults = .standard) throws {
        let keys = CalendarAppearanceKey.allCases.filter { defaults.object(forKey: $0.rawValue) != nil }
        guard !keys.isEmpty else { return }
        let current = Self.latestValues(in: try context.fetch(FetchDescriptor<CalendarAppearanceSelection>()))
        for key in keys where current[key.rawValue] == nil {
            guard let value = defaults.string(forKey: key.rawValue), key.accepts(value) else { continue }
            context.insert(CalendarAppearanceSelection(key: key.rawValue, value: value,
                                                       updatedAt: Date(timeIntervalSince1970: 0)))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        for key in keys { defaults.removeObject(forKey: key.rawValue) }
    }
}
