import SwiftUI

/// Narrow silver notebook binding.
struct RibbonNotebookBinding: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 32, 1)
            guard scale > 0, size.height > 70 else { return }
            let ringCenters = stride(from: CGFloat(70), through: size.height - 28, by: 82).map { $0 }
            for center in ringCenters {
                drawRing(at: center, scale: scale, in: &context)
            }

        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawRing(at y: CGFloat, scale: CGFloat, in context: inout GraphicsContext) {
        let hole = Path(ellipseIn: CGRect(x: 24 * scale, y: y - 4, width: 5 * scale, height: 8))
        context.fill(hole, with: .color(.black.opacity(colorScheme == .dark ? 0.42 : 0.15)))

        var ring = Path()
        ring.move(to: CGPoint(x: 27 * scale, y: y - 2))
        ring.addCurve(
            to: CGPoint(x: 27 * scale, y: y + 3),
            control1: CGPoint(x: -5 * scale, y: y - 18),
            control2: CGPoint(x: -5 * scale, y: y + 18)
        )

        context.stroke(
            ring.applying(CGAffineTransform(translationX: 0, y: 1)),
            with: .color(.black.opacity(colorScheme == .dark ? 0.30 : 0.13)),
            style: StrokeStyle(lineWidth: 3.5 * scale, lineCap: .round)
        )
        context.stroke(
            ring,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(white: 0.48), location: 0),
                    .init(color: Color(white: 0.95), location: 0.30),
                    .init(color: Color(white: 0.64), location: 0.54),
                    .init(color: Color(white: 0.91), location: 0.72),
                    .init(color: Color(white: 0.42), location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: y - 9),
                endPoint: CGPoint(x: 0, y: y + 9)
            ),
            style: StrokeStyle(lineWidth: 2.8 * scale, lineCap: .round)
        )

        var glint = Path()
        glint.move(to: CGPoint(x: 6 * scale, y: y - 3))
        glint.addQuadCurve(
            to: CGPoint(x: 19 * scale, y: y - 5),
            control: CGPoint(x: 9 * scale, y: y - 7)
        )
        context.stroke(
            glint, with: .color(.white.opacity(0.78)),
            style: StrokeStyle(lineWidth: 0.65 * scale, lineCap: .round)
        )
    }

}

/// Rounded stamp paper with small inward perforations along all four edges.
struct PostageStickerShape: Shape {
    var perforationDepth: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let corner = min(4, min(rect.width, rect.height) / 4)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        addPerforations(
            to: &path, from: CGPoint(x: rect.minX + corner, y: rect.minY),
            to: CGPoint(x: rect.maxX - corner, y: rect.minY), inward: CGVector(dx: 0, dy: 1)
        )
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + corner), control: CGPoint(x: rect.maxX, y: rect.minY))
        addPerforations(
            to: &path, from: CGPoint(x: rect.maxX, y: rect.minY + corner),
            to: CGPoint(x: rect.maxX, y: rect.maxY - corner), inward: CGVector(dx: -1, dy: 0)
        )
        path.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        addPerforations(
            to: &path, from: CGPoint(x: rect.maxX - corner, y: rect.maxY),
            to: CGPoint(x: rect.minX + corner, y: rect.maxY), inward: CGVector(dx: 0, dy: -1)
        )
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner), control: CGPoint(x: rect.minX, y: rect.maxY))
        addPerforations(
            to: &path, from: CGPoint(x: rect.minX, y: rect.maxY - corner),
            to: CGPoint(x: rect.minX, y: rect.minY + corner), inward: CGVector(dx: 1, dy: 0)
        )
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private func addPerforations(to path: inout Path, from start: CGPoint, to end: CGPoint, inward: CGVector) {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return }
        let direction = CGVector(dx: (end.x - start.x) / length, dy: (end.y - start.y) / length)
        let count = max(1, Int(length / 9))
        let pitch = length / CGFloat(count)
        let radius = min(2.3, pitch * 0.3)

        func point(at distance: CGFloat, depth: CGFloat = 0) -> CGPoint {
            CGPoint(
                x: start.x + direction.dx * distance + inward.dx * depth,
                y: start.y + direction.dy * distance + inward.dy * depth
            )
        }

        for index in 0..<count {
            let middle = (CGFloat(index) + 0.5) * pitch
            path.addLine(to: point(at: middle - radius))
            path.addQuadCurve(to: point(at: middle + radius), control: point(at: middle, depth: radius * 2 * perforationDepth))
        }
        path.addLine(to: end)
    }
}
