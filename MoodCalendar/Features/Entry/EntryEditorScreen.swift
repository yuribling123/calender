import SwiftUI
import SwiftData
import PhotosUI

private struct NoteCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct EntryEditorScreen: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let day: Date
    let entry: MoodEntry?
    let initialGroup: ChoiceGroup
    let onSaved: (DailyChoice, Bool) -> Void

    @State private var selectedChoice: DailyChoice?
    @State private var selectedGroup: ChoiceGroup = .mood
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var note = ""
    @State private var showsNote = false
    @State private var selectedPaper: CardPaper = .pink
    @State private var showsSong = false
    @State private var songTitle = ""
    @State private var songArtist = ""
    @State private var isSongEditorPresented = false
    @State private var isPaperPickerPresented = false
    @State private var errorMessage: String?
    @State private var isMembershipPresented = false
    @State private var noteCardFrame: CGRect = .zero
    @FocusState private var isNoteFocused: Bool

    private var hasPremiumAccess: Bool { membership.hasMembershipAccess }

    private func canUse(_ choice: DailyChoice) -> Bool {
        hasPremiumAccess || choice.group == .mood || choice.group == .activity || choice.group == .company
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorHeading

                    groupPicker

                    choicePicker

                    noteCard

                    songAttachment

                    photoAttachment

                    paperPicker
                }
                .padding(24)
            }
            .background(theme.palette.resolved(for: colorScheme).background)
            .coordinateSpace(name: "EntryEditor")
            .onPreferenceChange(NoteCardFramePreferenceKey.self) {
                noteCardFrame = $0
            }
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named("EntryEditor"))
                    .onEnded { tap in
                        guard showsNote,
                              isNoteFocused,
                              !noteCardFrame.contains(tap.location) else { return }
                        isNoteFocused = false
                    }
            )
            .navigationTitle(day.formatted(.dateTime.locale(AppLanguage.locale).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("保存")) { save() }
                        .disabled(selectedChoice == nil || isLoadingPhoto || (showsSong && songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .alert(localized("保存失败"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? localized("请稍后再试。"))
            }
            .sheet(isPresented: $isMembershipPresented) {
                MembershipScreen()
                    .environmentObject(membership)
            }
            .sheet(isPresented: $isPaperPickerPresented) {
                PaperDialPicker(selectedPaper: $selectedPaper)
            }
            .onChange(of: photoItem) { _, item in
                photoLoadTask?.cancel()
                guard let item else { return }
                isLoadingPhoto = true
                photoLoadTask = Task {
                    defer { if !Task.isCancelled { isLoadingPhoto = false } }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { throw PhotoLoadError.invalidImage }
                        try Task.checkCancellation()
                        let size = image.size
                        let scale = min(1, 1600 / max(size.width, size.height))
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        let rendered = UIGraphicsImageRenderer(size: CGSize(width: size.width * scale, height: size.height * scale), format: format).image { _ in
                            image.draw(in: CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale)))
                        }
                        guard let jpeg = rendered.jpegData(compressionQuality: 0.82) else { throw PhotoLoadError.invalidImage }
                        photoData = jpeg
                    } catch is CancellationError {
                    } catch { errorMessage = localized("照片未能加载，请重新选择。") }
                }
            }
            .onDisappear { photoLoadTask?.cancel() }
            .onAppear {
                selectedChoice = entry?.choice
                selectedGroup = entry?.choice?.group ?? initialGroup
                photoData = entry?.photoData
                note = entry?.note ?? ""
                showsNote = !(entry?.note.isEmpty ?? true)
                let savedPaper = CardPaper.resolve(entry?.cardPaperID)
                selectedPaper = savedPaper == .original ? CardPaper.matching(theme) : savedPaper
                songTitle = entry?.songTitle ?? ""
                songArtist = entry?.songArtist ?? ""
                showsSong = !songTitle.isEmpty
            }
        }
        .allowsHitTesting(!isSongEditorPresented)
        .accessibilityHidden(isSongEditorPresented)
        .overlay {
            if isSongEditorPresented {
                SongEditorOverlay(title: songTitle, artist: songArtist, isToday: DayKey(day).relationToToday == .today, onClose: {
                    isSongEditorPresented = false
                }) { title, artist in
                    songTitle = title
                    songArtist = artist
                    showsSong = !title.isEmpty
                    isSongEditorPresented = false
                }
            }
        }
    }

    private var songAttachment: some View {
        Button {
            isNoteFocused = false
            isSongEditorPresented = true
        } label: {
            HStack(spacing: 8) {
                Text("♫")
                if showsSong {
                    Text(songArtist.isEmpty ? songTitle : "\(songTitle) · \(songArtist)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(localized("记首歌"))
                }
            }
            .font(.subheadline)
            .foregroundStyle(theme.palette.strongAccent)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var photoAttachment: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(localized(photoData == nil ? "留张照片" : "更换照片"), systemImage: "photo.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(theme.palette.strongAccent)
                        .frame(minHeight: 44)
                }
                if isLoadingPhoto { ProgressView() }
                if photoData != nil {
                    Button(localized("删除照片"), role: .destructive) {
                        photoLoadTask?.cancel()
                        isLoadingPhoto = false
                        photoItem = nil
                        photoData = nil
                    }
                    .font(.footnote)
                    .frame(minHeight: 44)
                }
            }
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 140, maxHeight: 110, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(localized("照片"))
            }
        }
        .buttonStyle(.plain)
    }

    private var groupPicker: some View {
        ViewThatFits(in: .horizontal) {
            groupPickerRow
            ScrollView(.horizontal) {
                groupPickerRow
            }
            .scrollIndicators(.hidden)
        }
    }

    private var groupPickerRow: some View {
        HStack(spacing: 4) {
            ForEach(ChoiceGroup.allCases) { group in
                Button {
                    selectedGroup = group
                } label: {
                    Text(group.title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .font(.subheadline.weight(selectedGroup == group ? .semibold : .regular))
                        .foregroundStyle(selectedGroup == group ? Color.primary : Color(white: 0.44))
                        .background(alignment: .bottom) {
                            if selectedGroup == group {
                                GroupHighlightBrush()
                                    .fill(theme.palette.accent.opacity(0.24))
                                    .padding(.horizontal, -7)
                                    .frame(height: 15)
                                    .offset(y: 2)
                                    .accessibilityHidden(true)
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if !hasPremiumAccess && group != .mood && group != .activity && group != .company {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .offset(x: 13)
                            }
                        }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, hasPremiumAccess ? 6 : 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
            }
        }
        .padding(4)
    }

    private var choicePicker: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(DailyChoice.choices(in: selectedGroup)) { choice in
                let isAvailable = canUse(choice)
                Button {
                    if isAvailable {
                        selectedChoice = choice
                    } else {
                        isMembershipPresented = true
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            ChoiceArtwork(choice: choice)
                                .scaledToFit()
                                .frame(height: 32)
                                .scaleEffect(selectedGroup == .mood ? 1 : choice == .cake ? 1 : choice == .study ? 1.38 : selectedGroup == .company ? 1.32 : 1.22)
                                .accessibilityHidden(true)


                        }
                        Text(choice.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 30, alignment: .top)
                        Circle()
                            .fill(theme.palette.strongAccent)
                            .frame(width: 6, height: 6)
                            .opacity(selectedChoice == choice ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAvailable ? "\(choice.title)，\(choice.caption)" : localized("%@，%@，需要会员", String(describing: choice.title), String(describing: choice.caption)))
                .accessibilityAddTraits(selectedChoice == choice ? .isSelected : [])
            }
        }
        .padding(10)
        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private var editorHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                editorTitle.fixedSize()
                Spacer(minLength: 0)
                if let choice = selectedChoice, choice.group == selectedGroup {
                    Text(choice.caption)
                        .font(.footnote)
                        .foregroundStyle(theme.palette.strongAccent)
                        .fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                editorTitle
                if let choice = selectedChoice, choice.group == selectedGroup {
                    Text(choice.caption)
                        .font(.footnote)
                        .foregroundStyle(theme.palette.strongAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorTitle: some View {
        Text(DayKey(day).relationToToday == .today ? localized("今天想记什么？") : localized("这一天想记什么？"))
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private var captionForSelectedChoice: String {
        guard let selectedChoice, selectedChoice.group == selectedGroup else { return " " }
        return selectedChoice.caption
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsNote {
                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)
                    .focused($isNoteFocused)
                    .frame(minHeight: 130)
                    .accessibilityLabel(localized("文字记录"))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("写文字"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(localized("文字可选。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(localized("写文字"))
            }
            if showsNote {
                Text(localized("文字可选。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 22)
                    .fill(selectedPaper.color(for: theme, scheme: colorScheme))
                    .preference(
                        key: NoteCardFramePreferenceKey.self,
                        value: proxy.frame(in: .named("EntryEditor"))
                    )
            }
        }
        .overlay {
            if !showsNote {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: 22))
                    .onTapGesture { beginNoteEditing() }
            }
        }
    }

    private func beginNoteEditing() {
        showsNote = true
        DispatchQueue.main.async {
            isNoteFocused = true
        }
    }

    private var paperPicker: some View {
        Button { isPaperPickerPresented = true } label: {
            HStack(spacing: 10) {
                Text(localized("色纸"))
                Spacer()
                Circle()
                    .fill(selectedPaper.swatchAccent(for: theme))
                    .frame(width: 20, height: 20)
                Text(selectedPaper.title)
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let selectedChoice else { return }
        let savedNote = (showsNote ? note : "").trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPaper = CardPaper.resolve(entry?.cardPaperID)
        let initialPaper = savedPaper == .original ? CardPaper.matching(theme) : savedPaper
        let savedSong = showsSong ? songTitle.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let savedArtist = showsSong ? songArtist.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let hasChanges = selectedChoice != entry?.choice || savedNote != (entry?.note ?? "") || photoData != entry?.photoData || selectedPaper != initialPaper || savedSong != (entry?.songTitle ?? "") || savedArtist != (entry?.songArtist ?? "")
        do {
            try EntryStore(context: modelContext).save(
                day: DayKey(day), choice: selectedChoice, note: showsNote ? note : "",
                isMember: hasPremiumAccess, photoData: photoData, updatesPhoto: true,
                cardPaperID: selectedPaper.rawValue,
                updatesCardPaper: true,
                songTitle: savedSong, songArtist: savedArtist, updatesSong: true
            )
            onSaved(selectedChoice, hasChanges)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SongEditorOverlay: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var artist: String
    private enum Field: Hashable { case title, artist }
    @FocusState private var focusedField: Field?
    private let hasSong: Bool
    let isToday: Bool
    let onClose: () -> Void
    let onSave: (String, String) -> Void

    init(title: String, artist: String, isToday: Bool, onClose: @escaping () -> Void,
         onSave: @escaping (String, String) -> Void) {
        _title = State(initialValue: title)
        _artist = State(initialValue: artist)
        hasSong = !title.isEmpty
        self.isToday = isToday
        self.onClose = onClose
        self.onSave = onSave
    }

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { focusedField = nil }
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                player.padding(24)
                ScrollView { player.padding(24) }
            }
        }
        .tint(theme.palette.strongAccent)
        .accessibilityAddTraits(.isModal)
    }

    private var player: some View {
        VStack(spacing: 0) {
            HStack {
                if hasSong {
                    Button(localized("移除歌曲")) { onSave("", "") }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .accessibilityLabel(localized("取消"))
            }
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                TextField(localized("歌曲名"), text: $title,
                          prompt: Text(localized("歌曲名"))
                            .foregroundColor(theme.palette.foreground.opacity(0.48)),
                          axis: .vertical)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(theme.palette.foreground)
                    .lineLimit(1...2)
                    .truncationMode(.tail)
                    .accessibilityLabel(localized("歌曲名"))
                    .focused($focusedField, equals: .title)
                    .padding(.bottom, 2)
                TextField(localized("歌手（选填）"), text: $artist,
                          prompt: Text(localized("歌手（选填）"))
                            .foregroundColor(theme.palette.foreground.opacity(0.40)))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(localized("歌手（选填）"))
                    .focused($focusedField, equals: .artist)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.palette.playerScreenBackground.shadow(
                        .inner(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06),
                               radius: 2, x: 0, y: 1)
                    ))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(LinearGradient(
                                colors: [theme.palette.playerScreenTopEdge, theme.palette.playerScreenBottomEdge],
                                startPoint: .top, endPoint: .bottom
                            ), lineWidth: 0.75)
                    }
            }
            .overlay(alignment: .top) {
                Text(isToday ? localized("今天在听") : localized("这一天在听"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.palette.strongAccent)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 22) {
                speaker
                confirmationWheel
                speaker
            }
            .padding(.top, 24)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .background {
            RoundedRectangle(cornerRadius: 36)
                .fill(theme.palette.playerBody)
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }
        .frame(maxWidth: 360)
    }

    private var confirmationWheel: some View {
        ZStack {
            Circle()
                .fill(colorScheme == .dark ? Color(white: 0.23) : Color(white: 0.95))
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.14), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.10), radius: 2, y: 2)
                .accessibilityHidden(true)

            VStack {
                Text(verbatim: "MENU")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                Spacer()
                Image(systemName: "playpause.fill")
                    .font(.system(size: 9))
            }
            .padding(.vertical, 12)
            .foregroundStyle(theme.palette.strongAccent)
            .accessibilityHidden(true)
            .allowsHitTesting(false)

            HStack {
                Image(systemName: "backward.end.fill")
                Spacer()
                Image(systemName: "forward.end.fill")
            }
            .font(.system(size: 9))
            .padding(.horizontal, 12)
            .foregroundStyle(theme.palette.strongAccent)
            .accessibilityHidden(true)
            .allowsHitTesting(false)

            Button {
                PlayerButtonFeedback.play()
                onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                       artist.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                Text(localized("确认"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.palette.strongAccent)
                    .frame(width: 54, height: 54)
                    .contentShape(Circle())
            }
            .buttonStyle(PlayerCenterButtonStyle())
            .disabled(isTitleEmpty)
            .opacity(isTitleEmpty ? 0.45 : 1)
        }
        .frame(width: 120, height: 120)
        .onAppear { PlayerButtonFeedback.prepare() }
    }

    private var speaker: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { _ in
                Capsule().fill(theme.palette.foreground.opacity(0.12))
                    .frame(width: 3, height: 15)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PlayerCenterButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(white: 0.34), Color(white: 0.24)]
                            : [.white, Color(white: 0.88)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay { Circle().strokeBorder(.primary.opacity(0.16), lineWidth: 0.7) }
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.18),
                            radius: configuration.isPressed ? 0 : 2,
                            y: configuration.isPressed ? 0 : 2)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PaperDialPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedPaper: CardPaper
    @State private var rotation = 0.0
    @State private var lastDragAngle: Double?
    private let papers = CardPaper.allCases.filter { $0 != .original }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
                        .frame(width: 210, height: 210)
                    ZStack {
                        ForEach(Array(papers.enumerated()), id: \.element.id) { index, paper in
                            let angle = Double(index) * .pi / 4
                            Button { select(index) } label: {
                                Circle()
                                    .fill(paper.swatchAccent(for: theme))
                                    .frame(width: 38, height: 38)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .position(x: 140 + sin(angle) * 105, y: 140 - cos(angle) * 105)
                        }
                    }
                    .rotationEffect(.degrees(rotation))
                    VStack(spacing: 8) {
                        Text(selectedPaper.title)
                            .font(.headline.weight(.medium))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 280, height: 280)
                .contentShape(Circle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            let x = Double(value.location.x - 140)
                            let y = Double(value.location.y - 140)
                            guard hypot(x, y) > 35 else { return }
                            let angle = atan2(y, x) * 180 / .pi
                            let previous = lastDragAngle ?? atan2(
                                Double(value.startLocation.y - 140),
                                Double(value.startLocation.x - 140)
                            ) * 180 / .pi
                            var delta = angle - previous
                            if delta > 180 { delta -= 360 }
                            if delta < -180 { delta += 360 }
                            rotation += delta
                            updateSelection()
                            lastDragAngle = angle
                        }
                        .onEnded { _ in
                            lastDragAngle = nil
                            withAnimation(.easeOut(duration: 0.2)) {
                                rotation = (rotation / 45).rounded() * 45
                            }
                            updateSelection()
                        }
                )
                .overlay(alignment: .top) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 6))
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground.opacity(0.55))
                        .offset(y: -2)
                        .allowsHitTesting(false)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(localized("色纸"))
                .accessibilityValue(selectedPaper.title)
                .accessibilityAdjustableAction { direction in
                    let index = papers.firstIndex(of: selectedPaper) ?? 0
                    switch direction {
                    case .increment: select((index + 1) % papers.count)
                    case .decrement: select((index + papers.count - 1) % papers.count)
                    @unknown default: break
                    }
                }

                Text(localized("转动或轻点选色"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedPaper.color(for: theme, scheme: colorScheme))
                    .frame(height: 52)
                    .overlay { Text(selectedPaper.title).font(.subheadline) }
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.resolved(for: colorScheme).background)
            .navigationTitle(localized("色纸"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("完成")) { dismiss() }
                }
            }
            .tint(theme.palette.strongAccent)
        }
        .presentationDetents([.height(470)])
        .presentationDragIndicator(.visible)
        .onAppear { rotation = -Double(papers.firstIndex(of: selectedPaper) ?? 0) * 45 }
    }

    private func updateSelection() {
        let index = Int((-rotation / 45).rounded())
        selectedPaper = papers[(index % papers.count + papers.count) % papers.count]
    }

    private func select(_ index: Int) {
        var delta = (-Double(index) * 45 - rotation).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        withAnimation(.easeInOut(duration: 0.2)) {
            rotation += delta
            selectedPaper = papers[index]
        }
    }
}

private struct GroupHighlightBrush: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.height * 0.18))
        path.addCurve(to: CGPoint(x: rect.maxX - 1, y: rect.height * 0.10),
                      control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.02),
                      control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.height * 0.90))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.85),
                      control1: CGPoint(x: rect.width * 0.65, y: rect.height * 0.78),
                      control2: CGPoint(x: rect.width * 0.25, y: rect.height * 1.02))
        path.closeSubpath()
        return path
    }
}

private enum PhotoLoadError: Error { case invalidImage }
