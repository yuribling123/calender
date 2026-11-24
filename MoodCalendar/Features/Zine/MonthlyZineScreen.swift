/* 暂时停用：界面实现保留，恢复时同时取消对应入口的注释。
import SwiftUI
import SwiftData
import UIKit

/// A small, editable edition made from real memories. Export and preview use the same bitmap.
struct MonthlyZineScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entries: [MoodEntry]
    @Query private var monthlyNotes: [MonthlyNote]
    @State private var store: MonthlyZineDraftStore
    @State private var month: Date
    @State private var draft = MonthlyZineDraft()
    @State private var lastSavedDraft = MonthlyZineDraft()
    @State private var hasLoaded = false
    @State private var previewImage: UIImage?
    @State private var renderFailed = false
    @State private var exportItem: ZineExportItem?
    @State private var lastSharedURL: URL?
    @State private var errorMessage: String?
    @State private var savedMessage = false
    @State private var isChoosingMemories = false
    @State private var isChoosingPhoto = false
    @FocusState private var isWriting: Bool

    init(initialMonth: Date = .now, draftStore: MonthlyZineDraftStore? = nil) {
        let calendar = Calendar.current
        let current = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let proposed = calendar.dateInterval(of: .month, for: initialMonth)?.start ?? current
        _month = State(initialValue: min(proposed, current))
        _store = State(initialValue: draftStore ?? .applicationStore(isDemo: DemoData.isEnabled))
    }

    private var key: String { MonthlyZine.monthKey(month) }
    private var memories: [MoodEntry] { MonthlyZine.memories(in: month, entries: entries) }
    private var photoMemories: [MoodEntry] { memories.filter { $0.photoData.flatMap(UIImage.init(data:)) != nil } }
    private var selectedMemories: [MoodEntry] {
        memories.filter { draft.selectedDayKeys.contains($0.dayKey) }
    }
    private var monthlyNote: String {
        monthlyNotes.filter { $0.monthKey == key }.max { $0.updatedAt < $1.updatedAt }?.text ?? ""
    }
    private var monthOptions: [Date] {
        let current = MonthlyZine.monthKey(.now)
        let savedKeys = (try? store.exportDrafts().keys.map { $0 }) ?? []
        let keys = Set(entries.map { String($0.dayKey.prefix(7)) } + monthlyNotes.map(\.monthKey) + savedKeys + [current, key])
        return keys.filter { $0 <= current }.compactMap { MonthlyZine.date(for: $0) }.sorted(by: >)
    }
    private var canExport: Bool {
        !selectedMemories.isEmpty
            || draft.showsWriting && !draft.introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || draft.showsPhoto && photoMemories.contains { $0.dayKey == draft.photoDayKey }
            || draft.showsMusic && latestSong != nil
            || draft.showsWatch && latestWatch != nil
    }
    private var previewIdentity: ZinePreviewIdentity {
        ZinePreviewIdentity(
            monthKey: key,
            source: memories.map { ZineSourceRevision(id: $0.id, dayKey: $0.dayKey, updatedAt: $0.updatedAt) },
            draft: draft,
            theme: theme.rawValue,
            isDark: colorScheme == .dark,
            language: AppLanguage.selection,
            hasLoaded: hasLoaded
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    introduction
                    monthPicker
                    preview
                    editor
                    memorySelection
                    presentationSettings
                    exportAction
                }
                .padding(24)
                .iPadReadableWidth(680)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.palette.resolved(for: colorScheme).background.ignoresSafeArea())
            .navigationTitle(localized("本月小刊"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("完成")) {
                        isWriting = false
                        if store.loadError != nil || saveDraft() { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("存草稿")) {
                        isWriting = false
                        if saveDraft() { savedMessage = true }
                    }
                    .disabled(!hasLoaded || store.loadError != nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if savedMessage {
                    Text(localized("小刊草稿已保存"))
                        .font(.footnote)
                        .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 10)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .interactiveDismissDisabled(store.loadError == nil && hasLoaded && draft != lastSavedDraft)
        .onAppear {
            guard !hasLoaded else { return }
            loadDraft()
            if let error = store.loadError { errorMessage = error.localizedDescription }
        }
        .onChange(of: draft) { _, _ in savedMessage = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, hasLoaded, draft != lastSavedDraft { _ = saveDraft() }
        }
        .onChange(of: previewIdentity) { _, _ in
            // A deleted source record must disappear from the composition immediately.
            let sanitized = MonthlyZine.sanitized(draft, availableDayKeys: memories.map(\.dayKey), photoDayKeys: photoMemories.map(\.dayKey))
            if sanitized != draft { draft = sanitized }
        }
        .task(id: previewIdentity) {
            guard hasLoaded else { return }
            // Coalesce edits, and let the sheet appear before rendering the bitmap.
            // Only value changes restart this task; assigning previewImage does not.
            do { try await Task.sleep(for: .milliseconds(180)) }
            catch { return }
            guard !Task.isCancelled else { return }
            renderPreview()
        }
        .sheet(item: $exportItem, onDismiss: {
            if let lastSharedURL { try? FileManager.default.removeItem(at: lastSharedURL) }
            lastSharedURL = nil
        }) { item in
            ZineShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .alert(localized("本月小刊"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button(localized("确定"), role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("把这个月，订成一小页"))
                .font(.title3.weight(.medium))
                .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
            Text(localized("挑几天、留一句话。预览中的内容，就是导出的样子。"))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var monthPicker: some View {
        HStack {
            Text(localized("这一期"))
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Menu {
                ForEach(monthOptions, id: \.self) { date in
                    Button {
                        guard MonthlyZine.monthKey(date) != key else { return }
                        guard saveDraft() else { return }
                        month = date
                        loadDraft()
                    } label: {
                        if MonthlyZine.monthKey(date) == key {
                            Label(date.formatted(.dateTime.locale(AppLanguage.locale).year().month()), systemImage: "checkmark")
                        } else {
                            Text(date.formatted(.dateTime.locale(AppLanguage.locale).year().month()))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(month.formatted(.dateTime.locale(AppLanguage.locale).year().month()))
                    Image(systemName: "chevron.down").font(.caption.weight(.medium))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.palette.strongAccent)
                .frame(minHeight: 44)
            }
            .accessibilityLabel(localized("选择小刊月份"))
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("小刊预览")).font(.caption.weight(.medium))
                Spacer()
                Text(localized("仅选中的内容会被导出"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: theme.palette.collectionShadow, radius: 9, x: 0, y: 4)
                    .accessibilityLabel(localized("小刊预览"))
                    .accessibilityValue(accessiblePreview)
            } else if renderFailed {
                VStack(spacing: 14) {
                    Text(localized("未能生成小刊图片，请稍后再试。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(localized("重试")) { renderPreview() }
                        .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 240)
            }
            if !canExport {
                Text(localized("还没有选择内容。可以挑几个日子，或打开文字开关写一句寄语。"))
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(localized("封面文字"))
            TextField(localized("给这一期起个名字"), text: $draft.title, axis: .vertical)
                .font(.body).focused($isWriting)
                .padding(14)
                .background(theme.palette.notebookPaper, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: draft.title) { _, value in draft.title = String(value.prefix(MonthlyZine.titleLimit)) }
                .accessibilityLabel(localized("小刊标题"))
            Text(localized("标题最多 %d 字", MonthlyZine.titleLimit))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(localized("展示文字与月便签"), isOn: $draft.showsWriting)
                .font(.subheadline)
            if draft.showsWriting {
                TextField(localized("给这个月留一句话"), text: $draft.introduction, axis: .vertical)
                    .font(.body).lineLimit(3...7).focused($isWriting)
                    .padding(14)
                    .background(theme.palette.notebookPaper, in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: draft.introduction) { _, value in
                        draft.introduction = String(value.prefix(MonthlyZine.introductionLimit))
                    }
                    .accessibilityLabel(localized("小刊寄语"))
                HStack(alignment: .firstTextBaseline) {
                    Text(localized("只修改小刊草稿，不改动原来的记录。"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text("\(draft.introduction.count)/\(MonthlyZine.introductionLimit)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .tint(theme.palette.strongAccent)
    }

    private var memorySelection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(localized("挑几个日子"))
                Spacer()
                Text("\(draft.selectedDayKeys.count)/\(MonthlyZine.maximumMemories)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if memories.isEmpty {
                Text(localized("这个月还没有每日记录"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                DisclosureGroup(isExpanded: $isChoosingMemories) {
                    VStack(spacing: 0) {
                        ForEach(memories, id: \.dayKey) { memory in memoryRow(memory) }
                    }.padding(.top, 10)
                } label: {
                    Text(localized("选择最多三个日子"))
                        .font(.subheadline).foregroundStyle(theme.palette.strongAccent)
                        .frame(minHeight: 44)
                }
                Text(localized("文字开启时，每个日子展示一段短摘录；省略处以 … 标明。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func memoryRow(_ memory: MoodEntry) -> some View {
        let selected = draft.selectedDayKeys.contains(memory.dayKey)
        let disabled = !selected && draft.selectedDayKeys.count >= MonthlyZine.maximumMemories
        return Button {
            if selected { draft.selectedDayKeys.removeAll { $0 == memory.dayKey } }
            else if !disabled { draft.selectedDayKeys.append(memory.dayKey) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.palette.strongAccent : .secondary)
                if let choice = memory.choice {
                    ChoiceArtwork(choice: choice).scaledToFit().frame(width: 42, height: 35)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayLabel(memory.dayKey)).font(.subheadline.weight(.medium))
                    Text(MonthlyZine.excerpt(DemoData.displayText(memory.note).isEmpty
                                              ? memory.choice?.title ?? "" : DemoData.displayText(memory.note), limit: 40))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
            .padding(.vertical, 10)
            .frame(minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel("\(dayLabel(memory.dayKey)), \(memory.choice?.title ?? "")")
        .accessibilityValue(MonthlyZine.excerpt(DemoData.displayText(memory.note), limit: 40))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var presentationSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(localized("想放进小刊的"))
            Toggle(localized("展示一张照片"), isOn: $draft.showsPhoto)
                .disabled(photoMemories.isEmpty)
            if draft.showsPhoto, !photoMemories.isEmpty {
                DisclosureGroup(isExpanded: $isChoosingPhoto) {
                    VStack(spacing: 8) {
                        ForEach(photoMemories, id: \.dayKey) { memory in
                            Button {
                                draft.photoDayKey = memory.dayKey
                            } label: {
                                HStack(spacing: 12) {
                                    if let data = memory.photoData, let image = UIImage(data: data) {
                                        Image(uiImage: image).resizable().scaledToFit()
                                            .frame(width: 54, height: 54)
                                    }
                                    Text(dayLabel(memory.dayKey)).font(.subheadline)
                                    Spacer()
                                    if draft.photoDayKey == memory.dayKey {
                                        Image(systemName: "checkmark").foregroundStyle(theme.palette.strongAccent)
                                    }
                                }
                                .padding(.vertical, 6).frame(minHeight: 54)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(localized("选择 %@ 的照片", dayLabel(memory.dayKey)))
                            .accessibilityAddTraits(draft.photoDayKey == memory.dayKey ? .isSelected : [])
                        }
                    }.padding(.top, 8)
                } label: {
                    Text(draft.photoDayKey.map(dayLabel) ?? localized("选择照片"))
                        .font(.subheadline).foregroundStyle(theme.palette.strongAccent)
                        .frame(minHeight: 44)
                }
            }
            if photoMemories.isEmpty {
                Text(localized("这个月还没有照片"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle(localized("展示最近记下的一首歌"), isOn: $draft.showsMusic)
                .disabled(latestSong == nil)
            Toggle(localized("展示最近记下的一部影视"), isOn: $draft.showsWatch)
                .disabled(latestWatch == nil)
            Text(localized("文字和照片默认不展示；打开开关后才会出现在预览与导出中。"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .tint(theme.palette.strongAccent)
    }

    private var exportAction: some View {
        VStack(spacing: 12) {
            Button(action: export) {
                Label(localized("导出这一期"), systemImage: "square.and.arrow.up")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(theme.palette.todayButtonFill, in: Capsule())
            }
            .disabled(!canExport || previewImage == nil || store.loadError != nil)
            .opacity(canExport ? 1 : 0.5)
            Text(localized("导出为图片，由你决定保存或分享给谁。"))
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var latestSong: MoodEntry? {
        memories.last { !($0.songTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var latestWatch: MoodEntry? {
        memories.last { !($0.watchTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var accessiblePreview: String {
        var parts = [month.formatted(.dateTime.locale(AppLanguage.locale).year().month()),
                     draft.title.isEmpty ? localized("这一月，慢慢收藏") : draft.title,
                     localized("留下 %d 个日子", memories.count)]
        if draft.showsWriting { parts.append(draft.introduction) }
        for memory in selectedMemories {
            parts.append(dayLabel(memory.dayKey) + ", " + (memory.choice?.title ?? ""))
            if draft.showsWriting { parts.append(MonthlyZine.excerpt(DemoData.displayText(memory.note), limit: 90)) }
        }
        if draft.showsPhoto, let key = draft.photoDayKey { parts.append(localized("%@ 的照片", dayLabel(key))) }
        if draft.showsMusic, let song = latestSong { parts.append(song.songTitle ?? "") }
        if draft.showsWatch, let watch = latestWatch { parts.append(watch.watchTitle ?? "") }
        return parts.joined(separator: "。")
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium))
            .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
            .accessibilityAddTraits(.isHeader)
    }

    private func dayLabel(_ key: String) -> String {
        MonthlyZine.dayDate(key)?.formatted(.dateTime.locale(AppLanguage.locale).month().day()) ?? key
    }

    private func loadDraft() {
        let saved = store.draft(for: key)
        var value = saved ?? MonthlyZineDraft()
        if saved == nil {
            value.introduction = String(DemoData.displayText(monthlyNote).prefix(MonthlyZine.introductionLimit))
            // Start with a small, chronological selection. Users can replace every item.
            value.selectedDayKeys = Array(memories.suffix(MonthlyZine.maximumMemories).map(\.dayKey))
            value.photoDayKey = photoMemories.last?.dayKey
        }
        draft = MonthlyZine.sanitized(value, availableDayKeys: memories.map(\.dayKey), photoDayKeys: photoMemories.map(\.dayKey))
        lastSavedDraft = draft
        hasLoaded = true
        savedMessage = false
    }

    @discardableResult
    private func saveDraft() -> Bool {
        guard hasLoaded else { return true }
        do {
            let value = MonthlyZine.sanitized(draft, availableDayKeys: memories.map(\.dayKey), photoDayKeys: photoMemories.map(\.dayKey))
            try store.save(value, for: key)
            draft = value
            lastSavedDraft = value
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func renderPreview() {
        let poster = MonthlyZinePoster(month: month, draft: draft, memories: selectedMemories,
                                       recordedCount: memories.count,
                                       photo: photoMemories.first { $0.dayKey == draft.photoDayKey },
                                       song: latestSong, watch: latestWatch)
            .environment(\.appTheme, theme)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, AppLanguage.locale)
            .environment(\.dynamicTypeSize, .large)
            .frame(width: 600)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 2
        renderer.isOpaque = true
        previewImage = renderer.uiImage
        renderFailed = previewImage == nil
    }

    @MainActor
    private func export() {
        isWriting = false
        guard saveDraft() else { return }
        // Render synchronously again so the shared bitmap always matches the final settings.
        renderPreview()
        guard let image = previewImage, let data = image.pngData() else {
            errorMessage = localized("未能生成小刊图片，请稍后再试。")
            return
        }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoodCalendar-Zines", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Clean abandoned share files from earlier runs, without removing an active share.
            let staleBefore = Date().addingTimeInterval(-86_400)
            for file in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modified < staleBefore { try? FileManager.default.removeItem(at: file) }
            }
            let url = directory.appendingPathComponent("Little-Today-\(key)-\(UUID().uuidString.prefix(8)).png")
            try data.write(to: url, options: .atomic)
            lastSharedURL = url
            exportItem = ZineExportItem(url: url)
        } catch { errorMessage = error.localizedDescription }
    }
}

/// Task identity must use value equality: JSON object key order is not stable.
/// Renderer output and other presentation state deliberately stay out of this value.
private struct ZinePreviewIdentity: Equatable {
    let monthKey: String
    let source: [ZineSourceRevision]
    let draft: MonthlyZineDraft
    let theme: String
    let isDark: Bool
    let language: String
    let hasLoaded: Bool
}

private struct ZineSourceRevision: Equatable {
    let id: UUID
    let dayKey: String
    let updatedAt: Date
}

private struct ZineExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ZineShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

*/
