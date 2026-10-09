import SwiftUI
import SwiftData
#if ICLOUD_SYNC_ENABLED
import CloudKit
#endif
import UIKit

private struct CalendarTitleCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct ThemePaletteIcon: View {
    let palette: ThemePalette

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
                .fill(palette.selectionFill)
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
    @EnvironmentObject private var membership: MembershipStore
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.circle.rawValue
    #if ICLOUD_SYNC_ENABLED
    @AppStorage("icloudSyncEnabled") private var isICloudSyncEnabled = false
    #endif
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @AppStorage("dailyReminderEnabled") private var isDailyReminderEnabled = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme
    @Environment(\.selectionShape) private var selectionShape
    @Query private var entries: [MoodEntry]
    @State private var isThemePickerPresented = false
    @State private var isShapePickerPresented = false
    @State private var isMembershipPresented = false
    @State private var backupDocument: DataBackupDocument?
    @State private var isShowingBackupExporter = false
    @State private var exportError: String?
    #if ICLOUD_SYNC_ENABLED
    @State private var isCheckingICloud = false
    @State private var isICloudAccountAvailable = false
    @State private var isPreviewingICloudAccountAvailable = false
    @State private var isPreviewingICloudEnabled = false
    @State private var iCloudMessage = "数据仅保存在本机。"
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
            return "正在检查 iCloud 账号和访问权限…"
        }
        if isPreviewingICloudEnabled {
            return "预览：完全退出并重新打开 App 后开始同步"
        }
        if isPreviewingICloudAccountAvailable {
            return "预览：可以开启 iCloud 同步"
        }
        if isICloudSyncEnabled {
            return "完全退出并重新打开 App 后开始同步"
        }
        return iCloudMessage
    }

    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("我的")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    personalizationSection

                    membershipSection

                    reminderSection

                    #if ICLOUD_SYNC_ENABLED
                    syncSection
                    #endif

                    dataExportSection

                    feedbackSection
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.palette.background)
            .onPreferenceChange(CalendarTitleCardFramePreferenceKey.self) {
                calendarTitleCardFrame = $0
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileExporter(
                isPresented: $isShowingBackupExporter,
                document: backupDocument,
                contentType: .zip,
                defaultFilename: "今日份",
                onCompletion: handleBackupExport
            )
            .alert("导出失败", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("好", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "请稍后再试。")
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
            Text("个性化")
                .font(.title3.weight(.semibold))
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("日历标题")
                            if !hasPremiumAccess {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                            .font(.body.weight(.medium))
                        TextField("今日份", text: $storedCalendarTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .focused($isCalendarTitleFocused)
                            .disabled(!hasPremiumAccess)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit { isCalendarTitleFocused = false }
                            .accessibilityLabel("日历标题，最多六个字")
                            .onChange(of: storedCalendarTitle) { _, newValue in
                                let limitedValue = String(newValue.prefix(6))
                                if limitedValue != newValue {
                                    storedCalendarTitle = limitedValue
                                }
                            }
                    }
                    Spacer(minLength: 8)
                    if isCalendarTitleFocused {
                        Text("\(storedCalendarTitle.count)/6")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("已输入\(storedCalendarTitle.count)个字，共六个字")
                    }
                }
                .padding(18)
                .background {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.72))
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
                    ThemePaletteIcon(palette: theme.palette)
                        .accessibilityHidden(true)
                        .frame(width: 33, height: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("主题色")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(theme.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("主题色，\(theme.title)")
            .accessibilityHint("选择日历的强调色")

            Button {
                isShapePickerPresented = true
            } label: {
                HStack(spacing: 14) {
                    SelectionShapeIcon(
                        shape: selectionShape,
                        color: theme.palette.accent,
                        size: 28
                    )
                        .accessibilityHidden(true)
                        .frame(width: 33, height: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("选中图形")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(selectionShape.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选中图形，\(selectionShape.title)")
            .accessibilityHint("选择日期和月份的选中图形")

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会员")
                .font(.title3.weight(.semibold))

            Button {
                isMembershipPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: membership.hasMembershipAccess ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(membership.hasMembershipAccess ? "已永久解锁" : "解锁全部表情和自定义")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(membership.hasMembershipAccess ? "全部权益已开启" : "一次购买，永久使用 · \(membership.product?.displayPrice ?? "¥12")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(membership.hasMembershipAccess ? "会员，已永久解锁" : "会员，永久解锁全部表情包和自定义")
        }
        .padding(.top, 40)
    }

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据管理")
                .font(.title3.weight(.semibold))

            Button(action: prepareDataBackup) {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("导出数据")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("保存每日记录和月便签")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("导出数据")
            .accessibilityHint("将每日记录和月便签保存为今日份 ZIP 文件")
        }
        .padding(.top, 32)
    }

    private func prepareDataBackup() {
        do {
            let entries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let monthlyNotes = try modelContext.fetch(FetchDescriptor<MonthlyNote>())
            backupDocument = DataBackupDocument(
                data: try DataBackupExporter.makeArchive(entries: entries, monthlyNotes: monthlyNotes)
            )
            isShowingBackupExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            exportError = error.localizedDescription
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("反馈")
                .font(.title3.weight(.semibold))

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
                        Text("联系")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(verbatim: "yui480145@gmail.com")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(18)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("联系，yui480145@gmail.com")
            .accessibilityHint("打开邮件发送反馈")
        }
        .padding(.top, 32)
    }

    private var feedbackEmailURL: URL {
        URL(string: "mailto:yui480145@gmail.com?subject=%E4%BB%8A%E6%97%A5%E4%BB%BD%E5%8F%8D%E9%A6%88")!
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒")
                .font(.title3.weight(.semibold))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("每日提醒")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Toggle("每日提醒", isOn: dailyReminderToggleBinding)
                    .labelsHidden()
                    .tint(theme.palette.strongAccent)
                    .disabled(DemoData.isEnabled)
                    .accessibilityLabel("每日提醒")
            }
            .padding(18)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(.top, 32)
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
                }
            }
        )
    }

    // Temporarily excluded for Personal Team device testing.
    #if ICLOUD_SYNC_ENABLED
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据同步")
                .font(.title3.weight(.semibold))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud 同步")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(iCloudStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if isCheckingICloud {
                    ProgressView()
                        .tint(theme.palette.strongAccent)
                        .frame(width: 52, height: 32)
                        .accessibilityLabel("正在检查 iCloud")
                } else {
                    Toggle("iCloud 同步", isOn: iCloudToggleBinding)
                        .labelsHidden()
                        .tint(theme.palette.strongAccent)
                        .disabled(!canEnableICloudSync && !isICloudSyncEnabled && !isPreviewingICloudEnabled)
                        .accessibilityLabel("iCloud 同步")
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
            .opacity(isICloudAccountAvailable || isCheckingICloud || isPreviewingICloudEnabled || isPreviewingICloudAccountAvailable ? 1 : 0.58)
            .overlay(alignment: .topTrailing) {
                if !isICloudAccountAvailable && !isCheckingICloud && !isPreviewingICloudEnabled && !isPreviewingICloudAccountAvailable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(7)
                        .background(theme.palette.background, in: Circle())
                        .offset(x: -8, y: 8)
                        .accessibilityHidden(true)
                }
            }


            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                Button("预览已登录、未开启（仅调试，不会同步）") {
                    isPreviewingICloudAccountAvailable = true
                    isPreviewingICloudEnabled = false
                }
                Button("预览已开启（仅调试，不会同步）") {
                    isPreviewingICloudAccountAvailable = false
                    isPreviewingICloudEnabled = true
                }
                if isPreviewingICloudAccountAvailable || isPreviewingICloudEnabled {
                    Button("退出 iCloud 预览") {
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
                    iCloudMessage = "已关闭；完全退出并重新打开 App 后停止同步"
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
            iCloudMessage = "演示模式不支持 iCloud 同步"
            return
        }
        do {
            let status = try await CKContainer(identifier: "iCloud.com.qingqing.MoodCalendar").accountStatus()
            isICloudAccountAvailable = status == .available
            if status == .noAccount {
                iCloudMessage = "请先在系统设置中登录 iCloud"
            } else if status == .available && !isICloudSyncEnabled {
                iCloudMessage = "可以开启 iCloud 同步"
            } else if status != .available {
                iCloudMessage = "当前无法使用 iCloud；请检查系统设置"
            }
        } catch {
            isICloudAccountAvailable = false
            iCloudMessage = "无法访问 iCloud；请检查系统设置和网络"
        }
    }

    @MainActor
    private func enableICloudSyncAfterValidation() async {
        guard !isCheckingICloud else { return }
        isCheckingICloud = true
        iCloudMessage = "正在检查 iCloud 账号和访问权限…"
        defer { isCheckingICloud = false }

        guard !DemoData.isEnabled else {
            isICloudSyncEnabled = false
            iCloudMessage = "演示模式不支持 iCloud 同步"
            return
        }

        do {
            let cloudContainer = CKContainer(identifier: "iCloud.com.qingqing.MoodCalendar")
            switch try await cloudContainer.accountStatus() {
            case .available:
                _ = try await cloudContainer.userRecordID()
                isICloudAccountAvailable = true
                isICloudSyncEnabled = true
                iCloudMessage = "iCloud 已连接；完全退出并重新打开 App 后开始自动同步。"
            case .noAccount:
                isICloudAccountAvailable = false
                failToEnableICloud("请先在系统设置中登录 iCloud")
            case .restricted:
                isICloudAccountAvailable = false
                failToEnableICloud("此设备当前无法使用 iCloud")
            case .temporarilyUnavailable:
                isICloudAccountAvailable = false
                failToEnableICloud("iCloud 暂时不可用，请稍后再试")
            case .couldNotDetermine:
                isICloudAccountAvailable = false
                failToEnableICloud("暂时无法确认 iCloud 状态，请稍后再试")
            @unknown default:
                isICloudAccountAvailable = false
                failToEnableICloud("无法确认 iCloud 状态，请稍后再试")
            }
        } catch {
            isICloudAccountAvailable = false
            isICloudSyncEnabled = false
            if let cloudError = error as? CKError, cloudError.code == .notAuthenticated {
                iCloudMessage = "请先在系统设置中登录 iCloud"
            } else {
                iCloudMessage = "无法访问此 App 的 iCloud 容器，请检查开发者签名和网络后重试"
            }
        }
    }

    @MainActor
    private func failToEnableICloud(_ message: String) {
        isICloudSyncEnabled = false
        iCloudMessage = message
    }

    #endif

    private var themePicker: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("主题色")
                    .font(.headline.weight(.semibold))

                HStack {
                    Spacer()
                    Button("完成") { isThemePickerPresented = false }
                        .font(.headline.weight(.semibold))
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
                                    .fill(option.palette.accent)
                                    .frame(width: 28, height: 28)
                                    .accessibilityHidden(true)
                                Text(option.title)
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
        .background(theme.palette.background)
    }

    private var shapePicker: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("选中图形")
                    .font(.headline.weight(.semibold))

                HStack {
                    Spacer()
                    Button("完成") { isShapePickerPresented = false }
                        .font(.headline.weight(.semibold))
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
                                color: theme.palette.accent,
                                size: [.star, .sakura, .leaf, .cat].contains(option) ? 32 : 28
                            )
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                            Text(option.title)
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
        .background(theme.palette.background)
    }
}
