import SwiftUI
import SwiftData
#if ICLOUD_SYNC_ENABLED
import CloudKit
#endif
import UIKit
import UserNotifications

private struct CalendarTitleCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct ThemePaletteIcon: View {
    let theme: AppTheme

    private var palette: ThemePalette { theme.palette }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(palette.softHighlight)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                }
                .frame(width: 19, height: 19)
                .offset(x: 10, y: -7)

            RoundedRectangle(cornerRadius: 6)
                .fill(palette.strongAccent)
                .frame(width: 21, height: 21)
                .offset(x: 5, y: -3)

            RoundedRectangle(cornerRadius: 6)
                .fill(palette.accent)
                .frame(width: 23, height: 23)
        }
        .frame(width: 33, height: 30, alignment: .bottomLeading)
    }
}

private struct OutsideTapMonitor: UIViewRepresentable {
    let isActive: Bool
    let excludedFrame: CGRect
    let onOutsideTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isActive = isActive
        coordinator.excludedFrame = excludedFrame
        coordinator.onOutsideTap = onOutsideTap
        DispatchQueue.main.async {
            coordinator.attach(to: view.window)
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.attach(to: nil)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var window: UIWindow?
        var recognizer: UITapGestureRecognizer?
        var isActive = false
        var excludedFrame = CGRect.zero
        var onOutsideTap: () -> Void = {}

        func attach(to newWindow: UIWindow?) {
            guard window !== newWindow else { return }
            if let recognizer {
                window?.removeGestureRecognizer(recognizer)
            }
            window = newWindow
            guard let newWindow else { return }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            newWindow.addGestureRecognizer(tap)
            recognizer = tap
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            guard isActive, let window else { return false }
            return !excludedFrame.contains(touch.location(in: window))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func handleTap() {
            guard isActive else { return }
            onOutsideTap()
        }
    }
}

struct PersonalizationScreen: View {
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @EnvironmentObject private var membership: MembershipStore
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("calendarBookmarkStyle") private var storedBookmarkStyle = CalendarBookmarkStyle.dateColor.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.circle.rawValue
    #if ICLOUD_SYNC_ENABLED
    @AppStorage("icloudSyncEnabled") private var isICloudSyncEnabled = false
    #endif
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @AppStorage("dailyReminderEnabled") private var isDailyReminderEnabled = true
    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @AppStorage("showMonthArrows") private var showMonthArrows = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.selectionShape) private var selectionShape
    @Query private var entries: [MoodEntry]
    @State private var isThemePickerPresented = false
    @State private var isShapePickerPresented = false
    @State private var isMembershipPresented = false
    @State private var backupDocument: DataBackupDocument?
    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var isImportingBackup = false
    @State private var importPlan: DataBackupImportPlan?
    @State private var backupMessage: String?
    @State private var reminderPermissionDenied = false
    @State private var isReminderSettingsAlertPresented = false
    #if ICLOUD_SYNC_ENABLED
    @State private var isCheckingICloud = false
    @State private var isICloudAccountAvailable = false
    @State private var isPreviewingICloudAccountAvailable = false
    @State private var isPreviewingICloudEnabled = false
    @State private var iCloudMessage = localized("数据仅保存在本机。")
    #endif
    @State private var calendarTitleCardFrame: CGRect = .zero
    @FocusState private var isCalendarTitleFocused: Bool

    private var hasPremiumAccess: Bool { membership.hasMembershipAccess }

    #if ICLOUD_SYNC_ENABLED
    private var canEnableICloudSync: Bool {
        (isICloudAccountAvailable || isPreviewingICloudAccountAvailable)
            && !isCheckingICloud && !DemoData.isEnabled
    }

    private var iCloudStatusText: String {
        if isCheckingICloud {
            return localized("正在检查 iCloud 账号和访问权限…")
        }
        if isPreviewingICloudEnabled {
            return localized("预览：退出并重新打开 App 后开始同步")
        }
        if isPreviewingICloudAccountAvailable {
            return localized("预览：可以开启 iCloud 同步")
        }
        if isICloudSyncEnabled {
            return localized("退出并重新打开 App 后开始同步")
        }
        return iCloudMessage
    }

    #endif

    @ScaledMetric(relativeTo: .title3) private var settingsHeadingSize: CGFloat = 20

    private var settingsHeadingFont: Font {
        .system(size: settingsHeadingSize, weight: .medium)
    }

    private var settingsItemFont: Font {
        .system(size: settingsHeadingSize * 0.8, weight: .regular)
    }

    private var settingsDetailFont: Font {
        .system(size: settingsHeadingSize * 0.7, weight: .regular)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    personalizationSection

                    membershipSection

                    #if ICLOUD_SYNC_ENABLED
                    syncSection
                    #endif

                    dataExportSection

                    languageSection

                    feedbackSection
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .font(settingsItemFont)
            .background(theme.palette.resolved(for: colorScheme).background)
            .onPreferenceChange(CalendarTitleCardFramePreferenceKey.self) {
                calendarTitleCardFrame = $0
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await checkReminderPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await checkReminderPermission() }
                }
            }
            .fileExporter(
                isPresented: $isShowingBackupExporter,
                document: backupDocument,
                contentType: .zip,
                defaultFilename: localized("今日份"),
                onCompletion: handleBackupExport
            )
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false,
                onCompletion: handleBackupImportSelection
            )
            .confirmationDialog(localized("确认导入备份"), isPresented: Binding(
                get: { importPlan != nil },
                set: { if !$0 { importPlan = nil } }
            ), titleVisibility: .visible) {
                Button(localized("导入并合并")) { restoreBackup() }
                Button(localized("取消"), role: .cancel) { importPlan = nil }
            } message: {
                if let importPlan {
                    Text(localized(
                        "将补入 %d 条每日记录（含 %d 张照片）和 %d 条月便签。另有 %d 条每日记录和 %d 条月便签已存在，会保留。备份不会恢复会员资格。",
                        importPlan.entriesToImport.count,
                        importPlan.photoCount,
                        importPlan.monthlyNotesToImport.count,
                        importPlan.existingEntryCount,
                        importPlan.existingMonthlyNoteCount
                    ) + "\n" + localized("将恢复 %d 个月份的便签皮肤；本机已有选择会保留。", importPlan.monthlyNoteSkins.count))
                }
            }
            .alert(localized("数据备份"), isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { backupMessage = nil }
            } message: {
                Text(backupMessage ?? "")
            }
            #if ICLOUD_SYNC_ENABLED
            .task { await validateSavedICloudSetting() }
            #endif
            .sheet(isPresented: $isThemePickerPresented) {
                themePicker
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $isShapePickerPresented) {
                shapePicker
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $isMembershipPresented) {
                MembershipScreen()
                    .environmentObject(membership)
            }
            .background {
                OutsideTapMonitor(
                    isActive: isCalendarTitleFocused,
                    excludedFrame: calendarTitleCardFrame
                ) {
                    isCalendarTitleFocused = false
                }
                .frame(width: 0, height: 0)
            }
        }
    }

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("个性化"))
                .font(settingsHeadingFont)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(localized("日历标题"))
                            if !hasPremiumAccess {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                            .font(settingsItemFont)
                        TextField(localized("今日份"), text: $storedCalendarTitle)
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                            .focused($isCalendarTitleFocused)
                            .disabled(!hasPremiumAccess)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit { isCalendarTitleFocused = false }
                            .accessibilityLabel(localized("日历标题，最多十个字"))
                            .onChange(of: storedCalendarTitle) { _, newValue in
                                let limitedValue = String(newValue.prefix(10))
                                if limitedValue != newValue {
                                    storedCalendarTitle = limitedValue
                                }
                            }
                    }
                    Spacer(minLength: 8)
                    if isCalendarTitleFocused {
                        Text("\(storedCalendarTitle.count)/10")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel(localized("已输入%@个字，共十个字", String(describing: storedCalendarTitle.count)))
                    }
                }
                .padding(18)
                .background {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.palette.resolved(for: colorScheme).cardBackground)
                            .preference(
                                key: CalendarTitleCardFramePreferenceKey.self,
                                value: proxy.frame(in: .global)
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !hasPremiumAccess {
                        isMembershipPresented = true
                    }
                }
            }

            Button {
                isThemePickerPresented = true
            } label: {
                HStack(spacing: 14) {
                    ThemePaletteIcon(theme: theme)
                        .accessibilityHidden(true)
                        .frame(width: 33, height: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("主题色"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(theme.title)
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("主题色，%@", String(describing: theme.title)))
            .accessibilityHint(localized("选择日历的强调色"))

            Button {
                isShapePickerPresented = true
            } label: {
                HStack(spacing: 14) {
                    SelectionShapeIcon(
                        shape: selectionShape,
                        color: theme.swatchColor,
                        size: 28
                    )
                        .accessibilityHidden(true)
                        .frame(width: 33, height: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("选中图形"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(selectionShape.title)
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("选中图形，%@", String(describing: selectionShape.title)))
            .accessibilityHint(localized("选择日期和月份的选中图形"))

            bookmarkStyleControl

            calendarPreferences

            reminderControl

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("会员"))
                .font(settingsHeadingFont)

            Button {
                isMembershipPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: membership.hasMembershipAccess ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(membership.hasMembershipAccess ? localized("已永久解锁") : localized("解锁全部表情和自定义"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(membership.hasMembershipAccess ? localized("全部权益已开启") : membership.product.map { localized("一次购买，永久使用 · %@", $0.displayPrice) } ?? localized("一次购买，永久使用"))
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(membership.hasMembershipAccess ? localized("会员，已永久解锁") : localized("会员，永久解锁全部表情包和自定义"))
        }
        .padding(.top, 40)
    }

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("数据管理"))
                .font(settingsHeadingFont)

            Button(action: prepareDataBackup) {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("导出数据"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(localized("保存每日记录和月便签"))
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("导出数据"))
            .accessibilityHint(localized("将每日记录和月便签保存为今日份 ZIP 文件"))

            Button { isShowingBackupImporter = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("导入备份"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(localized("从 ZIP 备份恢复记录、便签和照片"))
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if isImportingBackup {
                        ProgressView()
                            .tint(theme.palette.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isImportingBackup)
            .accessibilityLabel(localized("导入备份"))
            .accessibilityHint(localized("选择今日份 ZIP 备份并预览将恢复的内容"))
        }
        .padding(.top, 32)
    }

    private func prepareDataBackup() {
        do {
            let entries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let monthlyNotes = try modelContext.fetch(FetchDescriptor<MonthlyNote>())
            let skins = try MonthlyNoteSkinStore(context: modelContext).backupSelections()
            backupDocument = DataBackupDocument(
                data: try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: monthlyNotes, monthlyNoteSkins: skins)
            )
            isShowingBackupExporter = true
        } catch {
            backupMessage = localized("导出失败：%@", error.localizedDescription)
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            backupMessage = localized("导出失败：%@", error.localizedDescription)
        }
    }

    private func handleBackupImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                backupMessage = localized("无法读取备份文件：%@", error.localizedDescription)
            }
            return
        }
        guard let url = urls.first else {
            backupMessage = localized("请选择一个 ZIP 备份文件。")
            return
        }

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        isImportingBackup = true
        Task { @MainActor in
            defer {
                isImportingBackup = false
                if hasScopedAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let archiveData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url, options: .mappedIfSafe)
                }.value
                let existingEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
                let existingNotes = try modelContext.fetch(FetchDescriptor<MonthlyNote>())
                let existingDayKeys = Set(existingEntries.map(\.dayKey))
                let existingMonthKeys = Set(existingNotes.map(\.monthKey))
                let plan = try await Task.detached(priority: .userInitiated) {
                    try DataBackupImporter.makePlan(
                        from: archiveData,
                        existingDayKeys: existingDayKeys,
                        existingMonthKeys: existingMonthKeys
                    )
                }.value
                guard !plan.entriesToImport.isEmpty || !plan.monthlyNotesToImport.isEmpty || !plan.monthlyNoteSkins.isEmpty else {
                    backupMessage = localized("备份中的记录都已存在，没有需要补入的内容。")
                    return
                }
                importPlan = plan
            } catch {
                backupMessage = error.localizedDescription
            }
        }
    }

    private func restoreBackup() {
        guard let importPlan else { return }
        self.importPlan = nil
        do {
            let result = try DataBackupImporter.restore(importPlan, into: modelContext)
            backupMessage = localized("导入完成：新增 %d 条每日记录和 %d 条月便签。", result.entries, result.monthlyNotes) + "\n" + localized("月便签皮肤已合并，本机已有选择会保留。")
        } catch {
            backupMessage = localized("导入失败：%@", error.localizedDescription)
        }
    }

    private var bookmarkStyleControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("标记样式"))
                .font(settingsItemFont)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(CalendarBookmarkStyle.allCases) { style in
                        bookmarkStyleOption(style)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(CalendarBookmarkStyle.allCases) { style in
                        bookmarkStyleOption(style)
                    }
                }
            }
        }
        .padding(18)
        .background(theme.palette.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private func bookmarkStyleOption(_ style: CalendarBookmarkStyle) -> some View {
        let isSelected = CalendarBookmarkStyle.resolve(storedBookmarkStyle) == style
        return Button {
            storedBookmarkStyle = style.rawValue
        } label: {
            HStack(spacing: 10) {
                Text(verbatim: "23")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(style == .dateColor ? CalendarBookmarkStyle.ink : theme.palette.bookmarkHighlightInk)
                    .background {
                        if style == .highlighter { BookmarkHighlight() }
                    }
                    .frame(width: 32)
                    .accessibilityHidden(true)
                Text(style.title)
                    .font(settingsDetailFont)
                    .foregroundStyle(theme.palette.foreground)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.palette.strongAccent : theme.palette.foreground.opacity(0.25))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .background(isSelected ? theme.palette.bookmarkHighlight : theme.palette.softHighlight.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var calendarPreferences: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(localized("允许修改往日"), isOn: $allowPastDateEditing)
                Text(localized("关闭后往日不可修改和标记"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle(localized("显示翻月箭头"), isOn: $showMonthArrows)
                Text(localized("关闭后仍可用手指左右滑动切换月份"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(theme.palette.strongAccent)
        .padding(18)
        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("语言"))
                .font(settingsHeadingFont)
                .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
            HStack {
                Text(localized("App 语言"))
                    .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
                Spacer()
                Picker(localized("App 语言"), selection: $storedLanguage) {
                    ForEach(AppLanguage.options, id: \.self) { code in
                        Text(AppLanguage.name(code)).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .font(.body)
            }
            .font(.body)
            .padding(20)
            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(.top, 28)
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("反馈"))
                .font(settingsHeadingFont)

            Button {
                openURL(feedbackEmailURL)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "envelope")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("联系"))
                            .font(settingsItemFont)
                            .foregroundStyle(.primary)
                        Text(verbatim: "yui480145@gmail.com")
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("联系，yui480145@gmail.com"))
            .accessibilityHint(localized("打开邮件发送反馈"))
        }
        .padding(.top, 32)
    }

    private var feedbackEmailURL: URL {
        URL(string: "mailto:yui480145@gmail.com?subject=%E4%BB%8A%E6%97%A5%E4%BB%BD%E5%8F%8D%E9%A6%88")!
    }

    private var reminderControl: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("每日提醒"))
                    .font(settingsItemFont)
                    .foregroundStyle(.primary)
                if reminderPermissionDenied {
                    Text(localized("系统通知已关闭，请在设置中允许通知"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if reminderPermissionDenied {
                Button(localized("去设置")) { isReminderSettingsAlertPresented = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.palette.strongAccent)
                    .accessibilityLabel(localized("打开系统设置，允许每日提醒通知"))
            } else {
                Toggle(localized("每日提醒"), isOn: dailyReminderToggleBinding)
                    .labelsHidden()
                    .tint(theme.palette.strongAccent)
                    .accessibilityLabel(localized("每日提醒"))
            }
        }
        .padding(18)
        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .alert(localized("需要开启系统通知"), isPresented: $isReminderSettingsAlertPresented) {
            Button(localized("打开设置")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button(localized("取消"), role: .cancel) {}
        } message: {
            Text(localized("请在 iPhone 设置中允许今日份发送通知，然后回来开启每日提醒。"))
        }
    }

    private func checkReminderPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        reminderPermissionDenied = settings.authorizationStatus == .denied
    }

    private var dailyReminderToggleBinding: Binding<Bool> {
        Binding(
            get: { isDailyReminderEnabled },
            set: { enabled in
                isDailyReminderEnabled = enabled
                let recordedDayKeys = Set(entries.filter { $0.choice != nil }.map(\.dayKey))
                Task {
                    await DailyFragmentReminder.refresh(
                        recordedDayKeys: recordedDayKeys,
                        isEnabled: enabled
                    )
                    await checkReminderPermission()
                }
            }
        )
    }

    // Temporarily excluded for Personal Team device testing.
    #if ICLOUD_SYNC_ENABLED
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("数据同步"))
                .font(settingsHeadingFont)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("iCloud 同步"))
                        .font(settingsItemFont)
                        .foregroundStyle(.primary)
                    Text(iCloudStatusText)
                        .font(settingsDetailFont)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if isCheckingICloud {
                    ProgressView()
                        .tint(theme.palette.strongAccent)
                        .frame(width: 52, height: 32)
                        .accessibilityLabel(localized("正在检查 iCloud"))
                } else {
                    Toggle(localized("iCloud 同步"), isOn: iCloudToggleBinding)
                        .labelsHidden()
                        .tint(theme.palette.strongAccent)
                        .disabled(!canEnableICloudSync && !isICloudSyncEnabled && !isPreviewingICloudEnabled)
                        .accessibilityLabel(localized("iCloud 同步"))
                }
            }
            .padding(18)
            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .opacity(isICloudAccountAvailable || isCheckingICloud || isPreviewingICloudEnabled || isPreviewingICloudAccountAvailable ? 1 : 0.58)
            .overlay(alignment: .topTrailing) {
                if !isICloudAccountAvailable && !isCheckingICloud && !isPreviewingICloudEnabled && !isPreviewingICloudAccountAvailable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(7)
                        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: Circle())
                        .offset(x: -8, y: 8)
                        .accessibilityHidden(true)
                }
            }


            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                Button(localized("预览已登录、未开启（仅调试，不会同步）")) {
                    isPreviewingICloudAccountAvailable = true
                    isPreviewingICloudEnabled = false
                }
                Button(localized("预览已开启（仅调试，不会同步）")) {
                    isPreviewingICloudAccountAvailable = false
                    isPreviewingICloudEnabled = true
                }
                if isPreviewingICloudAccountAvailable || isPreviewingICloudEnabled {
                    Button(localized("退出 iCloud 预览")) {
                        isPreviewingICloudAccountAvailable = false
                        isPreviewingICloudEnabled = false
                    }
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(theme.palette.strongAccent)
            .padding(.horizontal, 4)
            #endif
        }
        .padding(.top, 40)
    }

    private var iCloudToggleBinding: Binding<Bool> {
        Binding(
            get: {
                if isPreviewingICloudAccountAvailable { return false }
                if isPreviewingICloudEnabled { return true }
                return isICloudSyncEnabled
            },
            set: { wantsICloudSync in
                if isPreviewingICloudEnabled || isPreviewingICloudAccountAvailable {
                    isPreviewingICloudAccountAvailable = !wantsICloudSync
                    isPreviewingICloudEnabled = wantsICloudSync
                    return
                }
                guard canEnableICloudSync || !wantsICloudSync else { return }
                if wantsICloudSync {
                    Task { @MainActor in await enableICloudSyncAfterValidation() }
                } else {
                    isICloudSyncEnabled = false
                    iCloudMessage = localized("已关闭")
                }
            }
        )
    }

    @MainActor
    private func validateSavedICloudSetting() async {
        await checkICloudAccountAvailability()
        guard isICloudSyncEnabled else { return }
        await enableICloudSyncAfterValidation()
    }

    @MainActor
    private func checkICloudAccountAvailability() async {
        guard !DemoData.isEnabled else {
            isICloudAccountAvailable = false
            iCloudMessage = localized("演示模式不支持 iCloud 同步")
            return
        }
        do {
            let status = try await CKContainer(identifier: "iCloud.com.qingqing.MoodCalendar").accountStatus()
            isICloudAccountAvailable = status == .available
            if status == .noAccount {
                iCloudMessage = localized("请先在系统设置中登录 iCloud")
            } else if status == .available && !isICloudSyncEnabled {
                iCloudMessage = localized("可以开启 iCloud 同步")
            } else if status != .available {
                iCloudMessage = localized("当前无法使用 iCloud；请检查系统设置")
            }
        } catch {
            isICloudAccountAvailable = false
            iCloudMessage = localized("无法访问 iCloud；请检查系统设置和网络")
        }
    }

    @MainActor
    private func enableICloudSyncAfterValidation() async {
        guard !isCheckingICloud else { return }
        isCheckingICloud = true
        iCloudMessage = localized("正在检查 iCloud 账号和访问权限…")
        defer { isCheckingICloud = false }

        guard !DemoData.isEnabled else {
            isICloudSyncEnabled = false
            iCloudMessage = localized("演示模式不支持 iCloud 同步")
            return
        }

        do {
            let cloudContainer = CKContainer(identifier: "iCloud.com.qingqing.MoodCalendar")
            switch try await cloudContainer.accountStatus() {
            case .available:
                _ = try await cloudContainer.userRecordID()
                isICloudAccountAvailable = true
                isICloudSyncEnabled = true
                iCloudMessage = localized("退出并重新打开 App 后开始自动同步")
            case .noAccount:
                isICloudAccountAvailable = false
                failToEnableICloud(localized("请先在系统设置中登录 iCloud"))
            case .restricted:
                isICloudAccountAvailable = false
                failToEnableICloud(localized("此设备当前无法使用 iCloud"))
            case .temporarilyUnavailable:
                isICloudAccountAvailable = false
                failToEnableICloud(localized("iCloud 暂时不可用，请稍后再试"))
            case .couldNotDetermine:
                isICloudAccountAvailable = false
                failToEnableICloud(localized("暂时无法确认 iCloud 状态，请稍后再试"))
            @unknown default:
                isICloudAccountAvailable = false
                failToEnableICloud(localized("无法确认 iCloud 状态，请稍后再试"))
            }
        } catch {
            isICloudAccountAvailable = false
            UserDefaults.standard.set(true, forKey: "icloudEnableFailurePending")
            isICloudSyncEnabled = false
            if let cloudError = error as? CKError, cloudError.code == .notAuthenticated {
                iCloudMessage = localized("请先在系统设置中登录 iCloud")
            } else {
                iCloudMessage = localized("无法访问此 App 的 iCloud 容器，请检查开发者签名和网络后重试")
            }
        }
    }

    @MainActor
    private func failToEnableICloud(_ message: String) {
        UserDefaults.standard.set(true, forKey: "icloudEnableFailurePending")
        isICloudSyncEnabled = false
        iCloudMessage = message
    }

    #endif

    private var themePicker: some View {
        VStack(spacing: 16) {
            ZStack {
                Text(localized("主题色"))
                    .font(settingsHeadingFont)

                HStack {
                    Spacer()
                    Button(localized("完成")) { isThemePickerPresented = false }
                        .font(settingsItemFont)
                        .foregroundStyle(theme.palette.strongAccent)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
            .frame(minHeight: 40)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { option in
                        Button {
                            guard hasPremiumAccess || option == .pink || option == .black else {
                                isThemePickerPresented = false
                                isMembershipPresented = true
                                return
                            }
                            storedTheme = option.rawValue
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(option.swatchColor)
                                    .frame(width: 28, height: 28)
                                    .accessibilityHidden(true)
                                Text(option.title)
                                    .font(settingsItemFont)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if option != .pink && option != .black && !hasPremiumAccess {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if storedTheme == option.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(option.palette.strongAccent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(storedTheme == option.rawValue ? option.palette.softHighlight : .clear,
                                        in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(storedTheme == option.rawValue ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(theme.palette.resolved(for: colorScheme).background)
    }

    private var shapePicker: some View {
        VStack(spacing: 16) {
            ZStack {
                Text(localized("选中图形"))
                    .font(settingsHeadingFont)

                HStack {
                    Spacer()
                    Button(localized("完成")) { isShapePickerPresented = false }
                        .font(settingsItemFont)
                        .foregroundStyle(theme.palette.strongAccent)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
            .frame(minHeight: 40)

            VStack(spacing: 8) {
                ForEach(SelectionShape.allCases) { option in
                    Button {
                        guard hasPremiumAccess || option == .circle || option == .star else {
                            isShapePickerPresented = false
                            isMembershipPresented = true
                            return
                        }
                        storedSelectionShape = option.rawValue
                    } label: {
                        HStack(spacing: 14) {
                            SelectionShapeIcon(
                                shape: option,
                                color: theme.swatchColor,
                                size: [.star, .sakura, .leaf, .cat].contains(option) ? 32 : 28
                            )
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                            Text(option.title)
                                .font(settingsItemFont)
                                .foregroundStyle(.primary)
                            Spacer()
                            if option != .circle && option != .star && !hasPremiumAccess {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if storedSelectionShape == option.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.palette.strongAccent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(storedSelectionShape == option.rawValue ? theme.palette.softHighlight : .clear,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(storedSelectionShape == option.rawValue ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(theme.palette.resolved(for: colorScheme).background)
    }
}
