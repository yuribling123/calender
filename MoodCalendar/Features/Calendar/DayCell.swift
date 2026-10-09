import SwiftUI

struct DayCell: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.selectionShape) private var selectionShape
    @ScaledMetric(relativeTo: .body) private var scaledDateSize: CGFloat = 15

    let date: Date
    let choice: DailyChoice?
    let hasNote: Bool
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool
    let isRevealPending: Bool
    let isAnimating: Bool

    @State private var revealScale: CGFloat = 1
    @State private var revealOpacity: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                
                // 日期
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(
                        .system(
                            size: min(scaledDateSize, 20),
                            weight: isSelected ? .semibold : .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        isSelected
                            ? theme.palette.onSelection
                            : isToday
                                ? theme.palette.accent
                                : Color.primary
                    )
                    .opacity(isFuture ? 0.55 : 1)
                    .frame(
                        width: min(34, geometry.size.width),
                        height: 28
                    )
                    .background {
                        if isSelected {
                            SelectionShapeIcon(
                                shape: selectionShape,
                                color: theme.palette.selectionFill,
                                size: selectionShape == .sakura || selectionShape == .leaf ? 40 : 34
                            )
                        }
                    }

                // 图标 + Note 标记
                VStack(spacing: 2) {
                    
                    // 图标
                    Group {
                        if let choice {
                            Image(choice.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: min(50, geometry.size.width),
                                    height: 26
                                )
                                .scaleEffect(
                                    choice == .cake ? 1.05 : choice.group == .daily ? 1.2:choice.group == .mood ? 1 : choice == .gather ? 1.6 : choice.group == .company ? 1.5 : 1.4
                                )
                                .scaleEffect(revealScale)
                                .opacity(isRevealPending ? 0 : revealOpacity)
                                .accessibilityHidden(true)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 26)

                    // 有 Note 时显示两条横线
                    VStack(alignment: .leading, spacing: 2) {
                        Capsule()
                            .frame(width: 12, height: 1.5)

                        Capsule()
                            .frame(width: 8, height: 1.5)
                    }
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .opacity(hasNote ? 1 : 0)
                    .frame(height: 8)
                    .accessibilityHidden(true)
                }
                .padding(.top, 6) // ← 图标 + 横线整体往下
            }
            .padding(.top, 8)
            .frame(
                width: geometry.size.width,
                height: 74,
                alignment: .top
            )
        }
        .frame(height: 74)
        .onAppear {
            if isRevealPending { prepareReveal() }
        }
        .onChange(of: isRevealPending) { _, isPending in
            if isPending {
                prepareReveal()
            } else if isAnimating {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    revealScale = 1
                    revealOpacity = 1
                }
            }
        }
    }

    private func prepareReveal() {
        revealScale = 0.55
        revealOpacity = 0
    }
}
