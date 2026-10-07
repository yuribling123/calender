import SwiftUI

struct SelectedDateDetail: View {
    let date: Date
    let entry: MoodEntry?
    let onRecordMood: (Mood) -> Void
    let onChooseDaily: () -> Void
    let onEditToday: () -> Void

    private var relation: DayRelation { DayKey(date).relationToToday }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 1)

            HStack {
                Text(relation == .today
                     ? "今天"
                     : "\(date.formatted(.dateTime.month().day())) · \(date.formatted(.dateTime.weekday(.wide)))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(minHeight: 28)
            .overlay(alignment: .trailing) {
                if relation == .today, entry?.choice != nil {
                    Button(action: onEditToday) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("修改记录")
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.64), value: entry?.choice)

            switch relation {
            case .today:
                if let choice = entry?.choice {
                    recordedChoice(choice)
                } else {
                    HStack {
                        Text("今天什么心情？")
                            .font(.subheadline.weight(.medium))

//                        Spacer()
//
//                        Button("或记一件小日常") {
//                            onChooseDaily()
//                        }
//                        .font(.subheadline.weight(.medium))
//                        .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(Mood.allCases) { mood in
                            Button { onRecordMood(mood) } label: {
                                Image(mood.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 42)
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(1.3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("记录今天的心情：\(mood.title)")
                        }
                    }

                }
            case .past:
                if let choice = entry?.choice {
                    recordedChoice(choice)
                } else {
                    Text("这一天没有留下记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .future:
                Text("这一天还没到来")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    private struct ArtworkMetrics {
        let renderWidth: CGFloat
        let visibleLeft: CGFloat
    }

    private func artworkMetrics(for choice: DailyChoice) -> ArtworkMetrics? {
        switch choice {
        
        // Each value is derived from the artwork's transparent bounds so the
        // visible illustration, rather than its source canvas, is 22pt high.
        // case .clover: ArtworkMetrics(renderWidth: 59.3, visibleLeft: 17.5)
        // case .heart: ArtworkMetrics(renderWidth: 74.1, visibleLeft: 22.6)
        // case .music: ArtworkMetrics(renderWidth: 62.9, visibleLeft: 18.6)
        // case .coffee: ArtworkMetrics(renderWidth: 53.6, visibleLeft: 17.0)
        // case .cake: ArtworkMetrics(renderWidth: 53.6, visibleLeft: 16.4)
        // case .exercise: ArtworkMetrics(renderWidth: 85.0, visibleLeft: 25.1)
        // case .work: ArtworkMetrics(renderWidth: 82.2, visibleLeft: 24.8)
        // case .relax: ArtworkMetrics(renderWidth: 81.4, visibleLeft: 23.3)
        // case .gather: ArtworkMetrics(renderWidth: 95.5, visibleLeft: 26.9)
        // case .study: ArtworkMetrics(renderWidth: 92.5, visibleLeft: 27.3)
        // case .family: ArtworkMetrics(renderWidth: 78.7, visibleLeft: 23.4)
        // case .thinkingOfSomeone: ArtworkMetrics(renderWidth: 67.5, visibleLeft: 20.9)
        // case .fluffy: ArtworkMetrics(renderWidth: 80.5, visibleLeft: 24.3)
        // case .alone: ArtworkMetrics(renderWidth: 78.9, visibleLeft: 23.9)
        // case .friends: ArtworkMetrics(renderWidth: 84.3, visibleLeft: 25.2)
        default: nil
        }
    }

@ViewBuilder
private func choiceArtwork(_ choice: DailyChoice) -> some View {
    if let metrics = artworkMetrics(for: choice) {
        Image(choice.imageName)
            .resizable()
            .scaledToFit()
            .frame(
                width: metrics.renderWidth,
                height: metrics.renderWidth / 2
            )
            .offset(x: -(metrics.visibleLeft - 2))
            .frame(width: 44, height: 36, alignment: .leading)
            .clipped()
    } else {
        Image(choice.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 52) // 图片渲染尺寸，不要改
            .scaleEffect(choice.group == .mood ? 1 : choice == .cake ? 1.15 : 1.3)
            .offset(x: choice.group == .mood ? 0 : -10)
            .frame(
                width: choice.group == .mood ? 60 : 44,
                height: 52,
                alignment: .leading
            ) // 只改变它占的布局空间
    }
}

    private func recordedChoice(_ choice: DailyChoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 2) {
                choiceArtwork(choice)
                    .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(choice.title)
                        .font(.subheadline.weight(.medium))
                    Text(choice.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(choice.group.rawValue)，\(choice.title)，\(choice.caption)")
            }
            if let note = entry?.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}
