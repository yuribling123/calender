import SwiftUI
import UIKit

struct MonthlyNoteSurface<Content: View>: View {
    let skin: MonthlyNoteSkin
    var monthLabel: String = "MONTHLY NOTE"
    var ticketNumber: String = ""
    var showsPlainBorder: Bool = true
    @ViewBuilder var content: () -> Content
    @ScaledMetric(relativeTo: .subheadline) private var minimumContentHeight: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var playerNoteFontSize: CGFloat = 14
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Keep the single-line inset when the note grows to multiple lines.
    private var playerNoteVerticalInset: CGFloat {
        max(0, (minimumContentHeight - UIFont.systemFont(ofSize: playerNoteFontSize).lineHeight) / 2)
    }

    var body: some View {
        if skin == .ticket {
            content()
                .frame(maxWidth: .infinity, minHeight: minimumContentHeight, alignment: .leading)
                .foregroundStyle(theme.palette.foreground)
                .padding(.vertical, 24)
                .padding(.leading, 24)
                .padding(.trailing, 18 + MovieTicketShape.stubWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottomLeading) {
                    Text(verbatim: "NO. \(ticketNumber)")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(theme.palette.monthlyTicketInk.opacity(0.6))
                        .padding(.leading, 24)
                        .padding(.bottom, 6)
                }
                .overlay(alignment: .trailing) {
                    Text(localized("留作纪念"))
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(theme.palette.monthlyTicketStubInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 88)
                        .rotationEffect(.degrees(90))
                        .frame(width: MovieTicketShape.stubWidth)
                        .accessibilityHidden(true)
                }
                .accessibilityValue(monthLabel)
                .background { MovieTicketBackground() }
        }
        else if skin == .player2 {
            VStack(alignment: .leading, spacing: 8) {
                content()
                    .foregroundStyle(theme.palette.monthlyPlayer2Ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, playerNoteVerticalInset)
                    .frame(maxWidth: .infinity, minHeight: minimumContentHeight, alignment: .leading)

                HStack {
                    Image(systemName: "heart")
                    Spacer()
                    Image(systemName: "backward.end.fill")
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 17))
                    Spacer()
                    Image(systemName: "forward.end.fill")
                    Spacer()
                    Image(systemName: "plus")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.palette.monthlyPlayer2Ink)
                .frame(height: 26)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 5)
            .padding(.bottom, 9)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(theme.palette.monthlyPlayer2Body.opacity(reduceTransparency ? 1 : 0.86))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.75)
                    }
            }
        }
        else if skin == .player {
            VStack(alignment: .leading, spacing: 4) {
                content()
                    .foregroundStyle(theme.palette.monthlyPlayerInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, playerNoteVerticalInset)
                    .frame(maxWidth: .infinity, minHeight: minimumContentHeight, alignment: .leading)


                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.palette.monthlyPlayerInk.opacity(0.28))
                                .frame(height: 1.5)
                            Capsule().fill(theme.palette.monthlyPlayerInk)
                                .frame(width: geometry.size.width * 0.18, height: 1.5)
                            Circle().fill(theme.palette.monthlyPlayerInk)
                                .frame(width: 4, height: 4)
                                .offset(x: max(0, geometry.size.width * 0.18 - 2))
                        }
                        .frame(height: 5)
                    }
                    .frame(height: 5)

                    HStack(spacing: 16) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 10))
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 10))
                            ZStack {
                                Circle().fill(theme.palette.monthlyPlayerInk)
                                HStack(spacing: 2.5) {
                                    RoundedRectangle(cornerRadius: 0.6)
                                    RoundedRectangle(cornerRadius: 0.6)
                                }
                                .foregroundStyle(theme.palette.monthlyPlayerPaper)
                                .frame(width: 7, height: 10)
                            }
                            .frame(width: 22, height: 22)
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 10))
                            Image(systemName: "music.note.list")
                                .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.palette.monthlyPlayerInk)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 5)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.palette.monthlyPlayerShellTint.opacity(reduceTransparency ? 1 : 0.36))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [theme.palette.monthlyPlayerShellHighlight.opacity(0.22), .clear, theme.palette.monthlyPlayerShellShade.opacity(0.32)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(EllipticalGradient(
                                stops: [
                                    .init(color: theme.palette.monthlyPlayerShellHighlight.opacity(0.12), location: 0),
                                    .init(color: .clear, location: 0.65),
                                    .init(color: theme.palette.monthlyPlayerShellShade.opacity(0.28), location: 1)
                                ],
                                center: .center,
                                startRadiusFraction: 0,
                                endRadiusFraction: 0.7
                            ))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(LinearGradient(colors: [theme.palette.monthlyPlayerShellHighlight.opacity(0.85), theme.palette.monthlyPlayerShellHighlight.opacity(0.15), theme.palette.monthlyPlayerShellShade.opacity(0.8)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.palette.monthlyPlayerShellHighlight.opacity(0.15), lineWidth: 0.5)
                            .padding(2)
                    }
                    .shadow(color: theme.palette.monthlyPlayerShellShadow.opacity(0.5), radius: 4, x: 0, y: 2)
            }
        }
        /* 复古屏幕暂时停用，保留原布局供参考。
        else if skin == .screen {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    ScreenPixelArt(symbol: .signal)
                        .frame(width: 28, alignment: .leading)
                    Spacer()
                    ScreenPixelArt(symbol: .envelope)
                    Spacer()
                    ScreenPixelArt(symbol: .heart)
                        .frame(width: 28, alignment: .trailing)
                }
                .accessibilityHidden(true)

                content()

                HStack(alignment: .bottom, spacing: 8) {
                    Spacer(minLength: 0)
                    ScreenPixelArt(symbol: .sparkle, pixelSize: 1)
                        .padding(.bottom, 19)
                    ScreenPixelArt(symbol: .butterfly)
                }
                .accessibilityHidden(true)
            }
            .foregroundStyle(theme.palette.monthlyScreenInk)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { FlipPhoneNoteBackground() }
        }
        */
        else {
            content()
                // One- and two-line notes share a paper size; longer notes grow naturally.
                // Expand the text area before adding the same inset on every edge.
                .frame(maxWidth: .infinity, minHeight: minimumContentHeight, alignment: .leading)
                .padding(24)
                .background {
                    if skin != .plain || showsPlainBorder {
                        MonthlyNoteSkinBackground(skin: skin, monthLabel: monthLabel)
                    }
                }
        }
    }
}

// A tiny printed MiniDisc emblem, kept separate from the lyric window.
private struct MDDiscMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for scale: CGFloat in [0.44, 0.25] {
            path.addArc(center: center, radius: min(rect.width, rect.height) * scale,
                        startAngle: .degrees(35), endAngle: .degrees(325), clockwise: false)
        }
        path.move(to: CGPoint(x: rect.width * 0.71, y: rect.height * 0.43))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.43))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.64))
        return path
    }
}

// Small original print marks, drawn in normalized coordinates for a consistent weight.
private struct MDPrintedSymbol: Shape {
    enum Symbol { case play, shuffle, list, heart }
    let symbol: Symbol

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch symbol {
        case .play:
            p.move(to: CGPoint(x: 0.12, y: 0.06))
            p.addQuadCurve(to: CGPoint(x: 0.23, y: 0.03), control: CGPoint(x: 0.12, y: 0))
            p.addLine(to: CGPoint(x: 0.91, y: 0.45))
            p.addQuadCurve(to: CGPoint(x: 0.91, y: 0.55), control: CGPoint(x: 1, y: 0.5))
            p.addLine(to: CGPoint(x: 0.23, y: 0.97))
            p.addQuadCurve(to: CGPoint(x: 0.12, y: 0.94), control: CGPoint(x: 0.12, y: 1))
            p.closeSubpath()
        case .shuffle:
            p.move(to: CGPoint(x: 0.04, y: 0.18))
            p.addCurve(to: CGPoint(x: 0.93, y: 0.82), control1: CGPoint(x: 0.48, y: 0.18), control2: CGPoint(x: 0.48, y: 0.82))
            p.move(to: CGPoint(x: 0.04, y: 0.82))
            p.addCurve(to: CGPoint(x: 0.93, y: 0.18), control1: CGPoint(x: 0.48, y: 0.82), control2: CGPoint(x: 0.48, y: 0.18))
            for y: CGFloat in [0.18, 0.82] {
                p.move(to: CGPoint(x: 0.76, y: y - 0.15))
                p.addLine(to: CGPoint(x: 0.94, y: y))
                p.addLine(to: CGPoint(x: 0.76, y: y + 0.15))
            }
        case .list:
            for y: CGFloat in [0.15, 0.45, 0.75] {
                p.move(to: CGPoint(x: 0.02, y: y))
                p.addLine(to: CGPoint(x: 0.48, y: y))
            }
            p.move(to: CGPoint(x: 0.85, y: 0.7))
            p.addLine(to: CGPoint(x: 0.85, y: 0.08))
            p.addLine(to: CGPoint(x: 1, y: 0.03))
            p.addEllipse(in: CGRect(x: 0.64, y: 0.68, width: 0.21, height: 0.23))
        case .heart:
            p.move(to: CGPoint(x: 0.48, y: 0.96))
            p.addCurve(to: CGPoint(x: 0.04, y: 0.3), control1: CGPoint(x: 0.34, y: 0.8), control2: CGPoint(x: -0.02, y: 0.55))
            p.addCurve(to: CGPoint(x: 0.48, y: 0.2), control1: CGPoint(x: 0.06, y: 0.01), control2: CGPoint(x: 0.34, y: -0.02))
            p.addCurve(to: CGPoint(x: 0.97, y: 0.28), control1: CGPoint(x: 0.69, y: -0.06), control2: CGPoint(x: 0.98, y: 0.04))
            p.addCurve(to: CGPoint(x: 0.48, y: 0.96), control1: CGPoint(x: 1.03, y: 0.53), control2: CGPoint(x: 0.65, y: 0.83))
            p.closeSubpath()
        }
        return p.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}

private struct MonthlyNoteSkinBackground: View {
    let skin: MonthlyNoteSkin
    let monthLabel: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        let palette = theme.palette
        let edge = palette.foreground.opacity(0.15)
        switch skin {
        case .plain:
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(edge, lineWidth: 0.7)
        case .lace:
            LaceNoteBackground()
        case .ticket:
            MovieTicketBackground()
        case .player:
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.monthlyPlayerPaper)
        case .player2:
            RoundedRectangle(cornerRadius: 28)
                .fill(palette.monthlyPlayer2Body)
        case .grid:
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.memoBody)
                .overlay {
                    Canvas { context, size in
                        var path = Path()
                        for x in stride(from: CGFloat(0), through: size.width, by: 18) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: CGFloat(0), through: size.height, by: 18) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(palette.strongAccent.opacity(0.13)), lineWidth: 0.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(edge, lineWidth: 0.5) }
        // case .screen:
        //     FlipPhoneNoteBackground()
        case .tablecloth:
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.monthlyClothBase)
                .overlay {
                    Canvas { context, size in
                        // Separate passes let the gingham intersections deepen naturally.
                        var warpChecks = Path()
                        for x in stride(from: CGFloat(0), through: size.width, by: 24) {
                            warpChecks.addRect(CGRect(x: x, y: 0, width: 12, height: size.height))
                        }
                        context.fill(warpChecks, with: .color(palette.monthlyClothCheck.opacity(0.12)))

                        var weftChecks = Path()
                        for y in stride(from: CGFloat(0), through: size.height, by: 24) {
                            weftChecks.addRect(CGRect(x: 0, y: y, width: size.width, height: 12))
                        }
                        context.fill(weftChecks, with: .color(palette.monthlyClothCheck.opacity(0.12)))

                        // Fine, quiet threads add cloth texture beneath the note text.
                        var threads = Path()
                        for x in stride(from: CGFloat(1), through: size.width, by: 3) {
                            threads.move(to: CGPoint(x: x, y: 0))
                            threads.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: CGFloat(1), through: size.height, by: 3) {
                            threads.move(to: CGPoint(x: 0, y: y))
                            threads.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(threads, with: .color(palette.monthlyClothStitch.opacity(0.045)),
                                       lineWidth: 0.35)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(palette.monthlyClothStitch.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 0.7, dash: [3, 3]))
                        .padding(7)
                }
                .opacity(0.9)
        }
    }
}

/* 复古屏幕背景与像素装饰，暂时停用。
private struct FlipPhoneNoteBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        let palette = theme.palette
        RoundedRectangle(cornerRadius: 9)
            .fill(palette.monthlyScreenBezel)
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(palette.monthlyScreenInk.opacity(0.16), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .fill(palette.monthlyScreenPaper)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(palette.monthlyScreenInk.opacity(0.22), lineWidth: 1)
                    }
                    .padding(4)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// All screen ornaments share a square pixel grid, including the butterfly.
private struct ScreenPixelArt: View {
    enum Symbol {
        case signal, envelope, heart, butterfly, sparkle

        var rows: [String] {
            switch self {
            case .signal:
                return [
                    "000000000010",
                    "000000000010",
                    "000000010010",
                    "000000010010",
                    "000010010010",
                    "000010010010",
                    "010010010010",
                    "010010010010"
                ]
            case .envelope:
                return [
                    "1111111111111",
                    "1100000000011",
                    "1010000000101",
                    "1001000001001",
                    "1000111110001",
                    "1001000001001",
                    "1010000000101",
                    "1111111111111"
                ]
            case .heart:
                return [
                    "01100110",
                    "11111111",
                    "11111111",
                    "11111111",
                    "01111110",
                    "00111100",
                    "00011000"
                ]
            case .butterfly:
                return [
                    "000000100010000000",
                    "011000010100001110",
                    "100110001000110010",
                    "100001101011000010",
                    "010000111110000100",
                    "001000011100001000",
                    "000111111111110000",
                    "000100011100010000",
                    "001000111110001000",
                    "001001001001001000",
                    "000110001000110000",
                    "000000001000000000"
                ]
            case .sparkle:
                return [
                    "0001000",
                    "0001000",
                    "0011100",
                    "1111111",
                    "0011100",
                    "0001000",
                    "0001000"
                ]
            }
        }
    }

    let symbol: Symbol
    var pixelSize: CGFloat = 2

    var body: some View {
        let rows = symbol.rows
        ScreenPixelShape(rows: rows, pixelSize: pixelSize)
            .fill(style: FillStyle(antialiased: false))
            .frame(width: CGFloat(rows.first?.count ?? 0) * pixelSize,
                   height: CGFloat(rows.count) * pixelSize)
    }
}

private struct ScreenPixelShape: Shape {
    let rows: [String]
    let pixelSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "1" {
                path.addRect(CGRect(x: rect.minX + CGFloat(x) * pixelSize,
                                    y: rect.minY + CGFloat(y) * pixelSize,
                                    width: pixelSize, height: pixelSize))
            }
        }
        return path
    }
}

*/

private struct MovieTicketBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette
        MovieTicketShape()
            .fill(palette.monthlyTicketPaper)
            .shadow(color: palette.monthlyTicketInk.opacity(colorScheme == .dark ? 0 : 0.04),
                    radius: 1.5, x: 0, y: 1)
            .overlay {
                Canvas { context, size in
                    var fibers = Path()
                    for y in stride(from: CGFloat(3), through: size.height, by: 5) {
                        fibers.move(to: CGPoint(x: 0, y: y))
                        fibers.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(fibers, with: .color(palette.monthlyTicketInk.opacity(0.025)), lineWidth: 0.5)
                    var tear = Path()
                    tear.move(to: CGPoint(x: size.width - MovieTicketShape.stubWidth, y: 10))
                    tear.addLine(to: CGPoint(x: size.width - MovieTicketShape.stubWidth, y: size.height - 10))
                    context.stroke(tear, with: .color(palette.monthlyTicketRule.opacity(0.65)),
                                   style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1, 3]))
                }
                .clipShape(MovieTicketShape())
            }
            .overlay { MovieTicketShape().stroke(palette.monthlyTicketRule.opacity(0.4), lineWidth: 0.6) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct MovieTicketShape: Shape {
    static let stubWidth: CGFloat = 56

    func path(in bounds: CGRect) -> Path {
        guard bounds.width > 90, bounds.height > 0 else {
            return Path(roundedRect: bounds, cornerRadius: 4)
        }
        // Draw the ticket vertically, then turn it so the perforations sit on the short ends.
        let rect = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
        let r = rect.insetBy(dx: 1, dy: 1)
        guard r.width > 0, r.height > 70 else { return Path(roundedRect: rect, cornerRadius: 4) }
        let count = max(1, Int(r.width / 20))
        let step = r.width / CGFloat(count)
        let radius = min(CGFloat(4), step / 4)
        let tearY = rect.maxY - Self.stubWidth
        let notch: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        for index in 0..<count {
            let center = r.minX + (CGFloat(index) + 0.5) * step
            path.addLine(to: CGPoint(x: center - radius, y: r.minY))
            path.addCurve(to: CGPoint(x: center, y: r.minY + radius),
                          control1: CGPoint(x: center - radius, y: r.minY + radius * 0.5523),
                          control2: CGPoint(x: center - radius * 0.5523, y: r.minY + radius))
            path.addCurve(to: CGPoint(x: center + radius, y: r.minY),
                          control1: CGPoint(x: center + radius * 0.5523, y: r.minY + radius),
                          control2: CGPoint(x: center + radius, y: r.minY + radius * 0.5523))
        }
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: tearY - notch))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: tearY + notch),
                          control: CGPoint(x: r.maxX - notch * 2, y: tearY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        for index in 0..<count {
            let center = r.maxX - (CGFloat(index) + 0.5) * step
            path.addLine(to: CGPoint(x: center + radius, y: r.maxY))
            path.addCurve(to: CGPoint(x: center, y: r.maxY - radius),
                          control1: CGPoint(x: center + radius, y: r.maxY - radius * 0.5523),
                          control2: CGPoint(x: center + radius * 0.5523, y: r.maxY - radius))
            path.addCurve(to: CGPoint(x: center - radius, y: r.maxY),
                          control1: CGPoint(x: center - radius * 0.5523, y: r.maxY - radius),
                          control2: CGPoint(x: center - radius, y: r.maxY - radius * 0.5523))
        }
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: tearY + notch))
        path.addQuadCurve(to: CGPoint(x: r.minX, y: tearY - notch),
                          control: CGPoint(x: r.minX + notch * 2, y: tearY))
        path.closeSubpath()
        return path.applying(CGAffineTransform(a: 0, b: -1, c: 1, d: 0,
                                              tx: bounds.minX, ty: bounds.maxY))
    }
}

private struct LaceNoteBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        let palette = theme.palette
        ScallopedNoteShape()
            .fill(palette.monthlyLacePaper)
            .overlay {
                Canvas { context, size in
                    let bounds = CGRect(origin: .zero, size: size)
                    let geometry = LaceNoteGeometry(bounds: bounds)
                    let field = geometry.innerFrame
                    guard field.width > 0, field.height > 0 else { return }
                    // Fine, regular warp and weft continue across the whole cloth.
                    var weave = Path()
                    for x in stride(from: CGFloat(0), through: size.width, by: 2.8) {
                        weave.move(to: CGPoint(x: x, y: 0))
                        weave.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), through: size.height, by: 2.8) {
                        weave.move(to: CGPoint(x: 0, y: y))
                        weave.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(weave, with: .color(palette.monthlyLaceThread.opacity(0.05)), lineWidth: 0.45)
                    context.stroke(Path(roundedRect: field, cornerRadius: 9 * geometry.scale),
                                   with: .color(palette.monthlyLaceTrim), lineWidth: geometry.scale)

                    // Each three-petal sprig shares its center with one edge scallop.
                    // Coordinates below follow the 524-point-wide reference artwork.
                    var sprig = Path()
                    sprig.move(to: CGPoint(x: 0, y: 5))
                    sprig.addLine(to: CGPoint(x: 0, y: -5))
                    for side in [CGFloat(-1), CGFloat(1)] {
                        sprig.move(to: CGPoint(x: 0, y: 4))
                        sprig.addCurve(to: CGPoint(x: side * 4.5, y: -3),
                                       control1: CGPoint(x: side * 5, y: 4),
                                       control2: CGPoint(x: side * 5.5, y: 0))
                        sprig.addQuadCurve(to: CGPoint(x: 0, y: 4),
                                          control: CGPoint(x: side * 0.5, y: -2))
                    }
                    sprig.move(to: CGPoint(x: 0, y: 1))
                    sprig.addQuadCurve(to: CGPoint(x: 0, y: -5), control: CGPoint(x: -3, y: -2))
                    sprig.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 3, y: -2))
                    for vertical in [false, true] {
                        let centers = vertical ? geometry.verticalCenters : geometry.horizontalCenters
                        for center in centers {
                            for opposite in [false, true] {
                                var embroidery = context
                                let margin = 11 * geometry.scale
                                embroidery.translateBy(
                                    x: vertical ? (opposite ? bounds.maxX - margin : bounds.minX + margin) : center,
                                    y: vertical ? center : (opposite ? bounds.maxY - margin : bounds.minY + margin)
                                )
                                embroidery.rotate(by: .degrees(vertical ? (opposite ? 90 : -90) : (opposite ? 180 : 0)))
                                embroidery.scaleBy(x: geometry.scale, y: geometry.scale)
                                embroidery.stroke(sprig, with: .color(palette.monthlyLaceTrim),
                                                  style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                }
                .clipShape(ScallopedNoteShape())
            }
            .overlay {
                ScallopedNoteShape()
                    .stroke(palette.monthlyLaceThread.opacity(0.12), lineWidth: 0.6)
            }
            .shadow(color: palette.monthlyLaceThread.opacity(0.16), radius: 1, x: 0, y: 1)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(palette.monthlyLaceButton)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [palette.monthlyLaceButtonEdge.opacity(0.65),
                                             palette.monthlyLaceButtonEdge.opacity(0.12),
                                             palette.monthlyLaceButtonHole.opacity(0.55)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 0.8
                            )
                            .padding(2.5)
                    }
                    .overlay {
                        ZStack {
                            HStack(spacing: 4) {
                                Circle().frame(width: 3, height: 3)
                                Circle().frame(width: 3, height: 3)
                            }
                            .foregroundStyle(palette.monthlyLaceButtonHole)
                            // Two short stitches pass through the inset holes.
                            VStack(spacing: 0.6) {
                                Capsule().frame(width: 7, height: 0.7)
                                Capsule().frame(width: 7, height: 0.7)
                            }
                            .foregroundStyle(palette.monthlyLaceButtonStitch)
                        }
                    }
                    .frame(width: 23, height: 23)
                    .shadow(color: palette.monthlyLaceButtonHole.opacity(0.2), radius: 0.8, x: 0, y: 1)
                    .rotationEffect(.degrees(-12))
                    .padding(.top, 10)
                    .padding(.trailing, 13)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// Shared measurements keep the embroidered flowers centered on the cloth's lobes
// at both the compact picker size and the full monthly-note size.
private struct LaceNoteGeometry {
    let bounds: CGRect

    var scale: CGFloat { bounds.width / 524 }
    var innerFrame: CGRect { bounds.insetBy(dx: 16 * scale, dy: 16 * scale) }
    var edge: CGRect { bounds.insetBy(dx: 0.5, dy: 0.5) }
    var corner: CGFloat { min(39 * scale, min(edge.width, edge.height) / 2) }
    var depth: CGFloat { 4 * scale }
    var horizontalCount: Int { max(1, Int(((edge.width - 2 * corner) / (35 * scale)).rounded())) }
    var verticalCount: Int { max(1, Int(((edge.height - 2 * corner) / (35 * scale)).rounded())) }
    var horizontalCenters: [CGFloat] {
        (0..<horizontalCount).map {
            edge.minX + corner + (CGFloat($0) + 0.5) * (edge.width - 2 * corner) / CGFloat(horizontalCount)
        }
    }
    var verticalCenters: [CGFloat] {
        (0..<verticalCount).map {
            edge.minY + corner + (CGFloat($0) + 0.5) * (edge.height - 2 * corner) / CGFloat(verticalCount)
        }
    }
}

private struct ScallopedNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 1, rect.height > 1 else { return Path() }
        let geometry = LaceNoteGeometry(bounds: rect)
        let r = geometry.edge
        let corner = geometry.corner
        let depth = geometry.depth
        var path = Path()

        // Draw each side in its local clockwise coordinate system. A single broad
        // curve per lobe leaves the tiny inward joins visible in the reference.
        for side in 0..<4 {
            let horizontal = side.isMultiple(of: 2)
            let length = horizontal ? r.width : r.height
            let count = horizontal ? geometry.horizontalCount : geometry.verticalCount
            func point(_ along: CGFloat, _ inward: CGFloat) -> CGPoint {
                switch side {
                case 0: CGPoint(x: r.minX + along, y: r.minY + inward)
                case 1: CGPoint(x: r.maxX - inward, y: r.minY + along)
                case 2: CGPoint(x: r.maxX - along, y: r.maxY - inward)
                default: CGPoint(x: r.minX + inward, y: r.maxY - along)
                }
            }
            if side == 0 { path.move(to: point(corner, depth)) }
            let step = (length - 2 * corner) / CGFloat(count)
            for index in 0..<count {
                let start = corner + CGFloat(index) * step
                path.addCurve(to: point(start + step, depth),
                              control1: point(start + step * 0.28, -depth / 3),
                              control2: point(start + step * 0.72, -depth / 3))
            }
            // A fuller corner petal replaces a conventional rounded-rectangle corner.
            path.addCurve(to: point(length - depth, depth),
                          control1: point(length - corner * 0.68, 0),
                          control2: point(length - corner * 0.3, 0))
            path.addCurve(to: point(length - depth, corner),
                          control1: point(length, corner * 0.3),
                          control2: point(length, corner * 0.68))
        }
        path.closeSubpath()
        return path
    }
}

struct MonthlyNoteSkinPicker: View {
    let monthTitle: String
    let ticketNumber: String
    let selected: MonthlyNoteSkin
    let onSelect: (MonthlyNoteSkin) -> Void
    @EnvironmentObject private var membership: MembershipStore
    @State private var isMembershipPresented = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(MonthlyNoteSkin.allCases) { skin in
                        Button {
                            if skin.requiresMembership && !membership.hasMembershipAccess {
                                isMembershipPresented = true
                            } else {
                                onSelect(skin)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(localized(skin.title)).font(.subheadline.weight(.medium))
                                    if skin.requiresMembership && !membership.hasMembershipAccess {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.palette.strongAccent)
                                    }
                                    Spacer()
                                    if skin == selected {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.palette.strongAccent)
                                    }
                                }
                                MonthlyNoteSurface(skin: skin, monthLabel: monthTitle, ticketNumber: ticketNumber) {
                                    // The surface supplies the shared minimum height. A fixed
                                    // placeholder would add extra height to padded player notes.
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 0)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(skin.requiresMembership && !membership.hasMembershipAccess
                                            ? localized("%@，需要会员", localized(skin.title))
                                            : localized(skin.title))
                        .accessibilityAddTraits(skin == selected ? [.isSelected] : [])
                    }
                }
                .padding(24)
            }
            .sheet(isPresented: $isMembershipPresented) {
                MembershipScreen()
                    .environmentObject(membership)
            }
            .background(theme.palette.background)
            .navigationTitle(localized("月便签样式"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("完成")) { dismiss() }
                }
            }
        }
    }
}
