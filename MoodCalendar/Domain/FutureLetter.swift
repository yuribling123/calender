import Foundation

/// A private letter has its own calendar date; it never creates a future diary entry.
struct FutureLetter: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    let writtenDay: DayKey
    var deliveryDay: DayKey
    let createdAt: Date
    var updatedAt: Date
    var openedAt: Date?

    func hasArrived(on today: DayKey) -> Bool { deliveryDay <= today }
    var isOpened: Bool { openedAt != nil }

    static func date(for day: DayKey, calendar: Calendar = .current) -> Date? {
        guard (1...9999).contains(day.year), (1...12).contains(day.month), (1...31).contains(day.day),
              let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)),
              DayKey(date, calendar: calendar) == day else { return nil }
        return date
    }
}

enum FutureLetterError: Error, Equatable {
    case emptyBody, textTooLong, dateMustBeFuture, invalidDate, letterMissing, earlyOpeningNeedsConfirmation
    case alreadyOpened, unsupportedArchive, damagedArchive

    var messageKey: String {
        switch self {
        case .emptyBody: "先给未来的自己写几句话吧。"
        case .textTooLong: "标题最多 40 字，正文最多 3000 字。"
        case .dateMustBeFuture: "请选择今天之后的拆信日期。"
        case .invalidDate: "这个日期无效，请重新选择。"
        case .letterMissing: "这封纸条已经不存在了。"
        case .earlyOpeningNeedsConfirmation: "还没到约定的日子，请先确认提前拆开。"
        case .alreadyOpened: "已经拆开的纸条会保留原样。"
        case .unsupportedArchive: "这份纸条存档来自更新版本，请更新应用后再试。"
        case .damagedArchive: "纸条存档暂时无法读取，原文件已保留。"
        }
    }
}
