import SwiftUI

/// Subtle woven spine, with no metal hardware.
struct ClothNotebookSpine: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(1), to: size.width, by: 2) {
                var thread = Path()
                thread.move(to: CGPoint(x: x, y: 0))
                thread.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(thread, with: .color(theme.palette.foreground.opacity(0.045)), lineWidth: 0.5)
            }
            for y in stride(from: CGFloat(1), to: size.height, by: 3) {
                var thread = Path()
                thread.move(to: CGPoint(x: 0, y: y))
                thread.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(thread, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
            }
        }
        .overlay {
            LinearGradient(
                colors: [.black.opacity(0.06), .clear, .black.opacity(0.12)],
                startPoint: .leading, endPoint: .trailing
            )
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
