import Foundation

enum MonthlyNoteSkin: String, CaseIterable, Identifiable {
    case plain, grid, tablecloth, lace, player, player2, ticket
    // case screen // 复古屏幕暂时停用，保留实现供参考。

    var requiresMembership: Bool { self != .plain && self != .grid }

    var id: String { rawValue }
    var title: String {
        switch self {
        case .plain: "素笺小记"
        case .grid: "格子日记"
        // case .screen: "复古屏幕"
        case .lace: "裙边私语"
        case .ticket: "电影票"
        case .player: "月光电台"
        case .player2: "午夜电台"
        case .tablecloth: "半杯奶茶"
        }
    }
}
