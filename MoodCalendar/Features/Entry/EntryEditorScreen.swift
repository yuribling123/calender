import SwiftUI
import SwiftData

private struct NoteCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct EntryEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme

    let day: Date 
    let entry: MoodEntry?
    let initialGroup: ChoiceGroup

    @State private var selectedChoice: DailyChoice?
    @State private var selectedGroup: ChoiceGroup = .mood
    @State private var note = ""
    @State private var showsNote = false
    @State private var errorMessage: String?
    @State private var noteCardFrame: CGRect = .zero
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("今天想记什么？")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        ForEach(ChoiceGroup.allCases) { group in
                            Button { selectedGroup = group } label: {
                                Text(group.rawValue)
                                    .font(.subheadline.weight(selectedGroup == group ? .semibold : .regular))
                                    .foregroundStyle(selectedGroup == group ? .primary : .secondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(selectedGroup == group ? Color.white : .clear,
                                                in: RoundedRectangle(cornerRadius: 13))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                        }
                    }
                    .padding(4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 17))

                    HStack(alignment: .top, spacing: 4) {
                        ForEach(DailyChoice.choices(in: selectedGroup)) { choice in
                            Button { selectedChoice = choice } label: {
                                VStack(spacing: 6) {
                                    Image(choice.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 32)
                                        .scaleEffect(selectedGroup == .mood ? 1 : choice == .cake ? 1 : choice == .gather ? 1.48 : choice == .relax || choice == .study ? 1.38 : selectedGroup == .company ? 1.32 : 1.22)
                                        .accessibilityHidden(true)
                                    Text(choice.title)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
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
                            .accessibilityLabel("\(choice.title)，\(choice.caption)")
                            .accessibilityAddTraits(selectedChoice == choice ? .isSelected : [])
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 10) {
                        if showsNote {
                            TextEditor(text: $note)
                                .scrollContentBackground(.hidden)
                                .focused($isNoteFocused)
                                .frame(minHeight: 130)
                                .accessibilityLabel("文字记录")
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("写文字")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("文字是可选的，之后也可以修改。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("写文字")
                        }
                        if showsNote {
                            Text("文字是可选的，之后也可以修改。")
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
            .navigationTitle(day.formatted(.dateTime.month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedChoice == nil)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "请稍后再试。")
            }
            .onAppear {
                selectedChoice = entry?.choice
                selectedGroup = entry?.choice?.group ?? initialGroup
                note = entry?.note ?? ""
                showsNote = !(entry?.note.isEmpty ?? true)
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
        do {
            try EntryStore(context: modelContext).save(
                day: DayKey(day), choice: selectedChoice, note: showsNote ? note : ""
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
