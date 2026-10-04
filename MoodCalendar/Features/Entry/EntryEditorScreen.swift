import SwiftUI
import SwiftData

struct EntryEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let day: Date
    let entry: MoodEntry?

    @State private var selectedMood: Mood?
    @State private var note = ""
    @State private var showsNote = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("今天感觉怎么样？")
                            .font(.title2.bold())
                        ForEach(Mood.allCases) { mood in
                            Button { selectedMood = mood } label: {
                                HStack(spacing: 14) {
                                    Image(mood.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .accessibilityHidden(true)
                                    Text(mood.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedMood == mood {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(mood.color)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedMood == mood ? mood.color.opacity(0.20) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    if showsNote {
                        TextEditor(text: $note)
                            .frame(minHeight: 130)
                            .accessibilityLabel("文字记录")
                    } else {
                        Button("写文字") { showsNote = true }
                    }
                } footer: {
                    Text("文字是可选的，之后也可以修改。")
                }
            }
            .navigationTitle(day.formatted(.dateTime.month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedMood == nil)
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
                selectedMood = entry?.mood
                note = entry?.note ?? ""
                showsNote = !(entry?.note.isEmpty ?? true)
            }
        }
    }

    private func save() {
        guard let selectedMood else { return }
        do {
            try EntryStore(context: modelContext).save(
                day: DayKey(day), mood: selectedMood, note: showsNote ? note : ""
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
