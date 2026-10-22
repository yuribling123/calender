import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case black, pink, apricot, sage, blue, lavender, caramel, creamYellow

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
    case original, pink, apricot, yellow, green, blue, purple, caramel, black

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
        }
        return localized(key)
    }

    private var matchingTheme: AppTheme {
        switch self {
        case .original, .pink: .pink
        case .apricot: .apricot
        case .yellow: .creamYellow
        case .green: .sage
        case .blue: .blue
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
            background: adaptive(light: rgb(252, 250, 247), dark: rgb(29, 28, 27)),
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
    case circle, star, heart, sakura, leaf, cat

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
        let usesWhiteLines = colorScheme == .dark && group != .playful && group != .rabbit
        Image(imageName)
            .renderingMode(usesWhiteLines ? .template : .original)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
    }
}
