import SwiftUI
import CloudKit
import UIKit

private struct CalendarTitleCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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
    @AppStorage("appTheme") private var storedTheme = AppTheme.pink.rawValue
    @AppStorage("selectionShape") private var storedSelectionShape = SelectionShape.heart.rawValue
    @AppStorage("icloudSyncEnabled") private var isICloudSyncEnabled = false
    @AppStorage("calendarTitle") private var storedCalendarTitle = ""
    @Environment(\.appTheme) private var theme
    @Environment(\.selectionShape) private var selectionShape
    @State private var isThemePickerPresented = false
    @State private var isShapePickerPresented = false
    @State private var isCheckingICloud = false
    @State private var isICloudAccountAvailable = false
    @State private var iCloudMessage = "数据仅保存在本机。"
    @State private var calendarTitleCardFrame: CGRect = .zero
    @FocusState private var isCalendarTitleFocused: Bool

    private var canEnableICloudSync: Bool {
        isICloudAccountAvailable && !isCheckingICloud && !DemoData.isEnabled
    }

    private var iCloudStatusText: String {
        if isCheckingICloud {
            return "正在检查 iCloud 账号和访问权限…"
        }
        if isICloudSyncEnabled {
            return "iCloud 已连接；完全退出并重新打开 App 后开始同步。"
        }
        return iCloudMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("我的")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 16) {
                    Text("个性化")
                        .font(.title3.weight(.semibold))
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("日历标题")
                                    .font(.body.weight(.medium))
                                TextField("今日份", text: $storedCalendarTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .focused($isCalendarTitleFocused)
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
                    }

                    Button {
                        isThemePickerPresented = true
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(theme.palette.accent)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
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
                            Image(systemName: selectionShape.systemName)
                                .font(.system(size: 28))
                                .foregroundStyle(theme.palette.accent)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
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
                                    .disabled(!canEnableICloudSync && !isICloudSyncEnabled)
                                    .accessibilityLabel("iCloud 同步")
                            }
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                        .opacity(isICloudAccountAvailable || isCheckingICloud ? 1 : 0.58)
                        .overlay(alignment: .topTrailing) {
                            if !isICloudAccountAvailable && !isCheckingICloud {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(7)
                                    .background(theme.palette.background, in: Circle())
                                    .offset(x: -8, y: 8)
                                    .accessibilityHidden(true)
                            }
                        }

                        Text("开启或关闭均在完全退出并重新打开 App 后生效")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.palette.background)
            .onPreferenceChange(CalendarTitleCardFramePreferenceKey.self) {
                calendarTitleCardFrame = $0
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await validateSavedICloudSetting() }
            .sheet(isPresented: $isThemePickerPresented) {
                themePicker
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $isShapePickerPresented) {
                shapePicker
                    .presentationDetents([.medium])
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

    private var iCloudToggleBinding: Binding<Bool> {
        Binding(
            get: { isICloudSyncEnabled },
            set: { wantsICloudSync in
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

    private var themePicker: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ForEach(AppTheme.allCases) { option in
                    Button {
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
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(theme.palette.background)
            .navigationTitle("主题色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isThemePickerPresented = false }
                }
            }
        }
    }

    private var shapePicker: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ForEach(SelectionShape.allCases) { option in
                    Button {
                        storedSelectionShape = option.rawValue
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.systemName)
                                .font(.system(size: 28))
                                .foregroundStyle(theme.palette.accent)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                            Text(option.title)
                                .foregroundStyle(.primary)
                            Spacer()
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
            .padding(20)
            .background(theme.palette.background)
            .navigationTitle("选中图形")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isShapePickerPresented = false }
                }
            }
        }
    }
}
