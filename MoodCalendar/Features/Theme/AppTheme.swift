import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case pink, black, apricot, sage, blue, lavender, caramel, creamYellow

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
    case circle, heart, star, sakura, leaf, cat

    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: "圆形"
        case .heart: "爱心"
        case .star: "星星"
        case .sakura: "樱花"
        case .leaf: "叶子"
        case .cat: "猫猫"
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
