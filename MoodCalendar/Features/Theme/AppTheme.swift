import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case pink, apricot, sage, blue, lavender, caramel, creamYellow, black

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pink: "樱粉"
        case .apricot: "暖杏"
        case .sage: "鼠尾草绿"
        case .blue: "雾蓝"
        case .lavender: "淡紫"
        case .caramel: "焦糖棕"
        case .creamYellow: "奶油黄"
        case .black: "黑色"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .pink:
            ThemePalette(accent: rgb(242, 141, 178), selectionFill: rgb(249, 211, 226),
                         softHighlight: rgb(253, 234, 242),
                         strongAccent: rgb(176, 69, 102))
        case .apricot:
            ThemePalette(accent: rgb(241, 165, 126), selectionFill: rgb(250, 221, 202),
                         softHighlight: rgb(252, 238, 227),
                         strongAccent: rgb(150, 82, 48))
        case .sage:
            ThemePalette(accent: rgb(155, 188, 158), selectionFill: rgb(216, 235, 215),
                         softHighlight: rgb(234, 243, 232),
                         strongAccent: rgb(71, 112, 77))
        case .blue:
            ThemePalette(accent: rgb(142, 179, 207), selectionFill: rgb(211, 229, 242),
                         softHighlight: rgb(233, 242, 248),
                         strongAccent: rgb(63, 105, 139))
        case .lavender:
            ThemePalette(accent: rgb(177, 159, 203), selectionFill: rgb(231, 219, 242),
                         softHighlight: rgb(242, 235, 248),
                         strongAccent: rgb(101, 77, 134))
        case .caramel:
            ThemePalette(accent: rgb(185, 130, 91), selectionFill: rgb(235, 216, 198),
                         softHighlight: rgb(246, 237, 226),
                         strongAccent: rgb(112, 72, 43))
        case .creamYellow:
            ThemePalette(accent: rgb(232, 197, 106), selectionFill: rgb(247, 235, 194),
                         softHighlight: rgb(251, 246, 227),
                         strongAccent: rgb(119, 91, 34))
        case .black:
            ThemePalette(accent: rgb(38, 38, 38), selectionFill: rgb(38, 38, 38),
                         softHighlight: rgb(236, 234, 231), strongAccent: rgb(38, 38, 38),
                         onSelection: rgb(252, 250, 247))
        }
    }
}

struct ThemePalette {
    let accent: Color
    let selectionFill: Color
    let softHighlight: Color
    let strongAccent: Color
    var onSelection: Color = .primary

    let background = rgb(252, 250, 247)
    let onStrongAccent = rgb(252, 250, 247)
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
    case heart, circle

    var id: String { rawValue }
    var title: String { self == .heart ? "爱心" : "圆形" }
    var systemName: String { self == .heart ? "heart.fill" : "circle.fill" }
}

private struct SelectionShapeKey: EnvironmentKey {
    static let defaultValue: SelectionShape = .heart
}

extension EnvironmentValues {
    var selectionShape: SelectionShape {
        get { self[SelectionShapeKey.self] }
        set { self[SelectionShapeKey.self] = newValue }
    }
}
