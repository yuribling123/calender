import SwiftUI

struct SelectedDateDetail: View {
    let date: Date
    let entry: MoodEntry?
    let onRecordMood: (Mood) -> Void
    let onEditToday: () -> Void

    private var relation: DayRelation { DayKey(date).relationToToday }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 1)

            HStack {
                Text("\(date.formatted(.dateTime.month().day())) · \(date.formatted(.dateTime.weekday(.wide)))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if relation == .today, entry?.mood != nil {
                    Button(action: onEditToday) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("修改心情")
                }
            }

            switch relation {
            case .today:
                if let mood = entry?.mood {
                    recordedMood(mood)
                } else {
                    Text("今天是什么心情？")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(Mood.allCases) { mood in
                            Button { onRecordMood(mood) } label: {
                                Image(mood.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipped()
                                    .blendMode(.multiply)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("记录今天的心情：\(mood.title)")
                        }
                    }
                }
            case .past:
                if let mood = entry?.mood {
                    recordedMood(mood)
                    if entry?.note.isEmpty ?? true {
                        Text("那天没有留下文字记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("这一天没有留下心情记录")
                        .foregroundStyle(.secondary)
                }
            case .future:
                Text("这一天还没到来")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func recordedMood(_ mood: Mood) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(mood.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipped()
                    .blendMode(.multiply)
                    .accessibilityHidden(true)
                Text(mood.title)
                    .font(.headline)
            }
            if let note = entry?.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
