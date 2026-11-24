import Foundation

enum MonthlyNoteSkin: String, CaseIterable, Identifiable {
    case plain, grid, tablecloth, polkaDots, lace, player, player2, transparentPlayer, ticket
    // case screen // 复古屏幕暂时停用，保留实现供参考。

    // 电影票暂时停用新选择；ticket 标识与绘制保留，兼容历史记录和备份。
    static let selectableSkins: [Self] = [
        .plain, .grid, .tablecloth, .polkaDots, .lace, .player, .player2, .transparentPlayer,
        // .ticket,
    ]

    var requiresMembership: Bool {
        switch self {
        case .plain, .grid, .tablecloth: false
        case .polkaDots, .lace, .player, .player2, .transparentPlayer, .ticket: true
        }
    }

    var id: String { rawValue }
    var title: String {
        switch self {
        case .plain: "素笺小记"
        case .grid: "格子日记"
        case .polkaDots: "糖纸波点"
        // case .screen: "复古屏幕"
        case .lace: "裙边私语"
        case .ticket: "电影票"
        case .player: "月光电台"
        case .player2: "午夜电台"
        case .transparentPlayer: "透明随身听"
        case .tablecloth: "半杯奶茶"
        }
    }
}
