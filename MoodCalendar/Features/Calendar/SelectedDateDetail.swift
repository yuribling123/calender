import SwiftUI

struct SelectedDateDetail: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true

    @State private var isPhotoPresented = false

    let date: Date
    let entry: MoodEntry?
    let onRecordMood: (Mood) -> Void
    let onEdit: () -> Void

    private var relation: DayRelation { DayKey(date).relationToToday }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(relation == .today
                     ? localized("今天")
                     : "\(date.formatted(.dateTime.locale(AppLanguage.locale).month().day())) · \(date.formatted(.dateTime.locale(AppLanguage.locale).weekday(.wide)))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground.opacity(0.82))
                if entry?.photoData != nil {
                    Button { isPhotoPresented = true } label: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 5) {
                                PhotoStackOutline()
                                    .stroke(style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                                    .foregroundStyle(theme.palette.strongAccent.opacity(0.75))
                                    .frame(width: 16, height: 19)
                                    .accessibilityHidden(true)
                                Text(localized("这天有个画面"))
                                    .foregroundStyle(theme.palette.strongAccent.opacity(0.75))
                            }
                            .fixedSize()
                            PhotoStackOutline()
                                .stroke(style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(theme.palette.strongAccent.opacity(0.75))
                                .frame(width: 16, height: 19)
                                .accessibilityHidden(true)
                        }
                        .font(.caption2)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -11)
                    .accessibilityLabel(localized("这天有个画面"))
                }
                Spacer(minLength: 8)
                if relation == .past && allowPastDateEditing || relation == .today && entry?.choice != nil {
                    Color.clear.frame(width: relation == .past ? 60 : 44, height: 22)
                }
            }
            .frame(minHeight: 22)
            .padding(.bottom, -8)
            .overlay(alignment: .trailing) {
                if relation == .past && allowPastDateEditing || relation == .today && entry?.choice != nil {
                    Button(action: onEdit) {
                        Group {
                            if relation == .past {
                                Text(localized("补充"))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(theme.palette.strongAccent)
                            } else {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(relation == .past ? localized("补充") : localized("修改记录"))
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
                                ChoiceArtwork(mood: mood)
                                    .scaledToFit()
                                    .frame(width: 50, height: 42)
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(1.3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(localized("记录今天的心情：%@", String(describing: mood.title)))
                        }
                    }

                    Button(localized("选其他表情"), action: onEdit)
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
        .fullScreenCover(isPresented: $isPhotoPresented) {
            if let data = entry?.photoData, let image = UIImage(data: data) {
                DailyPhotoPreview(image: image)
                    .environment(\.appTheme, theme)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(CardPaper.resolve(entry?.cardPaperID).color(for: theme, scheme: colorScheme))
        }
    }

    private func choiceArtwork(_ choice: DailyChoice) -> some View {
        ChoiceArtwork(choice: choice)
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
            if let title = entry?.songTitle, !title.isEmpty {
                DailySongCard(title: title, artist: entry?.songArtist ?? "")
                    .padding(.top, -6)
                    .padding(.bottom, entry?.note.isEmpty == false ? 18 : 4)
            }
            if let note = entry?.note, !note.isEmpty {
                Text(DemoData.displayText(note))
                    .font(.subheadline)
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

/// A listening memory styled like a player; it has no playback action.
struct DailySongCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let artist: String

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Text("♫")
                    .accessibilityHidden(true)
                Text(songDescription)
                    .foregroundStyle(theme.palette.strongAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 13))
            .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground.opacity(0.72))

            HStack(spacing: 16) {
                Image(systemName: "backward.fill")
                    .frame(width: 11)
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .frame(width: 11)
                Image(systemName: "forward.fill")
                    .frame(width: 11)
            }
            .font(.system(size: 10 / 1.15))
            .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground.opacity(0.64))
            .fixedSize()
            .accessibilityHidden(true)

            Spacer(minLength: 0)
            Text(verbatim: "NOW PLAYING")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(theme.palette.strongAccent)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var songDescription: String {
        let song = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let singer = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return singer.isEmpty ? song : "\(song) · \(singer)"
    }
}

private struct DailyPhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let image: UIImage
    @State private var isVisible = false
    @State private var zoom: CGFloat = 1
    @State private var isClosing = false
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack {
            theme.palette.resolved(for: colorScheme).background.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(24)
                .scaleEffect(zoom * pinch * (isVisible || reduceMotion ? 1 : 0.86))
                .blur(radius: isVisible || reduceMotion ? 0 : 10)
                .opacity(isVisible ? 1 : 0)
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in
                            state = min(4 / zoom, max(0.45 / zoom, value.magnification))
                        }
                        .onEnded { value in
                            if zoom <= 1.05 && value.magnification < 0.68 {
                                closePhoto()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    zoom = min(4, max(1, zoom * value.magnification))
                                }
                            }
                        }
                )
                .accessibilityAction(named: localized("关闭")) { closePhoto() }
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button { closePhoto() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(theme.palette.resolved(for: colorScheme).cardBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("关闭"))
            .padding(12)
        }
        .onAppear {
            guard !isVisible else { return }
            PhotoOpenFeedback.play()
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.55, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
    }

    private func closePhoto() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(.easeIn(duration: 0.2)) { isVisible = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            dismiss()
        }
    }
}

// Only the exposed edges of the rear photo are drawn, so the outlines never overlap.
private struct PhotoStackOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.width / 18
        let y = rect.height / 22
        func point(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + px * x, y: rect.minY + py * y)
        }
        path.move(to: point(3.8, 16.5))
        path.addLine(to: point(0.9, 4.1))
        path.addQuadCurve(to: point(1.8, 2.9), control: point(0.6, 3.2))
        path.addLine(to: point(11.1, 0.7))
        path.addQuadCurve(to: point(12.4, 1.5), control: point(12.1, 0.5))
        path.addLine(to: point(13, 3.6))
        path.move(to: point(3.8, 10.5))
        path.addLine(to: point(2.5, 5.1))
        path.addLine(to: point(3.8, 4.8))
        path.addRoundedRect(in: CGRect(x: rect.minX + 3.8 * x, y: rect.minY + 3.6 * y,
                                      width: 13.3 * x, height: 17.6 * y),
                            cornerSize: CGSize(width: 1.2 * x, height: 1.2 * y))
        path.addRoundedRect(in: CGRect(x: rect.minX + 5.3 * x, y: rect.minY + 5.3 * y,
                                      width: 10.3 * x, height: 11.9 * y),
                            cornerSize: CGSize(width: 0.2 * x, height: 0.2 * y))
        return path
    }
}
