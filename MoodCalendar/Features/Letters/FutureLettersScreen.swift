/* 暂时停用：界面实现保留，恢复时同时取消对应入口的注释。
import SwiftUI

/// A small local mailbox, separate from the calendar's read-only future days.
struct FutureLettersScreen: View {
    @EnvironmentObject private var store: FutureLetterStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var isComposing = false
    @State private var selectedLetter: FutureLetter?
    @State private var pendingDeletion: FutureLetter?
    @State private var errorMessage: String?

    private var palette: ThemePalette { theme.palette.resolved(for: colorScheme) }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                mailbox(today: DayKey(context.date))
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(localized("给未来的纸条"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("关闭")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isComposing = true } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(localized("写一张未来纸条"))
                    .disabled(store.loadError != nil)
                }
            }
            .sheet(isPresented: $isComposing) { FutureLetterComposer() }
            .sheet(item: $selectedLetter) { letter in
                FutureLetterReader(letterID: letter.id)
            }
            .confirmationDialog(localized("删除这张纸条？"), isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                Button(localized("删除"), role: .destructive) {
                    guard let letter = pendingDeletion else { return }
                    do { try store.delete(letter.id) }
                    catch { errorMessage = letterErrorMessage(error) }
                    pendingDeletion = nil
                }
                Button(localized("取消"), role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(localized("纸条删除后无法撤销。"))
            }
            .alert(localized("未能保存纸条"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.reload() }
            }
        }
        .tint(palette.strongAccent)
    }

    private func mailbox(today: DayKey) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(spacing: 15) {
                    LetterEnvelopeArt(isOpened: false)
                        .frame(width: 124, height: 84)
                        .accessibilityHidden(true)
                    Text(localized("把今天的一点心事，留给以后的自己。"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text(localized("纸条保存在本机，到约定日期后回到这里拆开。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                if let loadError = store.loadError {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(letterErrorMessage(loadError))
                            .font(.subheadline)
                        Text(localized("为保护原来的纸条，暂时不能新建或修改。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(localized("重新读取")) { store.reload() }
                            .frame(minHeight: 44)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                } else if store.letters.isEmpty {
                    VStack(spacing: 16) {
                        Text(localized("这里还没有寄出的纸条"))
                            .font(.headline.weight(.medium))
                        Text(localized("可以写一句期待，也可以认真写一封长信。"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button { isComposing = true } label: {
                            Text(localized("写第一张纸条"))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 24)
                                .frame(minHeight: 46)
                                .background(palette.softHighlight, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                } else {
                    section(localized("可以拆开了"),
                            letters: store.letters.filter { !$0.isOpened && $0.hasArrived(on: today) }, today: today)
                    section(localized("等一个约定的日子"),
                            letters: store.letters.filter { !$0.isOpened && !$0.hasArrived(on: today) }, today: today)
                    section(localized("已经拆开的纸条"),
                            letters: store.letters.filter(\.isOpened).sorted { ($0.openedAt ?? .distantPast) > ($1.openedAt ?? .distantPast) }, today: today)
                }
            }
            .padding(24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func section(_ title: String, letters: [FutureLetter], today: DayKey) -> some View {
        if !letters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(letters.count.formatted(.number.locale(AppLanguage.locale)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ForEach(letters) { letter in
                    HStack(spacing: 6) {
                        Button { selectedLetter = letter } label: {
                            HStack(spacing: 14) {
                                LetterEnvelopeArt(isOpened: letter.isOpened)
                                    .frame(width: 52, height: 42)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(letter.title.isEmpty ? localized("写给未来的自己") : letter.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(palette.foreground)
                                        .multilineTextAlignment(.leading)
                                    Text(letterDateText(letter.deliveryDay))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !letter.isOpened && letter.hasArrived(on: today) {
                                        Text(localized("约定的日子到了"))
                                            .font(.caption)
                                            .foregroundStyle(palette.strongAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 16)
                            .padding(.leading, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(localized(letter.isOpened ? "阅读纸条" : "查看约定日期与拆信选项"))
                        Menu {
                            Button(localized("删除"), role: .destructive) { pendingDeletion = letter }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(localized("纸条选项"))
                        .padding(.trailing, 4)
                    }
                    .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.foreground.opacity(0.06), lineWidth: 0.7)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}

private struct FutureLetterComposer: View {
    @EnvironmentObject private var store: FutureLetterStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var title = ""
    @State private var bodyText = ""
    @State private var deliveryDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var errorMessage: String?
    @State private var confirmsDiscard = false
    @FocusState private var isWriting: Bool

    private var palette: ThemePalette { theme.palette.resolved(for: colorScheme) }
    private var hasDraft: Bool { !title.isEmpty || !bodyText.isEmpty }
    private var firstDeliveryDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("收件人：未来的我"))
                            .font(.title3.weight(.medium))
                        Text(localized("写下时的心情，也会被好好保留。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        TextField(localized("给纸条起个名字（可不填）"), text: $title, axis: .vertical)
                            .font(.headline.weight(.medium))
                            .accessibilityLabel(localized("纸条标题"))
                        if !title.isEmpty {
                            Text(localized("标题 %d / 40 字", title.count))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(title.count > 40 ? Color.red : .secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Rectangle().fill(palette.foreground.opacity(0.1)).frame(height: 0.7)
                        ZStack(alignment: .topLeading) {
                            if bodyText.isEmpty {
                                Text(localized("嗨，以后的我……"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $bodyText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 230)
                                .focused($isWriting)
                                .accessibilityLabel(localized("纸条正文"))
                        }
                        .font(.body)
                        .lineSpacing(6)
                        Text(localized("%d / 3000 字", bodyText.count))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(bodyText.count > 3000 ? Color.red : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(20)
                    .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(palette.foreground.opacity(0.09), lineWidth: 0.7)
                            .allowsHitTesting(false)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker(localized("约定拆信日期"), selection: $deliveryDate,
                                   in: firstDeliveryDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.subheadline)
                            .tint(palette.strongAccent)
                        Text(localized("封好后正文会藏起来。没有到期推送，记得回来看看。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(localized("写于 %@", letterDateText(DayKey(.now))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(localized("写一张纸条"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("取消")) {
                        if hasDraft { confirmsDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("封好")) { save() }
                        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 40 || bodyText.count > 3000)
                }
            }
            .interactiveDismissDisabled(hasDraft)
            .confirmationDialog(localized("放下这张还没封好的纸条？"), isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button(localized("放弃这次书写"), role: .destructive) { dismiss() }
                Button(localized("继续写"), role: .cancel) {}
            } message: {
                Text(localized("未封好的内容不会保存。"))
            }
            .alert(localized("未能保存纸条"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(palette.strongAccent)
    }

    private func save() {
        do {
            try store.save(title: title, body: bodyText, deliveryDate: deliveryDate)
            isWriting = false
            SaveFeedback.play()
            dismiss()
        } catch { errorMessage = letterErrorMessage(error) }
    }
}

private struct FutureLetterReader: View {
    @EnvironmentObject private var store: FutureLetterStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let letterID: UUID
    @State private var confirmsEarlyOpening = false
    @State private var errorMessage: String?

    private var palette: ThemePalette { theme.palette.resolved(for: colorScheme) }
    private var letter: FutureLetter? { store.letters.first { $0.id == letterID } }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    if let letter {
                        VStack(alignment: .leading, spacing: 24) {
                            if letter.isOpened {
                                opened(letter)
                            } else {
                                sealed(letter, today: DayKey(context.date))
                            }
                        }
                        .padding(28)
                        .frame(maxWidth: 620)
                        .frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView(localized("这封纸条已经不存在了。"), systemImage: "envelope")
                    }
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(localized("给未来的纸条"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("关闭")) { dismiss() }
                }
            }
            .confirmationDialog(localized("要提前拆开吗？"), isPresented: $confirmsEarlyOpening, titleVisibility: .visible) {
                Button(localized("提前拆开")) { open(allowEarly: true) }
                Button(localized("再等等"), role: .cancel) {}
            } message: {
                Text(localized("拆开后会一直保留在已拆开的纸条里，不能重新封好。"))
            }
            .alert(localized("未能打开纸条"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(palette.strongAccent)
    }

    private func sealed(_ letter: FutureLetter, today: DayKey) -> some View {
        VStack(spacing: 24) {
            LetterEnvelopeArt(isOpened: false)
                .frame(width: 210, height: 145)
                .padding(.top, 36)
                .accessibilityHidden(true)
            Text(letter.title.isEmpty ? localized("写给未来的自己") : letter.title)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Text(localized("约定在 %@ 拆开", letterDateText(letter.deliveryDay)))
                    .font(.subheadline)
                Text(localized("写于 %@", letterDateText(letter.writtenDay)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if letter.hasArrived(on: today) {
                Text(localized("约定的日子到了，来听听那时的自己。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { open(allowEarly: false) } label: {
                    Text(localized("拆开纸条"))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 32)
                        .frame(minHeight: 48)
                        .background(palette.softHighlight, in: Capsule())
                }
            } else {
                Text(localized("正文已经藏好，等约定的日子再见。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(localized("想提前拆开")) { confirmsEarlyOpening = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func opened(_ letter: FutureLetter) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "envelope.open")
                Text(localized("从过去寄来的纸条"))
                    .font(.caption)
            }
            .foregroundStyle(palette.strongAccent)
            Text(letter.title.isEmpty ? localized("写给未来的自己") : letter.title)
                .font(.title2.weight(.medium))
                .textSelection(.enabled)
            Text(localized("写于 %@", letterDateText(letter.writtenDay)))
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().fill(palette.foreground.opacity(0.1)).frame(height: 0.7)
            Text(letter.body)
                .font(.body)
                .lineSpacing(9)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let openedAt = letter.openedAt {
                Text(localized("拆于 %@", letterDateText(DayKey(openedAt))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 20)
            }
        }
        .padding(24)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.foreground.opacity(0.08), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
    }

    private func open(allowEarly: Bool) {
        do {
            try withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                try store.open(letterID, allowEarly: allowEarly)
            }
            SaveFeedback.play()
        } catch { errorMessage = letterErrorMessage(error) }
    }
}

/// Theme-aware paper folds, with a quiet printed seal rather than glossy decoration.
private struct LetterEnvelopeArt: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let isOpened: Bool

    private var palette: ThemePalette { theme.palette.resolved(for: colorScheme) }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(palette.cardBackground)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 5, y: 3)
                RoundedRectangle(cornerRadius: 5)
                    .stroke(palette.strongAccent.opacity(0.2), lineWidth: 0.8)
                Path { path in
                    path.move(to: CGPoint(x: 1, y: size.height - 1))
                    path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.38))
                    path.addLine(to: CGPoint(x: size.width - 1, y: size.height - 1))
                }
                .stroke(palette.strongAccent.opacity(0.13), lineWidth: 0.8)
                Path { path in
                    path.move(to: CGPoint(x: 1, y: 1))
                    path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * (isOpened ? 0.12 : 0.57)))
                    path.addLine(to: CGPoint(x: size.width - 1, y: 1))
                    path.closeSubpath()
                }
                .fill(palette.softHighlight)
                Path { path in
                    path.move(to: CGPoint(x: 1, y: 1))
                    path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * (isOpened ? 0.12 : 0.57)))
                    path.addLine(to: CGPoint(x: size.width - 1, y: 1))
                }
                .stroke(palette.strongAccent.opacity(0.22), lineWidth: 0.8)
                if !isOpened {
                    Circle()
                        .fill(palette.accent.opacity(0.6))
                        .frame(width: size.width * 0.13, height: size.width * 0.13)
                        .overlay {
                            Image(systemName: "heart.fill")
                                .font(.system(size: size.width * 0.045))
                                .foregroundStyle(palette.strongAccent.opacity(0.65))
                        }
                        .offset(y: size.height * 0.07)
                }
            }
        }
    }
}

private func letterDateText(_ day: DayKey) -> String {
    guard let date = FutureLetter.date(for: day) else { return day.storageValue }
    return date.formatted(.dateTime.locale(AppLanguage.locale).year().month().day())
}

private func letterErrorMessage(_ error: Error) -> String {
    if let letterError = error as? FutureLetterError { return localized(letterError.messageKey) }
    return localized("纸条暂时无法读写，请稍后重试。")
}

*/
