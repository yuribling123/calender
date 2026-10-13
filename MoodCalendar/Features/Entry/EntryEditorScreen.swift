import SwiftUI
import SwiftData

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

    let day: Date
    let entry: MoodEntry?
    let initialGroup: ChoiceGroup
    let onSaved: (DailyChoice, Bool) -> Void

    @State private var selectedChoice: DailyChoice?
    @State private var selectedGroup: ChoiceGroup = .mood
    @State private var note = ""
    @State private var showsNote = false
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
                }
                .padding(24)
            }
            .background(theme.palette.background)
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
                        .disabled(selectedChoice == nil)
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
            .onAppear {
                selectedChoice = entry?.choice
                selectedGroup = entry?.choice?.group ?? initialGroup
                note = entry?.note ?? ""
                showsNote = !(entry?.note.isEmpty ?? true)
            }
        }
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
                            Image(choice.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .scaleEffect(selectedGroup == .mood ? 1 : choice == .cake ? 1 : choice == .gather ? 1.48 : choice == .relax || choice == .study ? 1.38 : selectedGroup == .company ? 1.32 : 1.22)
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
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
    }

    private var editorHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                editorTitle.fixedSize()
                Spacer(minLength: 0)
                if let choice = selectedChoice, choice.group == selectedGroup {
                    Text(choice.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                editorTitle
                if let choice = selectedChoice, choice.group == selectedGroup {
                    Text(choice.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorTitle: some View {
        Text(localized("今天想记什么？"))
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
                    Text(localized("文字可选，今天内可以修改。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(localized("写文字"))
            }
            if showsNote {
                Text(localized("文字可选，今天内可以修改。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.72))
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

    private func save() {
        guard let selectedChoice else { return }
        let savedNote = (showsNote ? note : "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanges = selectedChoice != entry?.choice || savedNote != (entry?.note ?? "")
        do {
            try EntryStore(context: modelContext).save(
                day: DayKey(day), choice: selectedChoice, note: showsNote ? note : "",
                isMember: hasPremiumAccess
            )
            onSaved(selectedChoice, hasChanges)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
