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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var groupPickerViewport: CGRect = .zero
    @State private var groupContentFrame: CGRect = .zero
    @State private var groupButtonFrames: [ChoiceGroup: CGRect] = [:]
    @ScaledMetric(relativeTo: .subheadline) private var groupFontSize: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var note = ""
    @State private var locationName = ""
    @State private var showsNote = false
    @AppStorage("lastSelectedCardPaper") private var lastSelectedCardPaper = ""
    @State private var selectedPaper: CardPaper = .pink
    @State private var watchTitle = ""
    @State private var watchKind = ""
    @State private var watchNote = ""
    @State private var isWatchEditorPresented = false
    @State private var showsSong = false
    @State private var songTitle = ""
    @State private var songArtist = ""
    @State private var isSongEditorPresented = false
    @State private var isPaperPickerPresented = false
    @State private var paperBeforePreview: CardPaper = .pink
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var errorTitle = localized("保存失败")
    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @State private var isMembershipPresented = false
    @State private var noteCardFrame: CGRect = .zero
    @FocusState private var isNoteFocused: Bool

    private var hasPremiumAccess: Bool { membership.hasMembershipAccess }

    private func canUse(_ choice: DailyChoice) -> Bool {
        hasPremiumAccess || !choice.group.requiresMembership
    }

    var body: some View {
        NavigationStack {
            AdaptivePage { size in
                ScrollView {
                    if let size, size.width >= 700, !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 20) {
                                editorHeading
                                groupPicker
                                choicePicker
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            VStack(alignment: .leading, spacing: 20) {
                                noteCard
                                locationAttachment
                                songAttachment
                                watchAttachment
                                photoAttachment
                                paperPicker
                                deleteEntryAction
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .padding(28)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            editorHeading

                            groupPicker

                            choicePicker

                            noteCard

                            locationAttachment

                            songAttachment

                            watchAttachment

                            photoAttachment

                            paperPicker

                            deleteEntryAction
                        }
                        .padding(24)
                    }
                }
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
            .alert(errorTitle, isPresented: Binding(
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
            .sheet(isPresented: $isPaperPickerPresented, onDismiss: {
                if selectedPaper.requiresMembership && !hasPremiumAccess {
                    selectedPaper = paperBeforePreview
                    isMembershipPresented = true
                } else {
                    lastSelectedCardPaper = selectedPaper.rawValue
                }
            }) {
                PaperDialPicker(selectedPaper: Binding(
                    get: { selectedPaper },
                    set: { paper in
                        selectedPaper = paper
                    }
                ))
                .environmentObject(membership)
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
                selectedChoice = entry?.choice ?? .veryGood
                selectedGroup = selectedChoice?.group ?? initialGroup
                photoData = entry?.photoData
                note = entry?.note ?? ""
                locationName = entry?.locationName ?? ""
                showsNote = !(entry?.note.isEmpty ?? true)
                let savedPaper = CardPaper.resolve(entry == nil ? lastSelectedCardPaper : entry?.cardPaperID)
                selectedPaper = entry == nil && savedPaper == .strawberryHearts
                    ? .blueberryHearts : (savedPaper == .original ? CardPaper.matching(theme) : savedPaper)
                if entry == nil && selectedPaper.requiresMembership && !hasPremiumAccess {
                    selectedPaper = .stars
                }
                songTitle = entry?.songTitle ?? ""
                songArtist = entry?.songArtist ?? ""
                showsSong = !songTitle.isEmpty
                watchTitle = entry?.watchTitle ?? ""
                watchKind = entry?.watchKind ?? ""
                watchNote = entry?.watchNote ?? ""
            }
        }
        .allowsHitTesting(!isSongEditorPresented && !isWatchEditorPresented && !showsDeleteConfirmation)
        .accessibilityHidden(isSongEditorPresented || isWatchEditorPresented || showsDeleteConfirmation)
        .overlay {
            if showsDeleteConfirmation {
                deleteConfirmation
            } else if isWatchEditorPresented {
                WatchEditorOverlay(title: watchTitle, kind: WatchKind(rawValue: watchKind) ?? .movie, onClose: {
                    isWatchEditorPresented = false
                }) { title, kind in
                    watchTitle = title
                    watchKind = kind.rawValue
                    if title.isEmpty {
                        watchKind = ""
                        watchNote = ""
                    }
                    isWatchEditorPresented = false
                }
            } else if isSongEditorPresented {
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

    @ViewBuilder
    private var deleteEntryAction: some View {
        if entry != nil && DayKey(day).isEditable(allowPastDates: allowPastDateEditing) {
            HStack {
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    isNoteFocused = false
                    showsDeleteConfirmation = true
                } label: {
                    Text(localized("删除"))
                        .font(.footnote)
                        .foregroundStyle(theme.palette.destructiveAction)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deleteConfirmation: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                deleteConfirmationCard.padding(24)
                ScrollView { deleteConfirmationCard.padding(24) }
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { showsDeleteConfirmation = false }
    }

    private var deleteConfirmationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("删除当天记录？"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(day.formatted(.dateTime.locale(AppLanguage.locale).year().month().day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(localized("当天的表情、文字、照片、歌曲和影视记录都会删除，且无法恢复。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    showsDeleteConfirmation = false
                } label: {
                    Text(localized("取消"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }
                Button(role: .destructive) {
                    showsDeleteConfirmation = false
                    deleteEntry()
                } label: {
                    Text(localized("删除"))
                        .foregroundStyle(theme.palette.destructiveAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(theme.palette.destructiveAction.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .font(.headline)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .foregroundStyle(theme.palette.foreground)
        .padding(20)
        .frame(maxWidth: 320)
        .background(theme.palette.resolved(for: colorScheme).background, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private var locationAttachment: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin")
                .accessibilityHidden(true)
            TextField(localized("添加地点"), text: $locationName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityLabel(localized("添加地点"))
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
                    Text(localized("记歌"))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var watchAttachment: some View {
        Button {
            isNoteFocused = false
            isWatchEditorPresented = true
        } label: {
            HStack(spacing: 8) {
                WatchTVIcon()
                    .frame(width: 19, height: 17)
                    .accessibilityHidden(true)
                Text(watchTitle.isEmpty ? localized("记影视") : watchTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !watchTitle.isEmpty {
                    Spacer(minLength: 8)
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(watchTitle.isEmpty ? localized("记影视") : "\(localized("记影视"))，\(watchTitle)")
    }

    private var photoAttachment: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(localized(photoData == nil ? "留照片" : "更换照片"), systemImage: "photo.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
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
                    .font(.caption)
                    .foregroundStyle(theme.palette.destructiveAction)
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

    // Spread complete initial items evenly; the scroll view still moves freely by touch.
    private var groupItemSpacing: CGFloat {
        var usedWidth: CGFloat = 0
        var count = 0
        for group in ChoiceGroup.allCases {
            let width = groupButtonWidth(group)
            guard usedWidth + width + CGFloat(count) * 6 <= groupPickerViewport.width else { break }
            usedWidth += width
            count += 1
        }
        guard count > 1 else { return 6 }
        return max(6, (groupPickerViewport.width - usedWidth) / CGFloat(count - 1))
    }

    private func groupButtonWidth(_ group: ChoiceGroup) -> CGFloat {
        let font = UIFont.systemFont(ofSize: groupFontSize,
                                     weight: selectedGroup == group ? .medium : .regular)
        let titleWidth = (group.title as NSString).size(withAttributes: [.font: font]).width
        return max(44, ceil(titleWidth) + 10)
    }

    private var groupPicker: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 6) {
                groupScrollArrow(forward: false, proxy: proxy)
                ScrollView(.horizontal) {
                    groupPickerRow
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                            groupContentFrame = $0
                        }
                }
                .scrollIndicators(.hidden)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    groupPickerViewport = $0
                }
                groupScrollArrow(forward: true, proxy: proxy)
            }
        }
    }

    private func moveGroupPage(forward: Bool, proxy: ScrollViewProxy) {
        let viewport = groupPickerViewport
        guard !viewport.isEmpty, !groupContentFrame.isEmpty else { return }
        guard forward ? groupContentFrame.maxX > viewport.maxX + 1
                      : groupContentFrame.minX < viewport.minX - 1 else { return }
        let groups = ChoiceGroup.allCases
        let fullyVisible = groups.filter { group in
            guard let frame = groupButtonFrames[group] else { return false }
            return frame.minX >= viewport.minX - 1 && frame.maxX <= viewport.maxX + 1
        }
        let intersecting = groups.filter { group in
            guard let frame = groupButtonFrames[group] else { return false }
            return frame.maxX > viewport.minX && frame.minX < viewport.maxX
        }
        guard var target = forward ? (fullyVisible.last ?? intersecting.last)
                                   : (fullyVisible.first ?? intersecting.first),
              let frame = groupButtonFrames[target],
              let index = groups.firstIndex(of: target) else { return }
        // If only one item fits, advance instead of scrolling back to the same position.
        if forward && frame.minX <= viewport.minX + 1 && index + 1 < groups.count {
            target = groups[index + 1]
        } else if !forward && frame.maxX >= viewport.maxX - 1 && index > 0 {
            target = groups[index - 1]
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            proxy.scrollTo(target, anchor: forward ? .leading : .trailing)
        }
    }

    private func groupScrollArrow(forward: Bool, proxy: ScrollViewProxy) -> some View {
        Button {
            moveGroupPage(forward: forward, proxy: proxy)
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized(forward ? "查看更多分类" : "查看前面的分类"))
    }

    private var groupPickerRow: some View {
        HStack(spacing: groupItemSpacing) {
            ForEach(ChoiceGroup.allCases) { group in
                Button {
                    selectedGroup = group
                } label: {
                    Text(group.title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .font(.system(size: groupFontSize, weight: selectedGroup == group ? .medium : .regular))
                        .foregroundStyle(selectedGroup == group ? .primary : .secondary)
                        .padding(.horizontal, 5)
                        .frame(width: groupButtonWidth(group), height: max(44, groupFontSize * 1.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                .id(group)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    groupButtonFrames[group] = frame
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var choicePicker: some View {
        VStack(spacing: 0) {
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
                                    .scaleEffect(choicePickerArtworkScale(for: choice))
                                    .accessibilityHidden(true)


                            }
                            Text(choice.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                                .multilineTextAlignment(.center)
                            if isAvailable {
                                Circle()
                                    .fill(theme.palette.strongAccent)
                                    .frame(width: 6, height: 6)
                                    .opacity(selectedChoice == choice ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: isAvailable ? 74 : 0, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isAvailable ? "\(choice.title)，\(choice.caption)" : localized("%@，%@，需要会员", String(describing: choice.title), String(describing: choice.caption)))
                    .accessibilityAddTraits(selectedChoice == choice ? .isSelected : [])
                }
            }
            if !hasPremiumAccess && selectedGroup.requiresMembership {
                Text(localized("会员专享"))
                    .font(.caption)
                    .foregroundStyle(theme.palette.strongAccent)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, !hasPremiumAccess && selectedGroup.requiresMembership ? 0 : 10)
        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    /// Weather artwork has different silhouettes; tune visible subjects against the rainbow.
    private func choicePickerArtworkScale(for choice: DailyChoice) -> CGFloat {
        if choice == .wings { return 1.5 }
        return choice.weatherArtworkScale
            ?? (selectedGroup == .mood ? 1 : choice == .cake ? 1 : choice == .study ? 1.38 : selectedGroup == .company ? 1.32 : 1.22)
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
            .font(.title3.weight(.semibold))
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
                    Text(localized("文字可选"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(localized("写文字"))
            }
            if showsNote && isNoteFocused {
                Button(localized("确认")) { isNoteFocused = false }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(18)
        .background {
            GeometryReader { proxy in
                CardPaperBackground(paper: selectedPaper, cornerRadius: 22)
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
        .environment(\.colorScheme, selectedPaper == .nightHearts ? .dark : colorScheme)
    }

    private func beginNoteEditing() {
        showsNote = true
        DispatchQueue.main.async {
            isNoteFocused = true
        }
    }

    private var paperPicker: some View {
        Button {
            paperBeforePreview = selectedPaper
            isPaperPickerPresented = true
        } label: {
            HStack(spacing: 8) {
                Text(localized("色卡"))
                Circle()
                    .fill(selectedPaper == .nightHearts || selectedPaper.hasUnbackedStarPreview
                          ? Color.clear : (selectedPaper.isPatterned ? selectedPaper.color(for: theme) : selectedPaper.swatchAccent(for: theme)))
                    .overlay {
                        if selectedPaper.isHeartPattern {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(selectedPaper == .nightHearts ? Color(white: 0.24) : selectedPaper.heartInk)
                        } else if selectedPaper.isStarPattern {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(selectedPaper.previewStarInk)
                        }
                    }
                    .frame(width: 20, height: 20)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("色卡"))
        .accessibilityValue(selectedPaper.title)
    }

    private func deleteEntry() {
        do {
            try EntryStore(context: modelContext).delete(day: DayKey(day))
            dismiss()
        } catch {
            errorTitle = localized("删除失败")
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        errorTitle = localized("保存失败")
        guard let selectedChoice else { return }
        if selectedPaper.requiresMembership && !hasPremiumAccess && selectedPaper.rawValue != entry?.cardPaperID {
            isMembershipPresented = true
            return
        }
        let savedNote = (showsNote ? note : "").trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPaper = CardPaper.resolve(entry == nil ? lastSelectedCardPaper : entry?.cardPaperID)
        let initialPaper = entry == nil && savedPaper == .strawberryHearts
            ? CardPaper.blueberryHearts : (savedPaper == .original ? CardPaper.matching(theme) : savedPaper)
        let savedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedSong = showsSong ? songTitle.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let savedArtist = showsSong ? songArtist.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let savedWatch = watchTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedWatchNote = savedWatch.isEmpty ? "" : watchNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let watchChanged = savedWatch != (entry?.watchTitle ?? "") || (!savedWatch.isEmpty && watchKind != (entry?.watchKind ?? "")) || savedWatchNote != (entry?.watchNote ?? "")
        let hasChanges = savedLocation != (entry?.locationName ?? "") || watchChanged || selectedChoice != entry?.choice || savedNote != (entry?.note ?? "") || photoData != entry?.photoData || selectedPaper != initialPaper || savedSong != (entry?.songTitle ?? "") || savedArtist != (entry?.songArtist ?? "")
        do {
            try EntryStore(context: modelContext).save(
                day: DayKey(day), choice: selectedChoice, note: showsNote ? note : "",
                isMember: hasPremiumAccess, photoData: photoData, updatesPhoto: true,
                cardPaperID: selectedPaper.rawValue,
                updatesCardPaper: true,
                songTitle: savedSong, songArtist: savedArtist, updatesSong: true,
                watchTitle: savedWatch, watchKind: watchKind, watchNote: savedWatchNote, updatesWatch: true,
                locationName: savedLocation, updatesLocation: true
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
            GeometryReader { geometry in
                ScrollView {
                    player
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
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
                        .foregroundStyle(theme.palette.playerShellInk.opacity(0.65))
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
            .foregroundStyle(theme.palette.playerShellInk)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                TextField(localized("歌曲名"), text: $title,
                          prompt: Text(localized("歌曲名"))
                            .foregroundColor(theme.palette.foreground.opacity(0.56)),
                          axis: .vertical)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(theme.palette.foreground)
                    .lineLimit(1...2)
                    .truncationMode(.tail)
                    .accessibilityLabel(localized("歌曲名"))
                    .focused($focusedField, equals: .title)
                TextField(localized("歌手（选填）"), text: $artist,
                          prompt: Text(localized("歌手（选填）"))
                            .foregroundColor(theme.palette.foreground.opacity(0.50)))
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(localized("歌手（选填）"))
                    .focused($focusedField, equals: .artist)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 18)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.palette.musicPlayerScreenBackground.shadow(
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

            .padding(.horizontal, 12)

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
                .overlay {
                    RoundedRectangle(cornerRadius: 36)
                        .strokeBorder(theme.palette.playerBodyRim, lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }
        .frame(maxWidth: 360)
    }

    private var confirmationWheel: some View {
        ZStack {
            Circle()
                .fill(theme.palette.playerWheelBackground)
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
                Capsule().fill(theme.palette.playerShellInk.opacity(theme.palette.isObsidian ? 0.20 : 0.12))
                    .frame(width: 3, height: 15)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PlayerCenterButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(LinearGradient(
                        colors: [theme.palette.playerButtonTop, theme.palette.playerButtonBottom],
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

private enum PaperPickerKind: String, CaseIterable, Identifiable {
    case solid, patterned, hearts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .solid: localized("色纸")
        case .patterned: localized("星星")
        case .hearts: localized("爱心")
        }
    }
    var papers: [CardPaper] {
        CardPaper.allCases.filter { paper in
            switch self {
            case .solid: paper != .original && !paper.isPatterned
            case .patterned: paper.isStarPattern
            case .hearts: paper.isHeartPattern && paper != .strawberryHearts
            }
        }
    }
}

private struct PaperDialPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var kind: PaperPickerKind
    @EnvironmentObject private var membership: MembershipStore
    @Binding private var selectedPaper: CardPaper
    @State private var isMembershipPresented = false
    @State private var rotation = 0.0
    @State private var lastDragAngle: Double?
    private var papers: [CardPaper] { kind.papers }
    private var angleStep: Double { 360 / Double(papers.count) }
    // Opening another category previews its first paper without changing the user's selection.
    private var displayedPaper: CardPaper { papers.contains(selectedPaper) ? selectedPaper : papers[0] }

    init(selectedPaper: Binding<CardPaper>) {
        _selectedPaper = selectedPaper
        _kind = State(initialValue: selectedPaper.wrappedValue.isHeartPattern ? .hearts
            : selectedPaper.wrappedValue.isStarPattern ? .patterned : .solid)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 12) {
                Picker(localized("色卡"), selection: $kind) {
                    ForEach(PaperPickerKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 28)
                ZStack {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
                        .frame(width: 210, height: 210)
                    ZStack {
                        ForEach(Array(papers.enumerated()), id: \.element.id) { index, paper in
                            let angle = Double(index) * angleStep * .pi / 180
                            Button { select(index) } label: {
                                Circle()
                                    .fill(paper == .nightHearts || paper.hasUnbackedStarPreview
                                          ? Color.clear : (paper.isPatterned ? paper.color(for: theme) : paper.swatchAccent(for: theme)))
                                    .overlay {
                                        if paper.isHeartPattern {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 17))
                                                .foregroundStyle(paper == .nightHearts ? Color(white: 0.24) : paper.heartInk)
                                                .rotationEffect(.degrees(-rotation))
                                        } else if paper.isStarPattern {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 17))
                                                .foregroundStyle(paper.previewStarInk)
                                                .opacity(0.7)
                                                .blur(radius: 0.4)
                                                .rotationEffect(.degrees(-14))
                                                .rotationEffect(.degrees(-rotation))
                                        }
                                    }
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
                        if displayedPaper.requiresMembership && !membership.hasMembershipAccess {
                            Text(localized("会员专属"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(displayedPaper.title)
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
                                rotation = (rotation / angleStep).rounded() * angleStep
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
                .accessibilityLabel(kind.title)
                .accessibilityValue(displayedPaper.title + (displayedPaper.requiresMembership && !membership.hasMembershipAccess ? " · " + localized("会员专属") : ""))
                .accessibilityAdjustableAction { direction in
                    let index = papers.firstIndex(of: displayedPaper) ?? 0
                    switch direction {
                    case .increment: select((index + 1) % papers.count)
                    case .decrement: select((index + papers.count - 1) % papers.count)
                    @unknown default: break
                    }
                }

                Text(localized(kind == .solid ? "转动或轻点选色" : "转动或轻点选花纸"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.resolved(for: colorScheme).background)
            .navigationTitle(localized("色卡"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("完成")) {
                        guard !selectedPaper.requiresMembership || membership.hasMembershipAccess else {
                            isMembershipPresented = true
                            return
                        }
                        dismiss()
                    }
                }
            }
            .tint(theme.palette.strongAccent)
        }
        .sheet(isPresented: $isMembershipPresented) {
            MembershipScreen().environmentObject(membership)
        }
        .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.height(420), .large])
        .presentationDragIndicator(.visible)
        .onAppear { rotation = -Double(papers.firstIndex(of: displayedPaper) ?? 0) * angleStep }
        .onChange(of: kind) { _, _ in
            lastDragAngle = nil
            rotation = -Double(papers.firstIndex(of: displayedPaper) ?? 0) * angleStep
        }
    }

    private func updateSelection() {
        let index = Int((-rotation / angleStep).rounded())
        selectedPaper = papers[(index % papers.count + papers.count) % papers.count]
    }

    private func select(_ index: Int) {
        var delta = (-Double(index) * angleStep - rotation).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        withAnimation(.easeInOut(duration: 0.2)) {
            rotation += delta
            selectedPaper = papers[index]
        }
    }
}

private enum PhotoLoadError: Error { case invalidImage }

// A small rounded television keeps the entry as quiet as the music row.
struct WatchTVIcon: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 24, geometry.size.height / 18)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            ZStack {
                Path { path in
                    path.addRoundedRect(in: CGRect(x: 1, y: 1, width: 22, height: 16),
                                        cornerSize: CGSize(width: 4, height: 4))
                    path.addRoundedRect(in: CGRect(x: 4, y: 4, width: 12, height: 10),
                                        cornerSize: CGSize(width: 2, height: 2))
                }
                .applying(transform)
                .stroke(lineWidth: 1.5 * scale)
                Path { path in
                    path.addEllipse(in: CGRect(x: 19, y: 5, width: 2, height: 2))
                    path.addEllipse(in: CGRect(x: 19, y: 10, width: 2, height: 2))
                }
                .applying(transform)
                .fill()
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }
}

private struct WatchEditorOverlay: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State var title: String
    @State var kind: WatchKind
    @FocusState private var isTitleFocused: Bool
    private let hasRecord: Bool
    let onClose: () -> Void
    let onSave: (String, WatchKind) -> Void

    init(title: String, kind: WatchKind, onClose: @escaping () -> Void, onSave: @escaping (String, WatchKind) -> Void) {
        _title = State(initialValue: title)
        _kind = State(initialValue: kind)
        hasRecord = !title.isEmpty
        self.onClose = onClose
        self.onSave = onSave
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { isTitleFocused = false }
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                television.padding(24)
                ScrollView { television.padding(24) }
            }
        }
        .tint(theme.palette.strongAccent)
        .accessibilityAddTraits(.isModal)
    }

    private var television: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                screen
                VStack(spacing: 10) {
                    Button {
                        PlayerButtonFeedback.play()
                        onSave(trimmedTitle, kind)
                    } label: {
                        Text(localized(hasRecord ? "保存" : "记下"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.palette.strongAccent)
                            .frame(width: 52, height: 52)
                            .contentShape(Circle())
                    }
                    .buttonStyle(TelevisionKnobStyle())
                    .disabled(trimmedTitle.isEmpty)
                    .opacity(trimmedTitle.isEmpty ? 0.45 : 1)

                    Button(action: onClose) {
                        Text(localized("取消"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, height: 52)
                            .contentShape(Circle())
                    }
                    .buttonStyle(TelevisionKnobStyle())

                    VStack(spacing: 4) {
                        ForEach(0..<7) { _ in
                            Capsule()
                                .fill(theme.palette.playerShellInk.opacity(theme.palette.isObsidian ? 0.20 : 0.11))
                                .frame(height: 1.5)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.palette.foreground.opacity(0.025))
                    }
                    .accessibilityHidden(true)
                }
                .frame(width: 56)
                .padding(.top, 6)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 34)
                .fill(theme.palette.televisionBody)
                .overlay {
                    RoundedRectangle(cornerRadius: 34)
                        .strokeBorder(theme.palette.televisionBodyRim,
                                      lineWidth: theme.palette.isObsidian ? 0.75 : 1.5)
                }
                .shadow(color: .black.opacity(0.10), radius: 16, y: 7)
        }
        .frame(maxWidth: 400)
        .onAppear { PlayerButtonFeedback.prepare() }
    }

    private var screen: some View {
        VStack(spacing: 20) {
            Picker(localized("影视类型"), selection: $kind) {
                ForEach(WatchKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(localized("影视类型"))
            TextField(localized("片名"), text: $title,
                      prompt: Text(localized("片名"))
                        .foregroundColor(theme.palette.foreground.opacity(0.56)),
                      axis: .vertical)
                .font(.system(size: 21))
                .foregroundStyle(theme.palette.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(1...5)
                .textInputAutocapitalization(.never)
                .focused($isTitleFocused)
                .accessibilityLabel(localized("片名"))
                .frame(minHeight: 100)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, hasRecord ? 50 : 16)
        .frame(maxWidth: .infinity, minHeight: 204, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(theme.palette.televisionScreenBackground.shadow(
                    .inner(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.06),
                           radius: 3, x: 0, y: 2)
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(LinearGradient(
                            colors: [theme.palette.playerScreenTopEdge, theme.palette.playerScreenBottomEdge],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 0.75)
                }
        }
        .overlay(alignment: .bottomLeading) {
            if hasRecord {
                Button(localized("移除影视记录")) { onSave("", kind) }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .padding(.leading, 16)
                    .padding(.bottom, 6)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 34)
                .fill(theme.palette.foreground.opacity(0.055))
        }
    }
}

private struct TelevisionKnobStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(LinearGradient(
                        colors: [theme.palette.playerButtonTop, theme.palette.playerButtonBottom],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay {
                        Circle()
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.14),
                            radius: configuration.isPressed ? 0 : 2,
                            y: configuration.isPressed ? 0 : 2)
            }
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
