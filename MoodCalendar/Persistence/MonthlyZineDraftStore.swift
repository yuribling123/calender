import Foundation

/// Independent local layout preferences. Never writes to the source SwiftData store.
final class MonthlyZineDraftStore {
    enum StoreError: LocalizedError {
        case unreadable
        case invalidMonth
        case invalidDraft
        var errorDescription: String? {
            switch self {
            case .unreadable: localized("未能读取小刊草稿，原文件已保留。请稍后重试。")
            case .invalidMonth: localized("请选择已经到来的月份。")
            case .invalidDraft: localized("小刊草稿的格式不正确。")
            }
        }
    }

    private let fileURL: URL?
    private var drafts: [String: MonthlyZineDraft] = [:]
    private(set) var loadError: Error?
    private static let demoStore = MonthlyZineDraftStore(fileURL: nil)

    init(fileURL: URL?) {
        self.fileURL = fileURL
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: MonthlyZineDraft].self, from: Data(contentsOf: fileURL))
            // A time-zone change or clock correction may temporarily put a saved month ahead
            // of today. Keep that valid draft; only creation/import enforce today's boundary.
            try Self.validate(decoded, allowFutureMonths: true)
            drafts = decoded
        } catch {
            // Do not replace unreadable user data with an empty dictionary on the next save.
            loadError = StoreError.unreadable
        }
    }

    static func applicationStore(isDemo: Bool) -> MonthlyZineDraftStore {
        if isDemo { return demoStore }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return MonthlyZineDraftStore(fileURL: directory?
            .appendingPathComponent("MoodCalendar", isDirectory: true)
            .appendingPathComponent("monthly-zine-drafts-v1.json"))
    }

    func draft(for monthKey: String) -> MonthlyZineDraft? { drafts[monthKey] }

    func exportDrafts() throws -> [String: MonthlyZineDraft] {
        if let loadError { throw loadError }
        return drafts
    }

    static func validate(_ imported: [String: MonthlyZineDraft], today: Date = .now,
                         calendar: Calendar = .current, allowFutureMonths: Bool = false) throws {
        for (key, draft) in imported {
            guard MonthlyZine.date(for: key, calendar: calendar) != nil,
                  allowFutureMonths || key <= MonthlyZine.monthKey(today, calendar: calendar) else { throw StoreError.invalidMonth }
            guard draft.title.count <= MonthlyZine.titleLimit,
                  draft.introduction.count <= MonthlyZine.introductionLimit,
                  draft.selectedDayKeys.count <= MonthlyZine.maximumMemories,
                  Set(draft.selectedDayKeys).count == draft.selectedDayKeys.count,
                  draft.selectedDayKeys.allSatisfy({ $0.hasPrefix(key + "-") && MonthlyZine.dayDate($0, calendar: calendar) != nil }),
                  draft.photoDayKey.map({ $0.hasPrefix(key + "-") && MonthlyZine.dayDate($0, calendar: calendar) != nil }) ?? true
            else { throw StoreError.invalidDraft }
        }
    }

    @discardableResult
    func mergeImportedDrafts(_ imported: [String: MonthlyZineDraft], today: Date = .now,
                            calendar: Calendar = .current) throws -> Int {
        if let loadError { throw loadError }
        try Self.validate(imported, today: today, calendar: calendar)
        var next = drafts
        let additions = imported.filter { next[$0.key] == nil }
        for (key, draft) in additions { next[key] = draft }
        try write(next)
        drafts = next
        return additions.count
    }

    func save(_ draft: MonthlyZineDraft, for monthKey: String, today: Date = .now,
              calendar: Calendar = .current) throws {
        if let loadError { throw loadError }
        guard MonthlyZine.date(for: monthKey, calendar: calendar) != nil,
              monthKey <= MonthlyZine.monthKey(today, calendar: calendar) else { throw StoreError.invalidMonth }
        try Self.validate([monthKey: draft], today: today, calendar: calendar)
        var next = drafts
        next[monthKey] = draft
        try write(next)
        drafts = next
    }

    private func write(_ next: [String: MonthlyZineDraft]) throws {
        if let fileURL {
            let data = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
        }
    }
}
