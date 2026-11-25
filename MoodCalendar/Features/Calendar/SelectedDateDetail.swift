import SwiftUI

struct SelectedDateDetail: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .subheadline) private var detailTextSize: CGFloat = 14

    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @AppStorage("lastSelectedCardPaper") private var lastSelectedCardPaper = ""

    @State private var isPhotoPresented = false

    let date: Date
    let entry: MoodEntry?
    // Rediscovery shares the original card without exposing write actions.
    var isReadOnly = false
    var showsYear = false
    var showsPaperBackground = true
    var onOpenRecord: (() -> Void)? = nil
    var isStarred = false
    var onToggleStar: () -> Void = {}
    let onRecordMood: (Mood) -> Void
    let onEdit: () -> Void

    private var relation: DayRelation { DayKey(date).relationToToday }
    private var canMark: Bool { !isReadOnly && (relation == .today || relation == .past && allowPastDateEditing) }
    private var canEdit: Bool {
        !isReadOnly && (relation == .past && allowPastDateEditing || relation == .today && entry?.choice != nil)
    }
    private var selectedPaper: CardPaper {
        let paper = CardPaper.resolve(relation == .today && entry?.choice == nil ? lastSelectedCardPaper : entry?.cardPaperID)
        return relation == .today && entry?.choice == nil && paper == .strawberryHearts ? .blueberryHearts : paper
    }
    private var isNightPaper: Bool { selectedPaper == .nightHearts }
    private var cardInk: Color { isNightPaper ? .white : theme.palette.resolved(for: colorScheme).foreground }
    private var dateHeading: String {
        if relation == .today { return localized(entry?.choice == nil ? "今天什么心情？" : "今天") }
        let format: Date.FormatStyle = showsYear
            ? .dateTime.locale(AppLanguage.locale).year().month().day()
            : .dateTime.locale(AppLanguage.locale).month().day()
        return "\(date.formatted(format)) · \(date.formatted(.dateTime.locale(AppLanguage.locale).weekday(.wide)))"
    }

    var body: some View {
        detailCard
        .fullScreenCover(isPresented: $isPhotoPresented) {
            if let data = entry?.photoData, let image = UIImage(data: data) {
                DailyPhotoPreview(image: image)
                    .environment(\.appTheme, theme)
            }
        }
    }

    private var detailActions: some View {
        CalendarTextMenu(iconFont: .system(size: detailTextSize, weight: .medium),
                         tint: cardInk.opacity(0.7), aboveTrigger: true,
                         menuColorScheme: colorScheme) { item in
            if canMark {
                item(localized(isStarred ? "已标记" : "标记"), isStarred ? "star.fill" : "star", onToggleStar)
                    .accessibilityLabel(localized(isStarred ? "取消标记这一天" : "标记这一天"))
            }
            if canMark && canEdit {
                Rectangle()
                    .fill(.primary.opacity(0.10))
                    .frame(width: 0.5, height: 16)
                    .accessibilityHidden(true)
            }
            if canEdit {
                item(localized("编辑"), "pencil", onEdit)
            }
        }
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(dateHeading)
                    .font(.system(size: detailTextSize, weight: .medium))
                    .foregroundStyle(isNightPaper ? .white : AppTheme.black.palette.strongAccent)
                Spacer(minLength: 8)
                if canMark || canEdit {
                    Color.clear.frame(width: 44, height: 22)
                }
            }
            .frame(minHeight: 22)
            .padding(.bottom, -8)
            .overlay(alignment: .trailing) {
                if canMark || canEdit { detailActions }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.64), value: entry?.choice)

            switch relation {
            case .today:
                if let choice = entry?.choice {
                    recordContent(choice)
                } else {
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
                        .font(.system(size: detailTextSize, weight: .medium))
                        .foregroundStyle(isNightPaper ? .white : theme.palette.strongAccent)
                        .padding(.vertical, 8)
                        .buttonStyle(.plain)

                }
            case .past:
                if let choice = entry?.choice {
                    recordContent(choice)
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
            if showsPaperBackground {
                CardPaperBackground(paper: selectedPaper, cornerRadius: 18)
            }
        }
        .environment(\.colorScheme, isNightPaper ? .dark : colorScheme)
    }

    private func choiceArtwork(_ choice: DailyChoice) -> some View {
        ChoiceArtwork(choice: choice)
            .scaledToFit()
            .frame(width: 60, height: 52) // 图片渲染尺寸，不要改
            .scaleEffect(detailArtworkScale(for: choice))
            .scaleEffect(choice.group == .daily ? 0.9 : 1)
            .offset(x: choice.group == .mood ? 0 : -10)
            .frame(
                width: choice.group == .mood ? 60 : 44,
                height: 52,
                alignment: .leading
            ) // 只改变它占的布局空间
    }

    private func detailArtworkScale(for choice: DailyChoice) -> CGFloat {
        choice.weatherArtworkScale
            ?? ([DailyChoice.poutyRabbit, .absentRabbit, .glassesRabbit, .tearfulRabbit].contains(choice) ? 1.17 : choice.group == .mood ? 1 : choice == .cake ? 1.15 : 1.3)
    }

    @ViewBuilder
    private func recordContent(_ choice: DailyChoice) -> some View {
        if !isReadOnly, let onOpenRecord {
            recordedChoice(choice)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenRecord)
                .accessibilityAction(named: localized("查看这一天的记录")) { onOpenRecord() }
        } else {
            recordedChoice(choice)
        }
    }

    private func recordedChoice(_ choice: DailyChoice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 2) {
                choiceArtwork(choice)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(choice.title)
                            .font(.system(size: detailTextSize, weight: .medium))
                        Text(choice.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(choice.title)
                            .font(.system(size: detailTextSize, weight: .medium))
                        Text(choice.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(choice.group.title), \(choice.title), \(choice.caption)")
                Spacer(minLength: 8)
                photoButton
            }
            if let location = entry?.locationName, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .foregroundStyle(cardInk.opacity(0.72))
                        .accessibilityHidden(true)
                    Text(location)
                        .foregroundStyle(isNightPaper ? .white : theme.palette.strongAccent)
                }
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .padding(.top, 7)
                    .padding(
                        .bottom,
                        entry?.watchTitle?.isEmpty == false || entry?.songTitle?.isEmpty == false
                            ? 0
                            : (entry?.note.isEmpty == false ? 18 : 12)
                    )
                    .accessibilityLabel("\(localized("地点"))，\(location)")
            }

            // 🎬 电影
            if let title = entry?.watchTitle, !title.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        WatchTVIcon()
                            .frame(width: 16, height: 12)
                            .foregroundStyle(cardInk.opacity(0.72))
                            .accessibilityHidden(true)

                        Text(title)
                            .font(.system(size: 13))
                            .foregroundStyle(isNightPaper ? .white : theme.palette.strongAccent)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)
                        Text(verbatim: "WATCHING")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(0.5)
                            .fixedSize()
                            .padding(.leading, 12)
                    }

                }
                .foregroundStyle(.primary)
                .padding(.top, 7)
                .padding(
                    .bottom,
                    entry?.songTitle?.isEmpty == false
                        ? 0
                        : (entry?.note.isEmpty == false ? 18 : 12)
                )
                .accessibilityElement(children: .combine)
            }

            // 🎵 音乐
            if let title = entry?.songTitle, !title.isEmpty {
                DailySongCard(
                    title: title,
                    artist: entry?.songArtist ?? "",
                    isNightPaper: isNightPaper
                )
                .padding(.top, 7)
                .padding(.bottom, entry?.note.isEmpty == false ? 18 : 12)
            }
            if let note = entry?.note, !note.isEmpty {
                Text(DemoData.displayText(note))
                    .font(.system(size: detailTextSize))
                    .lineSpacing(9)
                    .foregroundStyle(.primary)
            }

        }
    }

    @ViewBuilder
    private var photoButton: some View {
        if let data = entry?.photoData, let image = UIImage(data: data) {
            Button {
                isPhotoPresented = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(1)
                    .background(theme.palette.resolved(for: colorScheme).cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
                    .frame(minWidth: 44, minHeight: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("这天有个画面"))
        }
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: detailTextSize))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}

struct CalendarTextMenu<Items: View>: View {
    @ScaledMetric(relativeTo: .footnote) private var textSize: CGFloat = 12
    @State private var isPresented = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme

    let iconFont: Font
    let tint: Color
    var aboveTrigger = false
    var menuColorScheme: ColorScheme? = nil
    @ViewBuilder let items: (_ item: (String, String?, @escaping () -> Void) -> Button<CalendarTextMenuLabel>) -> Items

    var body: some View {
        Button { isPresented = true } label: {
            Image(systemName: "ellipsis")
                .font(iconFont)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("日历菜单"))
        .anchorPreference(key: CalendarMenuPreference.self, value: .bounds) { anchor in
            guard isPresented else { return nil }
            return CalendarMenuPlacement(anchor: anchor, content: AnyView(menuContent), dismiss: dismiss,
                                         aboveTrigger: aboveTrigger)
        }
        .onDisappear(perform: dismiss)
    }

    private var menuContent: some View {
        let layout = aboveTrigger ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        return layout {
            items(menuItem)
        }
        .buttonStyle(CalendarTextMenuItemStyle(textSize: textSize, isCompact: aboveTrigger))
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, aboveTrigger ? 2 : 4)
        .padding(.vertical, aboveTrigger ? 0 : 3)
        .padding(.bottom, aboveTrigger ? 6 : 0)
        .background(theme.palette.memoBody, in: CalendarMenuBackground(hasTail: aboveTrigger))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .environment(\.colorScheme, menuColorScheme ?? colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
    }

    private func dismiss() {
        isPresented = false
    }

    private func menuItem(_ title: String, symbol: String?, action: @escaping () -> Void) -> Button<CalendarTextMenuLabel> {
        Button {
            dismiss()
            action()
        } label: {
            CalendarTextMenuLabel(title: title, symbol: symbol)
        }
    }
}

struct CalendarTextMenuLabel: View {
    @ScaledMetric(relativeTo: .footnote) private var symbolWidth: CGFloat = 18
    let title: String
    let symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: symbolWidth)
                    .accessibilityHidden(true)
            }
            Text(title)
        }
    }
}

struct CalendarTextMenuDivider: View {
    var body: some View {
        Divider()
            .opacity(0.45)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }
}

struct CalendarMenuPlacement {
    static let tailInset: CGFloat = 16
    let anchor: Anchor<CGRect>
    let content: AnyView
    let dismiss: () -> Void
    let aboveTrigger: Bool
}

private struct CalendarMenuBackground: Shape {
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let tailHeight: CGFloat = hasTail ? 6 : 0
        var body = rect
        body.size.height -= tailHeight
        var path = RoundedRectangle(cornerRadius: 10).path(in: body)
        if hasTail {
            let center = rect.maxX - CalendarMenuPlacement.tailInset
            path.move(to: CGPoint(x: center - 5, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: center + 5, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: center, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct CalendarMenuPreference: PreferenceKey {
    static let defaultValue: CalendarMenuPlacement? = nil

    static func reduce(value: inout CalendarMenuPlacement?, nextValue: () -> CalendarMenuPlacement?) {
        value = nextValue() ?? value
    }
}

private struct CalendarTextMenuItemStyle: ButtonStyle {
    let textSize: CGFloat
    let isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: textSize, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, isCompact ? 6 : 8)
            .frame(minWidth: isCompact ? 50 : 58, maxWidth: .infinity,
                   minHeight: 44, alignment: isCompact ? .center : .leading)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .contentShape(Rectangle())
    }
}

/// A listening memory styled like a player; it has no playback action.
struct DailySongCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let artist: String
    var isNightPaper = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("♫")
                    .accessibilityHidden(true)
                Text(songDescription)
                    .foregroundStyle(isNightPaper ? .white : theme.palette.strongAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 13))
            .foregroundStyle((isNightPaper ? Color.white : theme.palette.resolved(for: colorScheme).foreground).opacity(0.72))
            .layoutPriority(1)

            Spacer(minLength: 0)
            Text(verbatim: "NOW PLAYING")
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .fixedSize()
                .padding(.leading, 12)
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
