import SwiftUI
import UIKit

enum CollectionPhotoSkin: String, CaseIterable, Identifiable {
    case original, nightPrint, clearPlate

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: localized("原版相纸")
        case .nightPrint: localized("夜拍相纸")
        case .clearPlate: localized("清透片")
        }
    }
    var caption: String {
        switch self {
        case .original: localized("暖白小相纸，留住日常的一瞬")
        case .nightPrint: localized("哑黑相纸，收好夜里的微光")
        case .clearPlate: localized("清透薄片，让回忆轻轻浮着")
        }
    }
    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .original }
}

enum CollectionWatchSkin: String, CaseIterable, Identifiable {
    case original, clearWhite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: localized("经典录像带")
        case .clearWhite: localized("透明录像带")
        }
    }
    var caption: String {
        switch self {
        case .original: localized("小小录像带，收好看过的故事")
        case .clearWhite: localized("清透带壳，留住故事转动的片刻")
        }
    }
    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .original }
}

struct CollectionTapeMaterial {
    let shell: Color
    let bevel: Color
    let edge: Color
    let window: Color
    let pack: Color
    let hub: Color
    let label: Color
    let ink: Color
    let grainOpacity: Double
}

enum CollectionVinylSkin: String, CaseIterable, Identifiable {
    case original, peachSmoke, teaMarble, lightFilm, nightLace
    // case rainMist // 雨雾透胶暂时停用，保留实现。
    // case teaMilkMist // 暂时停用，恢复时放回雨雾透胶之后。

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: localized("原版")
        // case .rainMist: localized("雨雾透胶")
        case .nightLace: localized("夜色蕾丝")
        // case .teaMilkMist: localized("青茶奶雾")
        case .teaMarble: localized("青玉流纹")
        case .peachSmoke: localized("白桃浮烟")
        case .lightFilm: localized("花影白胶")
        }
    }
    var caption: String {
        switch self {
        case .original: localized("细唱纹，哑光黑")
        // case .rainMist: localized("蓝灰透胶，藏着两缕雨雾")
        case .nightLace: localized("梅灰黑胶，轻轻压上一圈蕾丝")
        // case .teaMilkMist: localized("清透茶绿，揉进一团暖奶雾")
        case .teaMarble: localized("青绿透胶，乳白纹路慢慢流淌")
        case .peachSmoke: localized("淡茶桃色，浮着柔柔的奶白烟")
        case .lightFilm: localized("清透白胶，轻轻刻下几朵小花")
        }
    }
    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .original }
}

// Collection skin customization is temporarily disabled.
// enum CollectionVinylSkin: String, CaseIterable, Identifiable {
//     case original, rose, smoked
//     var id: String { rawValue }
//     var title: String {
//         switch self {
//         case .original: localized("原版")
//         case .rose: localized("玫瑰压胶")
//         case .smoked: localized("烟紫透胶")
//         }
//     }
//     static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .original }
// }
//
// enum CollectionTapeSkin: String, CaseIterable, Identifiable {
//     case original, home, archive
//     var id: String { rawValue }
//     var title: String {
//         switch self {
//         case .original: localized("原版")
//         case .home: localized("家庭放映")
//         case .archive: localized("奶油档案")
//         }
//     }
//     static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .original }
// }
//
/// Display preferences for existing date bookmarks; saved dates remain unchanged.
enum CalendarBookmarkStyle: String, CaseIterable, Identifiable {
    case dateColor, highlighter

    var id: String { rawValue }
    var title: String {
        switch self {
        case .dateColor: localized("日期改色")
        case .highlighter: localized("荧光笔")
        }
    }

    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .dateColor }

    static let ink = adaptive(light: rgb(151, 84, 100), dark: rgb(185, 129, 145))
}

/// A short, slightly uneven stroke behind the date; never changes its layout.
struct BookmarkHighlight: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        BookmarkStroke()
            .fill(theme.palette.bookmarkHighlight)
            .padding(.horizontal, -3)
            .frame(height: 16)
            .rotationEffect(.degrees(-3))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BookmarkStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case black, pink, apricot, sage, blue, lavender, caramel, creamYellow

    var requiresMembership: Bool {
        switch self {
        case .black, .pink, .apricot, .sage: false
        case .blue, .lavender, .caramel, .creamYellow: true
        }
    }

    var id: String { rawValue }

    var swatchColor: Color {
        self == .black ? rgb(38, 38, 38) : palette.accent
    }

    var title: String {
        switch self {
        case .pink: localized("薄樱")
        case .apricot: localized("淡杏")
        case .sage: localized("若叶")
        case .blue: localized("水蓝")
        case .lavender: localized("紫藤")
        case .caramel: localized("亚麻")
        case .creamYellow: localized("奶油")
        case .black: localized("曜黑")
        }
    }

    var palette: ThemePalette {
        switch self {
        case .pink:
            ThemePalette.make(accent: rgb(232, 161, 174), selectionFill: rgb(242, 206, 211),
                         softHighlight: rgb(250, 237, 239),
                         strongAccent: rgb(155, 78, 96), todayButtonFill: rgb(174, 91, 110))
        case .apricot:
            ThemePalette.make(accent: rgb(216, 171, 143), selectionFill: rgb(237, 216, 200),
                         softHighlight: rgb(248, 241, 233),
                         strongAccent: rgb(133, 91, 63), todayButtonFill: rgb(147, 104, 77))
        case .sage:
            ThemePalette.make(accent: rgb(161, 178, 154), selectionFill: rgb(205, 220, 203),
                         softHighlight: rgb(240, 243, 235),
                         strongAccent: rgb(82, 105, 76), todayButtonFill: rgb(100, 123, 96))
        case .blue:
            ThemePalette.make(accent: rgb(158, 181, 191), selectionFill: rgb(202, 218, 225),
                         softHighlight: rgb(239, 243, 243),
                         strongAccent: rgb(73, 100, 114), todayButtonFill: rgb(93, 120, 135))
        case .lavender:
            ThemePalette.make(accent: rgb(184, 170, 198), selectionFill: rgb(221, 210, 229),
                         softHighlight: rgb(243, 240, 244),
                         strongAccent: rgb(103, 84, 120), todayButtonFill: rgb(121, 103, 137))
        case .caramel:
            ThemePalette.make(accent: rgb(178, 157, 134), selectionFill: rgb(223, 211, 195),
                         softHighlight: rgb(244, 240, 233),
                         strongAccent: rgb(112, 91, 69), todayButtonFill: rgb(130, 112, 92))
        case .creamYellow:
            ThemePalette.make(accent: rgb(217, 195, 143), selectionFill: rgb(236, 225, 190),
                         softHighlight: rgb(247, 244, 231),
                         strongAccent: rgb(118, 98, 47), todayButtonFill: rgb(137, 118, 63))
        case .black:
            ThemePalette.make(accent: adaptive(light: rgb(56, 56, 56), dark: rgb(180, 180, 180)),
                         selectionFill: rgb(38, 38, 38),
                         softHighlight: rgb(240, 240, 238),
                         strongAccent: rgb(38, 38, 38), todayButtonFill: rgb(113, 109, 101),
                         onSelection: .white, isObsidian: true)
        }
    }
}

enum CardPaper: String, CaseIterable, Identifiable {
    // roseStars remains the saved ID for the replacement mist-purple design.
    case original, pink, apricot, yellow, green, blue, purple, caramel, black, stars, silverStars, creamStars, roseStars
    case strawberryHearts, blueberryHearts, peachHearts, grapeHearts, nightHearts

    var isHeartPattern: Bool {
        switch self {
        case .strawberryHearts, .blueberryHearts, .peachHearts, .grapeHearts, .nightHearts: true
        default: false
        }
    }
    var isStarPattern: Bool { self == .stars || self == .silverStars || self == .creamStars || self == .roseStars }
    var isPatterned: Bool { isStarPattern || isHeartPattern }
    var requiresMembership: Bool { CardPaperAccess.requiresMembership(rawValue) }
    var hasUnbackedStarPreview: Bool { isStarPattern }

    var dotInk: Color { heartInk }

    var heartInk: Color {
        switch self {
        case .strawberryHearts: adaptive(light: rgb(214, 160, 168), dark: rgb(217, 169, 177))
        case .blueberryHearts: adaptive(light: rgb(158, 173, 196), dark: rgb(172, 190, 213))
        case .peachHearts: adaptive(light: rgb(212, 195, 179), dark: rgb(186, 163, 147))
        case .grapeHearts: adaptive(light: rgb(190, 161, 172), dark: rgb(204, 176, 189))
        default: adaptive(light: rgb(216, 191, 195), dark: rgb(222, 201, 205))
        }
    }

    var previewStarInk: Color {
        self == .creamStars
            ? adaptive(light: rgb(216, 206, 190), dark: rgb(196, 187, 170))
            : patternInk
    }

    var patternInk: Color {
        if self == .roseStars {
            return adaptive(light: rgb(196, 105, 151), dark: rgb(222, 135, 175))
        }
        if self == .creamStars {
            return adaptive(light: rgb(255, 252, 245), dark: rgb(196, 187, 170))
        }
        return self == .silverStars
            ? adaptive(light: rgb(65, 65, 65), dark: rgb(190, 190, 190))
            : adaptive(light: rgb(218, 196, 127), dark: rgb(194, 175, 122))
    }

    var secondaryStarInk: Color {
        if self == .roseStars {
            return adaptive(light: rgb(227, 154, 185), dark: rgb(195, 104, 147))
        }
        if self == .creamStars {
            return adaptive(light: rgb(216, 206, 190), dark: rgb(113, 104, 89))
        }
        return adaptive(light: rgb(100, 100, 100), dark: rgb(165, 165, 165))
    }

    var id: String { rawValue }

    static func resolve(_ id: String?) -> CardPaper {
        id.flatMap(CardPaper.init(rawValue:)) ?? .original
    }

    static func matching(_ theme: AppTheme) -> CardPaper {
        switch theme {
        case .pink: .pink
        case .black: .black
        case .apricot: .apricot
        case .sage: .green
        case .blue: .blue
        case .lavender: .purple
        case .caramel: .caramel
        case .creamYellow: .yellow
        }
    }

    var title: String {
        let key = switch self {
        case .original: "跟随主题"
        case .pink: "薄樱"
        case .apricot: "淡杏"
        case .yellow: "奶油"
        case .green: "若叶"
        case .blue: "水蓝"
        case .purple: "紫藤"
        case .caramel: "亚麻"
        case .black: "曜黑"
        case .stars: "奶黄星星"
        case .silverStars: "灰黑星星"
        case .creamStars: "奶油星星"
        case .roseStars: "雾紫星星"
        case .strawberryHearts: "樱桃苏打"
        case .blueberryHearts: "蓝莓爱心"
        case .peachHearts: "杏桃爱心"
        case .grapeHearts: "葡萄爱心"
        case .nightHearts: "夜色爱心"
        }
        return localized(key)
    }

    private var matchingTheme: AppTheme {
        switch self {
        case .original, .pink: .pink
        case .roseStars: .lavender
        case .strawberryHearts: .pink
        case .blueberryHearts: .blue
        case .peachHearts: .apricot
        case .grapeHearts: .lavender
        case .nightHearts: .black
        case .apricot: .apricot
        case .yellow: .creamYellow
        case .green: .sage
        case .blue: .blue
        case .stars, .silverStars: .black
        case .creamStars: .caramel
        case .purple: .lavender
        case .caramel: .caramel
        case .black: .black
        }
    }

    func color(for currentTheme: AppTheme) -> Color {
        let paper = self == .original ? CardPaper.matching(currentTheme) : self
        let light: Color = switch paper {
        case .original, .pink: rgb(248, 240, 239)
        case .apricot: rgb(248, 241, 233)
        case .yellow: rgb(247, 244, 231)
        case .green: rgb(240, 243, 235)
        case .blue: rgb(239, 243, 243)
        case .purple: rgb(243, 240, 244)
        case .caramel: rgb(244, 240, 233)
        case .black: rgb(239, 238, 235)
        case .stars: rgb(254, 253, 252)
        case .silverStars: rgb(250, 248, 244)
        case .creamStars: rgb(238, 232, 222)
        case .roseStars: rgb(250, 248, 244)
        case .strawberryHearts: rgb(250, 251, 252)
        case .blueberryHearts: rgb(252, 250, 245)
        case .peachHearts: rgb(253, 251, 248)
        case .grapeHearts: rgb(252, 249, 250)
        case .nightHearts: rgb(64, 61, 66)
        }
        let dark: Color = switch paper {
        case .original, .pink: rgb(58, 43, 48)
        case .apricot: rgb(59, 46, 38)
        case .yellow: rgb(56, 51, 35)
        case .green: rgb(42, 52, 41)
        case .blue: rgb(39, 50, 57)
        case .purple: rgb(50, 43, 59)
        case .caramel: rgb(53, 47, 40)
        case .black: rgb(46, 44, 41)
        case .stars: rgb(44, 43, 42)
        case .silverStars: rgb(48, 45, 42)
        case .creamStars: rgb(48, 45, 41)
        case .roseStars: rgb(48, 45, 42)
        case .strawberryHearts: rgb(56, 43, 49)
        case .blueberryHearts: rgb(41, 47, 63)
        case .peachHearts: rgb(57, 46, 41)
        case .grapeHearts: rgb(50, 43, 58)
        case .nightHearts: rgb(64, 61, 66)
        }
        return adaptive(light: light, dark: dark)
    }

    func color(for currentTheme: AppTheme, scheme: ColorScheme) -> Color {
        color(for: currentTheme)
    }

    func swatchAccent(for currentTheme: AppTheme) -> Color {
        let theme = self == .original ? currentTheme : matchingTheme
        return theme.palette.accent
    }
}

/// Soft-focus stars repeat beneath the shared card content.
struct CardPaperBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    let paper: CardPaper
    var cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            paper.color(for: theme, scheme: scheme)
            if paper.isHeartPattern {
                Canvas { context, size in
                    // Alternating rows: hearts sit halfway between the dots above and below.
                    let columnSpacing: CGFloat = 84
                    let rowSpacing: CGFloat = 42
                    for row in -1...Int(ceil(size.height / rowSpacing)) {
                        for column in -1...Int(ceil(size.width / columnSpacing)) {
                            let isHeart = row.isMultiple(of: 2)
                            let center = CGPoint(
                                x: CGFloat(column) * columnSpacing + (isHeart ? columnSpacing / 2 : 0) + 10,
                                y: CGFloat(row) * rowSpacing + 12
                            )
                            let path = isHeart
                                ? paperHeart(center: center, size: 9)
                                : Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3,
                                                         width: 6, height: 6))
                            context.fill(path, with: .color((isHeart ? paper.heartInk : paper.dotInk)
                                .opacity(paper == .nightHearts ? 0.82
                                    : (scheme == .dark ? 0.63 : 0.74))))
                        }
                    }
                }
                .blur(radius: 0.35)
            } else if paper.isStarPattern {
                Canvas { context, size in
                    // Anchor to the top-left so longer notes only reveal more rows.
                    // Each star stays inside its own cell, without image tile seams.
                    let columnSpacing: CGFloat = 88
                    let rowSpacing: CGFloat = 64
                    for row in -1...Int(ceil(size.height / rowSpacing)) {
                        for column in -1...Int(ceil(size.width / columnSpacing)) {
                            let variant = ((row * 7 + column * 3) % 5 + 5) % 5
                            let center = CGPoint(
                                x: CGFloat(column) * columnSpacing + 13
                                    + (row.isMultiple(of: 2) ? 0 : columnSpacing / 2)
                                    + CGFloat(variant - 2) * 1.5,
                                y: CGFloat(row) * rowSpacing + 9 + CGFloat(variant - 2) * 2
                            )
                            let radius = 6.25 + CGFloat(variant) * 0.3
                            let rotation = Double(variant * 7 - 14)
                            let print = paperStar(center: center, radius: radius * 0.8, rotation: rotation)
                            if paper == .roseStars {
                                let stamp = ((row * 7 + column * 3) % 10 + 10) % 10
                                let ink = stamp.isMultiple(of: 2) ? paper.patternInk : paper.secondaryStarInk
                                if stamp < 7 {
                                    let opacity = scheme == .dark
                                        ? (stamp < 5 ? 0.32 : 0.40)
                                        : (stamp < 5 ? 0.44 : 0.55)
                                    context.fill(print, with: .color(ink.opacity(opacity)))
                                } else {
                                    context.stroke(print, with: .color(ink.opacity(
                                        scheme == .dark ? 0.42 : 0.50
                                    )), style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))
                                }
                            } else if paper == .creamStars {
                                context.fill(print, with: .color(paper.patternInk.opacity(
                                    scheme == .dark ? 0.38 : 0.86
                                )))
                                context.stroke(print, with: .color(paper.secondaryStarInk.opacity(
                                    scheme == .dark ? 0.5 : 0.65
                                )), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
                            } else if paper == .stars {
                                let ink = scheme == .dark
                                    ? paper.patternInk
                                    : Color(red: 0.89, green: 0.77, blue: 0.39)
                                let opacity = (scheme == .dark ? 0.58 : 0.38) + Double(variant) * 0.015
                                context.fill(print, with: .color(ink.opacity(opacity)))
                            } else {
                                // Original palette: five light fills, two medium fills, three outlines.
                                let stamp = ((row * 7 + column * 3) % 10 + 10) % 10
                                if stamp < 7 {
                                    let opacity: Double = stamp < 5
                                        ? (scheme == .dark ? 0.28 : 0.48)
                                        : (scheme == .dark ? 0.42 : 0.72)
                                    context.fill(print, with: .color(paper.patternInk.opacity(
                                        opacity
                                    )))
                                } else {
                                    context.stroke(print, with: .color(paper.secondaryStarInk.opacity(
                                        scheme == .dark ? 0.44 : 0.66
                                    )), style: StrokeStyle(lineWidth: 0.5, lineCap: .round, lineJoin: .round))
                                }
                            }
                        }
                    }
                }
                .blendMode(.normal)
                .opacity(paper == .stars ? 0.8 : 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func paperHeart(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - size * 0.23))
        path.addCurve(to: CGPoint(x: center.x - size * 0.5, y: center.y - size * 0.10),
                      control1: CGPoint(x: center.x - size * 0.22, y: center.y - size * 0.57),
                      control2: CGPoint(x: center.x - size * 0.52, y: center.y - size * 0.41))
        path.addCurve(to: CGPoint(x: center.x, y: center.y + size * 0.48),
                      control1: CGPoint(x: center.x - size * 0.55, y: center.y + size * 0.16),
                      control2: CGPoint(x: center.x - size * 0.18, y: center.y + size * 0.38))
        path.addCurve(to: CGPoint(x: center.x + size * 0.5, y: center.y - size * 0.10),
                      control1: CGPoint(x: center.x + size * 0.18, y: center.y + size * 0.38),
                      control2: CGPoint(x: center.x + size * 0.55, y: center.y + size * 0.16))
        path.addCurve(to: CGPoint(x: center.x, y: center.y - size * 0.23),
                      control1: CGPoint(x: center.x + size * 0.52, y: center.y - size * 0.41),
                      control2: CGPoint(x: center.x + size * 0.22, y: center.y - size * 0.57))
        path.closeSubpath()
        return path
    }

    private func paperStar(center: CGPoint, radius: CGFloat, rotation: Double) -> Path {
        let vertices = (0..<10).map { point in
            let angle = (Double(point) * 36 - 90 + rotation) * .pi / 180
            let distance = point.isMultiple(of: 2) ? radius : radius * 0.57
            return CGPoint(x: center.x + CGFloat(cos(angle)) * distance,
                           y: center.y + CGFloat(sin(angle)) * distance)
        }
        var path = Path()
        // Round the tips slightly to preserve the original soft, plump print.
        for index in vertices.indices {
            let previous = vertices[(index + 9) % 10]
            let current = vertices[index]
            let next = vertices[(index + 1) % 10]
            let entry = CGPoint(x: current.x * 0.88 + previous.x * 0.12,
                                y: current.y * 0.88 + previous.y * 0.12)
            let exit = CGPoint(x: current.x * 0.88 + next.x * 0.12,
                               y: current.y * 0.88 + next.y * 0.12)
            if index == 0 { path.move(to: entry) } else { path.addLine(to: entry) }
            path.addQuadCurve(to: exit, control: current)
        }
        path.closeSubpath()
        return path
    }


}

/// Warm graphite surfaces, independent of the selected accent theme.
enum MemoryButtonColors {
    static let background = adaptive(light: rgb(75, 73, 70), dark: rgb(145, 142, 138))
    static let disabledBackground = adaptive(light: rgb(124, 121, 117), dark: rgb(113, 111, 108))
    static let topEdge = adaptive(light: rgb(252, 250, 247).opacity(0.20), dark: rgb(252, 250, 247).opacity(0.14))
}

struct ThemePalette {
    let accent: Color
    let selectionFill: Color
    let softHighlight: Color
    let strongAccent: Color
    let todayButtonFill: Color
    var onSelection: Color = .primary

    let background: Color
    let foreground: Color
    let onStrongAccent: Color
    let cardBackground: Color
    var isObsidian: Bool = false
}

extension ThemePalette {
    // Warm wood and neutral paper keep the retro collection understated.
    var collectionBackground: Color { adaptive(light: rgb(247, 245, 243), dark: rgb(29, 28, 31)) }
    var searchBackdrop: Color { adaptive(light: rgb(75, 68, 62), dark: rgb(16, 15, 17)) }
    var collectionWoodTop: Color { adaptive(light: rgb(137, 111, 92), dark: rgb(99, 80, 66)) }
    var collectionWoodHighlight: Color { adaptive(light: rgb(145, 119, 100), dark: rgb(106, 86, 71)) }
    var collectionWoodFace: Color { adaptive(light: rgb(120, 94, 77), dark: rgb(85, 67, 55)) }
    var collectionWoodEdge: Color { adaptive(light: rgb(113, 89, 73), dark: rgb(78, 62, 51)) }
    var collectionWoodGrain: Color { adaptive(light: rgb(66, 47, 36).opacity(0.24), dark: rgb(40, 29, 23).opacity(0.3)) }
    var collectionInk: Color { adaptive(light: rgb(53, 52, 58), dark: rgb(238, 233, 236)) }
    var collectionSecondaryInk: Color { adaptive(light: rgb(98, 96, 102), dark: rgb(194, 189, 194)) }
    var collectionTrackNumberInk: Color { adaptive(light: rgb(139, 101, 119), dark: rgb(207, 170, 188)) }
    var collectionWatchNumberInk: Color { adaptive(light: rgb(87, 114, 128), dark: rgb(159, 186, 198)) }
    var collectionNoteInk: Color { adaptive(light: rgb(77, 75, 81), dark: rgb(211, 206, 211)) }
    var collectionPaper: Color { adaptive(light: rgb(252, 252, 251), dark: rgb(39, 39, 40)) }
    var collectionSleeveTint: Color { adaptive(light: .white.opacity(0.08), dark: .white.opacity(0.025)) }
    var collectionShelfEdge: Color { collectionPaperEdge.opacity(0.65) }
    var collectionCaseBody: Color { adaptive(light: rgb(235, 236, 236), dark: rgb(48, 49, 50)) }
    var collectionCaseEdge: Color { adaptive(light: rgb(198, 200, 201), dark: rgb(105, 107, 109)) }
    var collectionCaseHighlight: Color { adaptive(light: .white.opacity(0.9), dark: rgb(201, 202, 204).opacity(0.4)) }
    var collectionPlayerScreen: Color { adaptive(light: rgb(239, 240, 237), dark: rgb(34, 36, 35)) }
    var collectionPlayerBar: Color { adaptive(light: rgb(226, 228, 225), dark: rgb(44, 47, 45)) }
    var collectionPlayerHighlight: Color { adaptive(light: rgb(212, 216, 212), dark: rgb(66, 71, 67)) }
    var collectionDiscBase: Color { adaptive(light: rgb(211, 213, 215), dark: rgb(97, 99, 102)) }
    var collectionBlackDisc: Color { adaptive(light: rgb(41, 39, 46), dark: rgb(36, 34, 41)) }
    var collectionMistVinyl: Color { adaptive(light: rgb(186, 199, 206), dark: rgb(120, 141, 155)) }
    var collectionMistVinylCloud: Color { adaptive(light: rgb(135, 154, 168), dark: rgb(82, 106, 124)) }
    var collectionMistVinylLight: Color { adaptive(light: rgb(232, 238, 240), dark: rgb(189, 205, 215)) }
    var collectionLaceVinyl: Color { adaptive(light: rgb(57, 50, 62), dark: rgb(73, 65, 79)) }
    var collectionLaceVinylPrint: Color { adaptive(light: rgb(184, 170, 169), dark: rgb(206, 190, 190)) }
    var collectionLaceVinylShade: Color { adaptive(light: rgb(40, 36, 46), dark: rgb(36, 31, 42)) }
    // var collectionTeaSmokeBase: Color { adaptive(light: rgb(175, 191, 169), dark: rgb(139, 159, 137)) }
    // var collectionTeaSmokeMilk: Color { adaptive(light: rgb(241, 235, 223), dark: rgb(215, 216, 201)) }
    // var collectionTeaSmokeDepth: Color { adaptive(light: rgb(127, 151, 127), dark: rgb(100, 125, 102)) }
    var collectionPeachSmokeBase: Color { adaptive(light: rgb(215, 183, 170), dark: rgb(175, 148, 142)) }
    var collectionPeachSmokeMilk: Color { adaptive(light: rgb(238, 229, 217), dark: rgb(213, 203, 193)) }
    var collectionPeachSmokeDepth: Color { adaptive(light: rgb(183, 155, 155), dark: rgb(139, 113, 119)) }
    var collectionTeaMarbleBase: Color { adaptive(light: rgb(168, 190, 147), dark: rgb(139, 161, 126)) }
    var collectionTeaMarbleMilk: Color { adaptive(light: rgb(240, 238, 221), dark: rgb(218, 220, 206)) }
    var collectionLightFilmBody: Color { adaptive(light: rgb(229, 228, 223), dark: rgb(185, 187, 189)) }
    var collectionLightFilmEdge: Color { adaptive(light: rgb(161, 164, 166), dark: rgb(207, 210, 211)) }
    var collectionLightFilmEtch: Color { adaptive(light: rgb(255, 254, 250), dark: rgb(231, 231, 225)) }
    var collectionLightFilmShade: Color { adaptive(light: rgb(124, 127, 129), dark: rgb(63, 64, 67)) }
    var collectionLightFilmLine: Color { adaptive(light: rgb(125, 127, 122), dark: rgb(238, 236, 228)) }
    var collectionLightFilmPeach: Color { adaptive(light: rgb(232, 197, 190), dark: rgb(207, 182, 181)) }
    var collectionLightFilmGreen: Color { adaptive(light: rgb(189, 203, 199), dark: rgb(172, 195, 188)) }
    var collectionLightFilmGelGradient: Gradient {
        Gradient(stops: [
            .init(color: collectionLightFilmEtch.opacity(0.28), location: 0),
            .init(color: collectionLightFilmBody.opacity(0.44), location: 0.5),
            .init(color: collectionLightFilmBody.opacity(0.3), location: 0.78),
            .init(color: collectionLightFilmEtch.opacity(0.2), location: 1)
        ])
    }
    var collectionFavoriteHeart: Color { adaptive(light: rgb(190, 70, 79), dark: rgb(225, 116, 124)) }
    var collectionSongSelectedRow: Color { adaptive(light: rgb(235, 229, 232), dark: rgb(59, 53, 57)) }
    var collectionWatchSelectedRow: Color { adaptive(light: rgb(229, 233, 235), dark: rgb(52, 57, 60)) }
    var collectionDiscLabelInk: Color { adaptive(light: rgb(239, 234, 225), dark: rgb(239, 234, 225)) }
    var collectionDiscPrint: Color { adaptive(light: rgb(166, 165, 171), dark: rgb(180, 179, 185)) }
    var collectionDiscGleam: Color { adaptive(light: rgb(248, 249, 250), dark: rgb(164, 167, 170)) }
    var collectionDiscShade: Color { adaptive(light: rgb(175, 179, 183), dark: rgb(65, 68, 71)) }
    var collectionDiscReflection: Color { adaptive(light: rgb(227, 228, 229), dark: rgb(126, 128, 131)) }
    var collectionRecordLabelPaper: Color { adaptive(light: rgb(216, 200, 206), dark: rgb(185, 167, 175)) }
    var collectionRecordLabelInk: Color { adaptive(light: rgb(57, 48, 55), dark: rgb(43, 35, 41)) }
    var collectionRecordLabelEdge: Color { adaptive(light: rgb(121, 101, 112).opacity(0.18), dark: rgb(84, 67, 78).opacity(0.22)) }
    var collectionProgrammePaper: Color { adaptive(light: rgb(240, 241, 242), dark: rgb(51, 53, 56)) }
    var collectionFilmSleeveSurface: Color { adaptive(light: rgb(222, 226, 230).opacity(0.42), dark: rgb(119, 127, 138).opacity(0.2)) }
    var collectionProgrammeHighlight: Color { adaptive(light: .white.opacity(0.72), dark: rgb(155, 162, 172).opacity(0.22)) }
    var collectionProgrammeEdge: Color { adaptive(light: rgb(142, 149, 158).opacity(0.18), dark: rgb(202, 208, 218).opacity(0.16)) }
    // Classic VHS materials: charcoal shell, smoky windows, ivory paper and a blue-gray label band.
// Collection skin customization is temporarily disabled.
//     var collectionRoseVinylBase: Color { adaptive(light: rgb(185, 128, 139), dark: rgb(176, 131, 144)) }
//     var collectionRoseVinylLight: Color { adaptive(light: rgb(226, 186, 192), dark: rgb(209, 171, 183)) }
//     var collectionRoseVinylDeep: Color { adaptive(light: rgb(135, 88, 99), dark: rgb(120, 85, 98)) }
//     var collectionRoseVinylEdge: Color { adaptive(light: rgb(117, 77, 89), dark: rgb(224, 187, 200)) }
//     var collectionSmokedVinyl: Color { adaptive(light: rgb(155, 143, 159), dark: rgb(142, 130, 149)) }
//     var collectionVinylCreamPaper: Color { adaptive(light: rgb(238, 230, 217), dark: rgb(216, 208, 197)) }
//     var collectionArchiveTapeShell: Color { adaptive(light: rgb(217, 210, 200), dark: rgb(170, 163, 156)) }
//     var collectionRentalPaper: Color { adaptive(light: rgb(232, 201, 125), dark: rgb(210, 181, 113)) }
//     var collectionRentalRed: Color { adaptive(light: rgb(142, 63, 54), dark: rgb(123, 52, 46)) }
//     var collectionRentalReel: Color { adaptive(light: rgb(191, 187, 177), dark: rgb(174, 171, 163)) }
    func tapeMaterial(for skin: CollectionWatchSkin) -> CollectionTapeMaterial {
        switch skin {
        case .clearWhite:
            CollectionTapeMaterial(
                shell: collectionLightFilmBody.opacity(0.12),
                bevel: collectionLightFilmEtch.opacity(0.22),
                edge: collectionLightFilmEdge,
                window: adaptive(light: rgb(210, 208, 206).opacity(0.1), dark: rgb(190, 187, 185).opacity(0.07)),
                pack: adaptive(light: rgb(108, 105, 104).opacity(0.34), dark: rgb(184, 181, 179).opacity(0.3)),
                hub: collectionLightFilmEtch.opacity(0.55),
                label: adaptive(light: rgb(253, 251, 248).opacity(0.64), dark: rgb(239, 236, 232).opacity(0.16)),
                ink: adaptive(light: rgb(64, 61, 60), dark: rgb(235, 231, 227)), grainOpacity: 0)
        case .original:
            CollectionTapeMaterial(shell: collectionTapeShell, bevel: collectionTapeBevel,
                                   edge: collectionTapeEdge, window: collectionTapeWindow,
                                   pack: collectionTapePack, hub: collectionTapeHub,
                                   label: collectionBackground, ink: collectionInk, grainOpacity: 0.23)
        }
    }

    var collectionClearTapeRibbon: Color { adaptive(light: rgb(60, 57, 59).opacity(0.88), dark: rgb(81, 76, 81).opacity(0.9)) }
    var collectionClearTapeHub: Color { adaptive(light: rgb(91, 86, 90), dark: rgb(112, 105, 112)) }
    var collectionClearTapeSpoke: Color { adaptive(light: rgb(75, 70, 74).opacity(0.72), dark: rgb(130, 121, 130).opacity(0.72)) }
    var collectionTapeShell: Color { adaptive(light: rgb(49, 46, 48), dark: rgb(43, 40, 43)) }
    var collectionTapeBevel: Color { adaptive(light: rgb(65, 61, 63), dark: rgb(59, 55, 59)) }
    var collectionTapeEdge: Color { adaptive(light: rgb(145, 137, 142), dark: rgb(157, 148, 155)) }
    var collectionTapeWindow: Color { adaptive(light: rgb(66, 63, 70), dark: rgb(60, 57, 64)) }
    var collectionTapePack: Color { adaptive(light: rgb(35, 32, 35), dark: rgb(31, 28, 32)) }
    var collectionTapeHub: Color { adaptive(light: rgb(174, 167, 166), dark: rgb(151, 145, 146)) }
    var collectionTapeLabel: Color { adaptive(light: rgb(233, 226, 223), dark: rgb(206, 199, 197)) }
    var collectionTapeLabelInk: Color { adaptive(light: rgb(34, 31, 34), dark: rgb(36, 33, 36)) }
    var collectionPhotoMount: Color { adaptive(light: rgb(248, 248, 247), dark: rgb(54, 54, 55)) }
    func photoPaper(for skin: CollectionPhotoSkin) -> Color {
        switch skin {
        case .original: collectionPhotoMount
        case .nightPrint: adaptive(light: rgb(55, 48, 52), dark: rgb(39, 34, 39))
        case .clearPlate: .clear
        }
    }
    var collectionPhotoNightEdge: Color { adaptive(light: rgb(136, 121, 130), dark: rgb(143, 129, 143)) }
    var collectionPhotoNightLip: Color { adaptive(light: rgb(76, 64, 71), dark: rgb(57, 47, 57)) }
    var collectionPhotoClearEdge: Color { collectionLightFilmEdge.opacity(0.48) }
    var collectionPhotoClearHighlight: Color { collectionLightFilmEtch.opacity(0.8) }
    var collectionPhotoClearShade: Color { adaptive(light: rgb(75, 82, 91).opacity(0.12), dark: .black.opacity(0.22)) }
    var collectionPaperEdge: Color { adaptive(light: rgb(116, 112, 120).opacity(0.22), dark: rgb(179, 170, 178).opacity(0.24)) }
    var collectionAlbumCover: Color { adaptive(light: rgb(211, 211, 209), dark: rgb(77, 77, 78)) }
    var collectionAlbumBinding: Color { adaptive(light: rgb(185, 188, 190), dark: rgb(153, 156, 158)) }
    var collectionShadow: Color { adaptive(light: rgb(53, 52, 58).opacity(0.08), dark: .black.opacity(0.16)) }

    var bookmarkHighlight: Color {
        if isObsidian {
            return adaptive(light: rgb(219, 217, 212), dark: rgb(177, 174, 167))
        }
        return tintedSurface(tint: accent, lightBase: (255, 253, 248), darkBase: (203, 198, 186),
                             lightWeight: 0.45, darkWeight: 0.45)
    }

    var bookmarkHighlightInk: Color {
        isObsidian ? rgb(49, 44, 42) : adaptive(light: foreground, dark: rgb(49, 44, 42))
    }

    var searchFieldBackground: Color {
        adaptive(light: rgb(244, 242, 239), dark: rgb(47, 45, 43))
    }

    var monthlyPlayerPaper: Color { adaptive(light: rgb(233, 234, 232), dark: rgb(65, 66, 65)) }
    var monthlyPlayer2Body: Color { adaptive(light: rgb(39, 40, 38), dark: rgb(32, 33, 31)) }
    var monthlyPlayer2Ink: Color { rgb(242, 242, 237) }
    var monthlyPlayerShellTint: Color { adaptive(light: rgb(216, 219, 216), dark: rgb(65, 66, 65)) }
    var monthlyPlayerShellHighlight: Color { adaptive(light: .white.opacity(0.65), dark: .white.opacity(0.19)) }
    var monthlyPlayerShellShade: Color { adaptive(light: .black.opacity(0.10), dark: .black.opacity(0.26)) }
    var monthlyPlayerShellShadow: Color { adaptive(light: .black.opacity(0.07), dark: .black.opacity(0.18)) }
    var monthlyPlayerWindow: Color { adaptive(light: rgb(245, 245, 241), dark: rgb(66, 67, 64)) }
    var monthlyPlayerInk: Color { adaptive(light: rgb(41, 43, 41), dark: rgb(232, 233, 228)) }
    var monthlyPlayerHeart: Color { adaptive(light: rgb(188, 67, 82), dark: rgb(226, 120, 133)) }

    var destructiveAction: Color {
        adaptive(light: rgb(158, 76, 79), dark: rgb(224, 150, 153))
    }

    var calendarWeekdayText: Color {
        tintedSurface(tint: strongAccent, lightBase: (112, 108, 105), darkBase: (180, 176, 172),
                      lightWeight: 0.55, darkWeight: 0.45)
    }

    var stampIndicator: Color { adaptive(light: rgb(97, 123, 96), dark: rgb(172, 192, 164)) }
    var stampWheelBackground: Color { adaptive(light: rgb(240, 238, 233), dark: rgb(34, 33, 30)) }

    var monthlyFlowerPaper: Color { adaptive(light: rgb(253, 243, 239), dark: rgb(49, 40, 40)) }
    var monthlyLacePaper: Color { adaptive(light: rgb(247, 245, 237), dark: rgb(58, 56, 51)) }
    var monthlyLaceThread: Color { adaptive(light: rgb(149, 146, 128), dark: rgb(164, 158, 139)) }
    var monthlyLaceTrim: Color { adaptive(light: rgb(255, 254, 248), dark: rgb(202, 197, 177)) }
    var monthlyLaceHem: Color { adaptive(light: rgb(250, 249, 239), dark: rgb(87, 83, 73)) }
    var monthlyLaceYarn: Color { adaptive(light: monthlyLaceTrim.opacity(0.45), dark: monthlyLaceTrim.opacity(0.14)) }
    var monthlyLaceButton: Color { adaptive(light: rgb(98, 85, 77), dark: rgb(53, 50, 46)) }
    var monthlyLaceButtonEdge: Color { adaptive(light: rgb(112, 105, 95), dark: rgb(127, 119, 107)) }
    var monthlyLaceButtonHole: Color { adaptive(light: rgb(34, 31, 28), dark: rgb(28, 26, 23)) }
    var monthlyLaceButtonStitch: Color { adaptive(light: rgb(235, 226, 213), dark: rgb(221, 212, 190)) }
    var monthlyTicketPaper: Color { adaptive(light: rgb(252, 250, 246), dark: rgb(43, 40, 38)) }
    var monthlyTicketInk: Color { foreground }
    var monthlyTicketStubInk: Color { adaptive(light: rgb(122, 48, 56), dark: rgb(211, 170, 176)) }
    var monthlyTicketRule: Color { foreground.opacity(0.35) }
    var monthlyClothBase: Color { adaptive(light: rgb(247, 241, 228), dark: rgb(49, 45, 39)) }
    var monthlyPolkaPaper: Color { adaptive(light: rgb(255, 252, 247), dark: rgb(45, 41, 39)) }
    var monthlyPolkaInks: [Color] {
        [adaptive(light: rgb(181, 133, 140), dark: rgb(195, 154, 160)),
         adaptive(light: rgb(179, 169, 127), dark: rgb(193, 184, 147)),
         adaptive(light: rgb(133, 156, 169), dark: rgb(151, 174, 186)),
         adaptive(light: rgb(156, 141, 166), dark: rgb(175, 161, 185))]
    }
    var monthlyClothCheck: Color { adaptive(light: rgb(183, 158, 125), dark: rgb(167, 144, 114)) }
    var monthlyClothStitch: Color { adaptive(light: rgb(150, 128, 101), dark: rgb(190, 170, 143)) }
//     var monthlyScreenPaper: Color { adaptive(light: rgb(236, 232, 240), dark: rgb(49, 42, 55)) }
//     var monthlyScreenBezel: Color { adaptive(light: rgb(244, 239, 231), dark: rgb(70, 61, 72)) }
//     var monthlyScreenInk: Color { adaptive(light: rgb(87, 70, 95), dark: rgb(222, 208, 229)) }
//     var monthlyScreenHighlight: Color { adaptive(light: rgb(255, 251, 245), dark: rgb(126, 109, 132)) }

    var memoBody: Color { adaptive(light: rgb(255, 252, 248), dark: rgb(43, 40, 38)) }

    var notebookCover: Color {
        tintedSurface(tint: accent, lightBase: (125, 116, 108), darkBase: (38, 35, 33),
                      lightWeight: 0.65, darkWeight: 0.28)
    }
    var notebookPageEdge: Color {
        adaptive(light: rgb(231, 225, 215), dark: rgb(58, 57, 52))
    }
    var notebookPaper: Color {
        if isObsidian { return adaptive(light: rgb(250, 247, 242), dark: rgb(32, 30, 29)) }
        return adaptive(light: rgb(255, 254, 252), dark: rgb(32, 34, 31))
    }

    // Warm ivory player shell, with the theme color reserved for its rim.
    var playerBody: Color {
        if isObsidian { return adaptive(light: rgb(46, 43, 45), dark: rgb(26, 23, 25)) }
        return adaptive(light: rgb(249, 248, 245), dark: rgb(53, 52, 49))
    }

    var playerBodyRim: Color {
        isObsidian ? .clear : adaptive(light: accent.opacity(0.47), dark: accent.opacity(0.40))
    }

    var televisionBody: Color {
        playerBody
    }

    var televisionBodyRim: Color {
        isObsidian ? Color.primary.opacity(0.09) : playerBodyRim
    }

    var televisionScreenBackground: Color {
        if isObsidian { return playerScreenBackground }
        return adaptive(light: rgb(235, 234, 231), dark: rgb(29, 28, 26))
    }

    var playerShellInk: Color { isObsidian ? rgb(235, 233, 230) : foreground }

    // Opaque so adding color to the shell cannot tint the screen through it.
    var playerScreenBackground: Color {
        adaptive(light: rgb(250, 247, 242), dark: rgb(32, 30, 29))
    }

    var musicPlayerScreenBackground: Color {
        if isObsidian { return playerScreenBackground }
        return adaptive(light: rgb(244, 243, 240), dark: rgb(34, 33, 31))
    }

    var playerWheelBackground: Color {
        if isObsidian { return adaptive(light: rgb(237, 236, 233), dark: rgb(59, 57, 56)) }
        return adaptive(light: rgb(237, 236, 233), dark: rgb(60, 58, 55))
    }

    var playerButtonTop: Color {
        adaptive(light: rgb(250, 247, 242), dark: rgb(70, 67, 66))
    }

    var playerButtonBottom: Color {
        adaptive(light: rgb(237, 236, 233), dark: rgb(52, 49, 48))
    }

    var playerScreenTopEdge: Color {
        adaptive(light: rgb(201, 197, 191), dark: rgb(24, 26, 23))
    }

    var playerScreenBottomEdge: Color {
        adaptive(light: rgb(243, 240, 235), dark: rgb(66, 69, 62))
    }

    static func make(accent: Color, selectionFill: Color, softHighlight: Color,
                     strongAccent: Color, todayButtonFill: Color,
                     onSelection: Color = .primary, isObsidian: Bool = false) -> ThemePalette {
        ThemePalette(
            accent: accent,
            selectionFill: adaptive(light: selectionFill, dark: accent.opacity(0.30)),
            softHighlight: adaptive(light: softHighlight, dark: rgb(54, 49, 47)),
            strongAccent: adaptive(light: strongAccent, dark: accent),
            todayButtonFill: todayButtonFill,
            onSelection: adaptive(light: onSelection, dark: rgb(247, 242, 236)),
            background: Color("AppBackground"),
            foreground: adaptive(light: rgb(49, 44, 42), dark: rgb(242, 237, 231)),
            onStrongAccent: rgb(252, 250, 247),
            cardBackground: adaptive(light: .white.opacity(0.72), dark: rgb(43, 40, 38)),
            isObsidian: isObsidian
        )
    }

    func resolved(for scheme: ColorScheme) -> ThemePalette {
        // Every color resolves against the window's actual interface style.
        self
    }
}

private func tintedSurface(tint: Color, lightBase: (Int, Int, Int), darkBase: (Int, Int, Int),
                           lightWeight: CGFloat, darkWeight: CGFloat) -> Color {
    let tintColor = UIColor(tint)
    return Color(uiColor: UIColor { traits in
        let isDark = traits.userInterfaceStyle == .dark
        let base = isDark ? darkBase : lightBase
        let weight = isDark ? darkWeight : lightWeight
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        tintColor.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(
            red: CGFloat(base.0) / 255 * (1 - weight) + red * weight,
            green: CGFloat(base.1) / 255 * (1 - weight) + green * weight,
            blue: CGFloat(base.2) / 255 * (1 - weight) + blue * weight,
            alpha: 1
        )
    })
}

private func adaptive(light: Color, dark: Color) -> Color {
    let lightColor = UIColor(light)
    let darkColor = UIColor(dark)
    return Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? darkColor : lightColor
    })
}

private func rgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
    Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .pink
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

enum SelectionShape: String, CaseIterable, Identifiable {
    case circle, star, sakura, leaf, cat, heart

    var requiresMembership: Bool {
        switch self {
        case .circle, .star, .sakura: false
        case .leaf, .cat, .heart: true
        }
    }

    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: localized("圆形")
        case .heart: localized("爱心")
        case .star: localized("星星")
        case .sakura: localized("樱花")
        case .leaf: localized("叶子")
        case .cat: localized("猫猫")
        }
    }

    var systemName: String {
        switch self {
        case .circle: "circle.fill"
        case .heart: "heart.fill"
        case .star: "star.fill"
        case .sakura: "camera.macro"
        case .leaf: "leaf.fill"
        case .cat: "cat.fill"
        }
    }
}

struct SelectionShapeIcon: View {
    let shape: SelectionShape
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            if shape == .star {
                WideCenterStar()
                    .fill(color)
            } else if shape == .sakura {
                SakuraFlower()
                    .fill(color)
            } else if shape == .leaf {
                ZStack {
                    LeafShape()
                        .fill(color)
                    LeafVein()
                        .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: max(1, size / 24), lineCap: .round))
                }
            } else if shape == .cat {
                Image("selectionCat")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                Image(systemName: shape.systemName)
                    .font(.system(size: size))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct WideCenterStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.58
        var path = Path()

        for pointIndex in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(pointIndex) * .pi / 5
            let radius = pointIndex.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct SakuraFlower: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let petalAngle = 2 * CGFloat.pi / 5
        var path = Path()

        for petalIndex in 0..<5 {
            let angle = -CGFloat.pi / 2 + CGFloat(petalIndex) * petalAngle
            let start = point(center: center, radius: radius * 0.46, angle: angle - petalAngle / 2)
            let notch = point(center: center, radius: radius * 0.78, angle: angle)
            let end = point(center: center, radius: radius * 0.46, angle: angle + petalAngle / 2)
            let leftLobe = point(center: center, radius: radius, angle: angle - petalAngle * 0.18)
            let rightLobe = point(center: center, radius: radius, angle: angle + petalAngle * 0.18)

            if petalIndex == 0 {
                path.move(to: start)
            }
            path.addQuadCurve(to: notch, control: leftLobe)
            path.addQuadCurve(to: end, control: rightLobe)
        }

        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.86, y: h * 0.14))
        path.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.66),
                      control1: CGPoint(x: w * 0.55, y: h * 0.02),
                      control2: CGPoint(x: w * 0.06, y: h * 0.34))
        path.addCurve(to: CGPoint(x: w * 0.39, y: h * 0.86),
                      control1: CGPoint(x: w * 0.20, y: h * 0.84),
                      control2: CGPoint(x: w * 0.30, y: h * 0.88))
        path.addCurve(to: CGPoint(x: w * 0.86, y: h * 0.14),
                      control1: CGPoint(x: w * 0.68, y: h * 0.84),
                      control2: CGPoint(x: w * 0.90, y: h * 0.48))
        path.closeSubpath()
        return path
    }
}

private struct LeafVein: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.73))
        path.addCurve(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.20),
                      control1: CGPoint(x: rect.width * 0.40, y: rect.height * 0.61),
                      control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.36))
        return path
    }
}

private struct SelectionShapeKey: EnvironmentKey {
    static let defaultValue: SelectionShape = .circle
}

extension EnvironmentValues {
    var selectionShape: SelectionShape {
        get { self[SelectionShapeKey.self] }
        set { self[SelectionShapeKey.self] = newValue }
    }
}

extension DailyChoice {
    /// Balances the visible subject inside each weather asset's transparent canvas.
    var weatherArtworkScale: CGFloat? {
        switch self {
        case .rainbow: 1.18
        case .sunshine: 1.34
        case .rain: 1.36
        case .snow: 1.30
        case .wind: 1.14
        default: nil
        }
    }
}

/// Keeps the supplied artwork intact and adapts monochrome groups to dark backgrounds.
struct ChoiceArtwork: View {
    @Environment(\.colorScheme) private var colorScheme
    private let imageName: String
    private let group: ChoiceGroup

    init(choice: DailyChoice) {
        imageName = choice.imageName
        group = choice.group
    }

    init(mood: Mood) {
        imageName = mood.imageName
        group = .mood
    }

    var body: some View {
        let artwork = Image(imageName)
        if colorScheme == .dark && group == .rabbit {
            // Preserve the dark strokes as white and drop the light fill from the mask.
            artwork
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .colorInvert()
                .contrast(2)
                .background(.black)
                .compositingGroup()
                .luminanceToAlpha()
                .colorInvert()
        } else {
            let usesWhiteLines = colorScheme == .dark && group != .playful && group != .everyday && group != .weather
            artwork
                .renderingMode(usesWhiteLines ? .template : .original)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        }
    }

}
