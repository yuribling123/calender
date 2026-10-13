import SwiftUI

struct SelectedDateDetail: View {
    @Environment(\.appTheme) private var theme

    let date: Date
    let entry: MoodEntry?
    let onRecordMood: (Mood) -> Void
    let onEditToday: () -> Void

    private var relation: DayRelation { DayKey(date).relationToToday }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(relation == .today
                     ? localized("今天")
                     : "\(date.formatted(.dateTime.locale(AppLanguage.locale).month().day())) · \(date.formatted(.dateTime.locale(AppLanguage.locale).weekday(.wide)))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.72))
                Spacer()
            }
            .padding(.bottom, -8)
            .overlay(alignment: .trailing) {
                if relation == .today, entry?.choice != nil {
                    Button(action: onEditToday) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("修改记录"))
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
                        Text(localized("今天什么心情？"))
                            .font(.subheadline.weight(.medium))

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
                            .accessibilityLabel(localized("记录今天的心情：%@", String(describing: mood.title)))
                        }
                    }

                    Button(localized("选其他表情"), action: onEditToday)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.palette.strongAccent)
                        .padding(.vertical, 8)
                        .buttonStyle(.plain)

                }
            case .past:
                if let choice = entry?.choice {
                    recordedChoice(choice)
                } else {
                    statusMessage(localized("这一天没有留下记录"))
                }
            case .future:
                statusMessage(localized("这一天还没到来"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.palette.accent.opacity(0.06))
        }
    }

    private func choiceArtwork(_ choice: DailyChoice) -> some View {
        Image(choice.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 52) // 图片渲染尺寸，不要改
            .scaleEffect([DailyChoice.poutyRabbit, .absentRabbit, .glassesRabbit, .tearfulRabbit].contains(choice) ? 1.17 : choice.group == .mood ? 1 : choice == .cake ? 1.15 : 1.3)
            .offset(x: choice.group == .mood ? 0 : -10)
            .frame(
                width: choice.group == .mood ? 60 : 44,
                height: 52,
                alignment: .leading
            ) // 只改变它占的布局空间
    }

    private func recordedChoice(_ choice: DailyChoice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 2) {
                choiceArtwork(choice)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(choice.title)
                        .font(.subheadline.weight(.medium))
                    Text(choice.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(choice.title)
                            .font(.subheadline.weight(.medium))
                        Text(choice.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(choice.group.title), \(choice.title), \(choice.caption)")
            }
            if let note = entry?.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}
