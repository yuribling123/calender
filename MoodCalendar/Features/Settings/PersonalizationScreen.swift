import SwiftUI
import SwiftData
#if ICLOUD_SYNC_ENABLED
import CloudKit
#endif
import UIKit
import UserNotifications

/// A broad marker stroke with a pressed tip and staggered lift-off marks.
private struct SettingsMarkerStroke: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = min(rect.height * 0.28, rect.width * 0.12)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x, y: rect.minY + rect.height * y)
        }
        let width = rect.width
        var path = Path()
        path.move(to: point(tip, 0.07))
        path.addCurve(to: point(width - tip * 0.4, 0.04),
                      control1: point(width * 0.32, -0.02),
                      control2: point(width * 0.70, 0.10))
        path.addLine(to: point(width - tip * 0.8, 0.31))
        path.addLine(to: point(width, 0.34))
        path.addLine(to: point(width - tip * 0.35, 0.62))
        path.addLine(to: point(width - tip * 0.05, 0.65))
        path.addLine(to: point(width - tip * 0.75, 0.94))
        path.addCurve(to: point(tip * 0.15, 0.96),
                      control1: point(width * 0.66, 0.89),
                      control2: point(width * 0.30, 1.02))
        path.addLine(to: point(tip * 0.40, 0.66))
        path.addLine(to: point(0, 0.62))
        path.closeSubpath()
        return path
    }
}

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.selection
    @EnvironmentObject private var membership: MembershipStore
    @AppStorage("collectionVinylSkin") private var storedVinylSkin = CollectionVinylSkin.original.rawValue
    @AppStorage("collectionWatchSkin.v1") private var storedWatchSkin = CollectionWatchSkin.original.rawValue
    @AppStorage("collectionPhotoSkin.v1") private var storedPhotoSkin = CollectionPhotoSkin.original.rawValue
//     @AppStorage("collectionTapeSkin") private var storedTapeSkin = CollectionTapeSkin.original.rawValue
    @State private var appearanceSaveFailed = false
    @Environment(\.calendarBookmarkStyle) private var bookmarkStyle
    #if ICLOUD_SYNC_ENABLED
    @AppStorage("icloudSyncEnabled") private var isICloudSyncEnabled = false
    #endif
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @AppStorage("dailyReminderEnabled") private var isDailyReminderEnabled = true
    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @AppStorage("showMonthArrows") private var showMonthArrows = true
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var futureLetterStore: FutureLetterStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.selectionShape) private var selectionShape
    @Query private var entries: [MoodEntry]
    @State private var isThemePickerPresented = false
    @StateObject private var manualUpdateChecker = AppUpdateChecker()
    @State private var updateMessage: String?
    @State private var manualUpdate: AppStoreUpdate?
    @State private var isShapePickerPresented = false
    @State private var isBookmarkStylePickerPresented = false
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

    @ScaledMetric(relativeTo: .body) private var settingsSectionHeadingSize: CGFloat = 17
    private let settingsHeadingSize: CGFloat = 23
    @ScaledMetric(relativeTo: .title3) private var settingsItemSize: CGFloat = 16
    @ScaledMetric(relativeTo: .title3) private var settingsDetailSize: CGFloat = 14

    private var settingsSectionHeadingFont: Font {
        .system(size: settingsSectionHeadingSize, weight: .medium)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(settingsSectionHeadingFont)
            .foregroundStyle(theme.palette.resolved(for: colorScheme).foreground)
            .background(alignment: .center) {
                SettingsMarkerStroke()
                    .fill(LinearGradient(
                        colors: [theme.palette.settingsHeadingHighlight.opacity(0.85),
                                 theme.palette.settingsHeadingHighlight,
                                 theme.palette.settingsHeadingHighlight.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: settingsSectionHeadingSize * 1.05)
                    .padding(.horizontal, -6)
                    .rotationEffect(.degrees(-1.2))
                    .offset(y: 2)
            }
            .padding(.leading, 18)
            .accessibilityAddTraits(.isHeader)
    }

    private var settingsHeadingFont: Font {
        .system(size: settingsHeadingSize, weight: .medium)
    }

    private var settingsItemFont: Font {
        .system(size: settingsItemSize, weight: .regular)
    }

    private var settingsDetailFont: Font {
        .system(size: settingsDetailSize, weight: .regular)
    }

    var body: some View {
        NavigationStack {
            AdaptivePage { size in
                ScrollView {
                    if let size, size.width >= 760, !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 28) {
                            personalizationSection
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            VStack(alignment: .leading, spacing: 0) {
                                membershipSection(topPadding: 12)
                                #if ICLOUD_SYNC_ENABLED
                                syncSection
                                #endif
                                dataExportSection
                                languageSection
                                feedbackSection
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .padding(32)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            personalizationSection

                            membershipSection()

                            #if ICLOUD_SYNC_ENABLED
                            syncSection
                            #endif

                            dataExportSection

                            languageSection

                            feedbackSection
                        }
                        .padding(24)
                    }
                }
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
                    ) + "\n" + localized("将恢复 %d 个月份的便签皮肤；本机已有选择会保留。", importPlan.monthlyNoteSkins.count) + "\n" + localized("将合并 %d 个日期的标记状态；本机已有状态会保留。", importPlan.starredDays.count) + "\n" + localized("另有 %d 封未来纸条和 %d 份小刊草稿；本机已有内容会保留。", importPlan.futureLetters.count, importPlan.monthlyZineDrafts.count) + (importPlan.appearance.isEmpty ? "" : "\n" + localized("备份中的主题色、选中图形和标记样式将应用到本机。")))
                }
            }
            .alert(localized("无法保存个性化设置"), isPresented: $appearanceSaveFailed) {
                Button(localized("确定"), role: .cancel) {}
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
                    .iPadScrollable(background: theme.palette.resolved(for: colorScheme).background)
                    .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium])
            }
            .sheet(isPresented: $isBookmarkStylePickerPresented) {
                bookmarkStylePicker
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(localized("个性化"))
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("日历标题"))
                            .font(settingsItemFont)
                        TextField(localized("今日份"), text: $storedCalendarTitle)
                            .font(settingsDetailFont)
                            .foregroundStyle(.secondary)
                            .focused($isCalendarTitleFocused)
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

            // 暂时隐藏收藏皮肤入口，保留选择页面以便后续恢复。
            // vinylSkinControl
            // watchSkinControl
            // photoSkinControl

            bookmarkStyleControl

            calendarPreferences

            reminderControl

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoSkinControl: some View {
        NavigationLink {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(CollectionPhotoSkin.allCases) { skin in
                        Button { storedPhotoSkin = skin.rawValue } label: {
                            HStack(spacing: 22) {
                                CollectionPhotoPaperPreview(skin: skin)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(skin.title).font(.body.weight(.medium))
                                        if CollectionPhotoSkin.resolve(storedPhotoSkin) == skin {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(theme.palette.strongAccent)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                    Text(skin.caption).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(20)
                            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(CollectionPhotoSkin.resolve(storedPhotoSkin) == skin
                                                  ? theme.palette.strongAccent.opacity(0.45) : .clear, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(skin.title + "，" + skin.caption)
                        .accessibilityAddTraits(CollectionPhotoSkin.resolve(storedPhotoSkin) == skin ? .isSelected : [])
                    }
                }
                .padding(24)
                .iPadReadableWidth(600)
            }
            .background(theme.palette.collectionBackground)
            .navigationTitle(localized("相纸皮肤"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
        } label: {
            HStack(spacing: 14) {
                CollectionPhotoPaperPreview(skin: .resolve(storedPhotoSkin))
                    .fixedSize()
                    .scaleEffect(0.34)
                    .frame(width: 33, height: 33)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("相纸皮肤")).font(settingsItemFont).foregroundStyle(.primary)
                    Text(CollectionPhotoSkin.resolve(storedPhotoSkin).title)
                        .font(settingsDetailFont).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("相纸皮肤") + "，" + CollectionPhotoSkin.resolve(storedPhotoSkin).title)
    }

    private var watchSkinControl: some View {
        NavigationLink {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(CollectionWatchSkin.allCases) { skin in
                        Button { storedWatchSkin = skin.rawValue } label: {
                            HStack(spacing: 22) {
                                CollectionWatchTape(title: "", kind: "movie", width: 84, skin: skin)
                                    .frame(width: 84).frame(minHeight: 84)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(skin.title).font(.body.weight(.medium))
                                        if CollectionWatchSkin.resolve(storedWatchSkin) == skin {
                                            Image(systemName: "checkmark").font(.footnote.weight(.semibold))
                                                .foregroundStyle(theme.palette.strongAccent)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                    Text(skin.caption).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(20)
                            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(CollectionWatchSkin.resolve(storedWatchSkin) == skin
                                                  ? theme.palette.strongAccent.opacity(0.45) : .clear, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(skin.title + "，" + skin.caption)
                        .accessibilityAddTraits(CollectionWatchSkin.resolve(storedWatchSkin) == skin ? .isSelected : [])
                    }
                }
                .padding(24)
                .iPadReadableWidth(600)
            }
            .background(theme.palette.collectionBackground)
            .navigationTitle(localized("影视皮肤"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
        } label: {
            HStack(spacing: 14) {
                CollectionWatchTape(title: "", kind: "", width: 33, skin: .resolve(storedWatchSkin))
                    .frame(width: 33, height: 33)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("影视皮肤")).font(settingsItemFont).foregroundStyle(.primary)
                    Text(CollectionWatchSkin.resolve(storedWatchSkin).title)
                        .font(settingsDetailFont).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var vinylSkinControl: some View {
        NavigationLink {
            vinylSkinPicker
        } label: {
            HStack(spacing: 14) {
                CollectionDisc(skin: .resolve(storedVinylSkin))
                    .frame(width: 33, height: 33)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("黑胶皮肤")).font(settingsItemFont).foregroundStyle(.primary)
                    Text(CollectionVinylSkin.resolve(storedVinylSkin).title)
                        .font(settingsDetailFont).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("黑胶皮肤") + "，" + CollectionVinylSkin.resolve(storedVinylSkin).title)
    }

    private var vinylSkinPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(CollectionVinylSkin.allCases) { skin in
                    Button { storedVinylSkin = skin.rawValue } label: {
                        HStack(alignment: .center, spacing: 22) {
                            vinylSkinPreview(skin)
                            vinylSkinDescription(skin)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(CollectionVinylSkin.resolve(storedVinylSkin) == skin
                                              ? theme.palette.strongAccent.opacity(0.45) : .clear, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(skin.title + "，" + skin.caption)
                    .accessibilityAddTraits(CollectionVinylSkin.resolve(storedVinylSkin) == skin ? .isSelected : [])
                }
            }
            .padding(24)
            .iPadReadableWidth(600)
        }
        .background(theme.palette.collectionBackground)
        .navigationTitle(localized("黑胶皮肤"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func vinylSkinPreview(_ skin: CollectionVinylSkin) -> some View {
        CollectionVinylArtwork(title: "", artist: "", diameter: 84, skin: skin)
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)
    }

    private func vinylSkinDescription(_ skin: CollectionVinylSkin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(skin.title).font(.body.weight(.medium))
                if CollectionVinylSkin.resolve(storedVinylSkin) == skin {
                    Image(systemName: "checkmark").font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.palette.strongAccent)
                }
            }
            .foregroundStyle(.primary)
            Text(skin.caption).font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(nil)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

// Legacy skin controls remain commented out; only the vinyl picker above is active.
//     private var collectionSkinControl: some View {
//         VStack(spacing: 10) {
//             NavigationLink {
//                 collectionSkinDetails(isVinyl: true)
//             } label: {
//                 collectionSkinRow(title: localized("黑胶皮肤"),
//                                   selection: CollectionVinylSkin.resolve(storedVinylSkin).title) {
//                     CollectionVinylArtwork(title: "", artist: "", diameter: 33,
//                                            skin: .resolve(storedVinylSkin))
//                 }
//             }
//             NavigationLink {
//                 collectionSkinDetails(isVinyl: false)
//             } label: {
//                 collectionSkinRow(title: localized("录像带皮肤"),
//                                   selection: CollectionTapeSkin.resolve(storedTapeSkin).title) {
//                     CollectionWatchTape(title: "", kind: "", width: 33,
//                                         skin: .resolve(storedTapeSkin))
//                 }
//             }
//         }
//         .buttonStyle(.plain)
//     }
//
//     private func collectionSkinRow<Artwork: View>(title: String, selection: String,
//                                                  @ViewBuilder artwork: () -> Artwork) -> some View {
//         HStack(spacing: 14) {
//             artwork().frame(width: 33, height: 33).accessibilityHidden(true)
//             VStack(alignment: .leading, spacing: 4) {
//                 Text(title).font(settingsItemFont).foregroundStyle(.primary)
//                 Text(selection).font(settingsDetailFont).foregroundStyle(.secondary)
//             }
//             Spacer(minLength: 8)
//             Image(systemName: "chevron.right")
//                 .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
//                 .accessibilityHidden(true)
//         }
//         .padding(18)
//         .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
//         .contentShape(Rectangle())
//     }
//
//     private func collectionSkinDetails(isVinyl: Bool) -> some View {
//         ScrollView {
//             LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 12)], spacing: 12) {
//                 if isVinyl {
//                     vinylSkinChoices
//                 } else {
//                     tapeSkinChoices
//                 }
//             }
//             .padding(24)
//         }
//         .background(theme.palette.collectionBackground)
//         .navigationTitle(localized(isVinyl ? "黑胶皮肤" : "录像带皮肤"))
//         .navigationBarTitleDisplayMode(.inline)
//     }
//
//     private var vinylSkinChoices: some View {
//         ForEach(CollectionVinylSkin.allCases) { skin in
//             skinChoice(title: skin.title, selected: CollectionVinylSkin.resolve(storedVinylSkin) == skin,
//                        action: { storedVinylSkin = skin.rawValue }) {
//                 CollectionVinylArtwork(title: localized("晴天"), artist: "", diameter: 76, skin: skin)
//             }
//         }
//     }
//
//     private var tapeSkinChoices: some View {
//         ForEach(CollectionTapeSkin.allCases) { skin in
//             skinChoice(title: skin.title, selected: CollectionTapeSkin.resolve(storedTapeSkin) == skin,
//                        action: { storedTapeSkin = skin.rawValue }) {
//                 CollectionWatchTape(title: localized("六个字的电影"), kind: "movie", width: 108, skin: skin)
//             }
//         }
//     }
//
//     private func skinChoice<Artwork: View>(title: String, selected: Bool, action: @escaping () -> Void,
//                                           @ViewBuilder artwork: () -> Artwork) -> some View {
//         Button(action: action) {
//             VStack(spacing: 10) {
//                 artwork().frame(height: 80).accessibilityHidden(true)
//                 HStack(spacing: 5) {
//                     Image(systemName: selected ? "checkmark.circle.fill" : "circle")
//                         .foregroundStyle(selected ? theme.swatchColor : .secondary)
//                     Text(title).foregroundStyle(.primary)
//                 }
//                 .font(.footnote)
//             }
//             .padding(.vertical, 12)
//             .padding(.horizontal, 8)
//             .frame(minWidth: 124, maxWidth: .infinity)
//             .background(theme.palette.collectionBackground, in: RoundedRectangle(cornerRadius: 12))
//             .overlay {
//                 RoundedRectangle(cornerRadius: 12)
//                     .strokeBorder(selected ? theme.swatchColor.opacity(0.65) : .clear, lineWidth: 1)
//             }
//             .contentShape(Rectangle())
//         }
//         .buttonStyle(.plain)
//         .accessibilityLabel(title)
//         .accessibilityAddTraits(selected ? .isSelected : [])
//     }
//
    private func membershipSection(topPadding: CGFloat = 40) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(localized("会员"))

            Button {
                isMembershipPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: membership.hasMembershipAccess ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(membership.hasMembershipAccess ? localized("已永久解锁") : localized("表情包、日历外观和月便签皮肤"))
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
            .accessibilityLabel(membership.hasMembershipAccess ? localized("会员，已永久解锁") : localized("会员，永久解锁表情包、日历外观和月便签皮肤"))
        }
        .padding(.top, topPadding)
    }

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(localized("数据管理"))

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
                        // 新功能暂时停用，保留原文案供恢复。
                        // Text(localized("保存记录、月便签、未来纸条和小刊草稿"))
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
            .accessibilityHint(localized(futureLetterStore.letters.isEmpty
                ? "将每日记录和月便签保存为今日份 ZIP 文件"
                : "将记录、未来纸条和小刊草稿保存为 ZIP 文件，包含未拆纸条的正文"))

            if !futureLetterStore.letters.isEmpty {
                Text(localized("ZIP 备份也会包含未拆纸条的正文，请保存在私人的位置。"))
                    .font(settingsDetailFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
            }

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

    private func saveAppearance(_ value: String, for key: CalendarAppearanceKey) {
        do {
            try CalendarAppearanceStore(context: modelContext).select(value, for: key)
        } catch {
            appearanceSaveFailed = true
        }
    }

    private func prepareDataBackup() {
        do {
            let entries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let monthlyNotes = try modelContext.fetch(FetchDescriptor<MonthlyNote>())
            let skins = try MonthlyNoteSkinStore(context: modelContext).backupSelections()
            _ = try futureLetterStore.exportData()
            let drafts = try MonthlyZineDraftStore.applicationStore(isDemo: DemoData.isEnabled).exportDrafts()
            backupDocument = DataBackupDocument(
                data: try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: monthlyNotes, monthlyNoteSkins: skins, starredDays: try StarredDayPersistence(context: modelContext).backupSelections(), futureLetters: futureLetterStore.letters, monthlyZineDrafts: drafts, appearance: try CalendarAppearanceStore(context: modelContext).backupValues())
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
                guard !plan.entriesToImport.isEmpty || !plan.monthlyNotesToImport.isEmpty || !plan.monthlyNoteSkins.isEmpty || !plan.starredDays.isEmpty || !plan.futureLetters.isEmpty || !plan.monthlyZineDrafts.isEmpty || !plan.appearance.isEmpty else {
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
            // Preflight both local stores before changing any records. Imports are
            // additive and safe to retry if a later disk write fails.
            let draftStore = MonthlyZineDraftStore.applicationStore(isDemo: DemoData.isEnabled)
            if !importPlan.futureLetters.isEmpty { _ = try futureLetterStore.exportData() }
            if !importPlan.monthlyZineDrafts.isEmpty { _ = try draftStore.exportDrafts() }
            if !importPlan.futureLetters.isEmpty { try futureLetterStore.importLetters(importPlan.futureLetters) }
            if !importPlan.monthlyZineDrafts.isEmpty { try draftStore.mergeImportedDrafts(importPlan.monthlyZineDrafts) }
            let result = try DataBackupImporter.restore(importPlan, into: modelContext)
            backupMessage = localized("导入完成：新增 %d 条每日记录和 %d 条月便签。", result.entries, result.monthlyNotes) + "\n" + localized("月便签皮肤已合并，本机已有选择会保留。") + "\n" + localized("日期标记已合并，本机已有状态会保留。") + "\n" + localized("未来纸条和小刊草稿已合并，本机已有内容会保留。") + (importPlan.appearance.isEmpty ? "" : "\n" + localized("已恢复备份中的个性化设置。"))
        } catch {
            backupMessage = localized("导入未全部完成：%@。已合并的内容会保留，可安全重试。", error.localizedDescription)
        }
    }

    private var bookmarkStyleControl: some View {
        Button {
            isBookmarkStylePickerPresented = true
        } label: {
            HStack(spacing: 14) {
                bookmarkStylePreview(bookmarkStyle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("标记样式"))
                        .font(settingsItemFont)
                        .foregroundStyle(.primary)
                    Text(bookmarkStyle.title)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("标记样式") + "，" + bookmarkStyle.title)
    }

    private func bookmarkStylePreview(_ style: CalendarBookmarkStyle) -> some View {
        Text(verbatim: "23")
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(style == .dateColor ? CalendarBookmarkStyle.ink : theme.palette.bookmarkHighlightInk)
            .background {
                if style == .highlighter { BookmarkHighlight() }
            }
            .frame(width: 33, height: 30)
            .accessibilityHidden(true)
    }

    private var bookmarkStylePicker: some View {
        VStack(spacing: 16) {
            ZStack {
                Text(localized("标记样式"))
                    .font(settingsHeadingFont)
                HStack {
                    Spacer()
                    Button(localized("完成")) { isBookmarkStylePickerPresented = false }
                        .font(settingsItemFont)
                        .foregroundStyle(theme.palette.strongAccent)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
            .frame(minHeight: 40)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(CalendarBookmarkStyle.allCases) { style in
                        bookmarkStyleOption(style)
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

    private func bookmarkStyleOption(_ style: CalendarBookmarkStyle) -> some View {
        let isSelected = bookmarkStyle == style
        return Button {
            saveAppearance(style.rawValue, for: .bookmark)
        } label: {
            HStack(spacing: 14) {
                bookmarkStylePreview(style)
                Text(style.title)
                    .font(settingsItemFont)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.palette.strongAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(isSelected ? theme.palette.softHighlight : .clear, in: RoundedRectangle(cornerRadius: 14))
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(localized("语言"))
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
        .padding(.top, 32)
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            /* 手动检查更新入口暂时隐藏，保留以便恢复。
            Button {
                Task {
                    manualUpdate = nil
                    switch await manualUpdateChecker.checkIfNeeded(manually: true) {
                    case .update(let update):
                        manualUpdate = update
                        updateMessage = localized("有新版本啦") + " " + update.version
                    case .upToDate:
                        updateMessage = localized("已是最新版本")
                    case .failed, .skipped:
                        updateMessage = localized("检查失败，请稍后再试")
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    Text(localized("检查更新"))
                        .foregroundStyle(.primary)
                    Spacer()
                    if manualUpdateChecker.isChecking { ProgressView() }
                }
                .padding(18)
                .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(manualUpdateChecker.isChecking)
            .alert(localized("检查更新"), isPresented: Binding(
                get: { updateMessage != nil },
                set: { if !$0 { updateMessage = nil } }
            )) {
                if let url = manualUpdate?.productURL {
                    Button(localized("前往更新")) { openURL(url) }
                }
                Button(localized("确定"), role: .cancel) {}
            } message: {
                Text(updateMessage ?? "")
            }
            */

            sectionHeading(localized("反馈"))

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
                        isEnabled: enabled,
                        mayRequestAuthorization: true
                    )
                    await checkReminderPermission()
                }
            }
        )
    }

    // Temporarily excluded for Personal Team device testing.
    #if ICLOUD_SYNC_ENABLED
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(localized("数据同步"))

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
                        .foregroundStyle(theme.palette.strongAccent)
                        .padding(7)
                        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: Circle())
                        .offset(x: -8, y: 8)
                        .accessibilityHidden(true)
                }
            }
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
                            guard hasPremiumAccess || !option.requiresMembership else {
                                isThemePickerPresented = false
                                isMembershipPresented = true
                                return
                            }
                            saveAppearance(option.rawValue, for: .theme)
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
                                if option.requiresMembership && !hasPremiumAccess {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(theme.palette.strongAccent)
                                }
                                if theme == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(option.palette.strongAccent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(theme == option ? option.palette.softHighlight : .clear,
                                        in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(theme == option ? .isSelected : [])
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
                        guard hasPremiumAccess || !option.requiresMembership else {
                            isShapePickerPresented = false
                            isMembershipPresented = true
                            return
                        }
                        saveAppearance(option.rawValue, for: .shape)
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
                            if option.requiresMembership && !hasPremiumAccess {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.palette.strongAccent)
                            }
                            if selectionShape == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.palette.strongAccent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(selectionShape == option ? theme.palette.softHighlight : .clear,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(selectionShape == option ? .isSelected : [])
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
