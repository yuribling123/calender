import SwiftUI
import SwiftData

struct MonthlyGoalScreen: View {
    let onOpenMonth: (Date) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Query private var entries: [MoodEntry]
    @Query private var monthlyNotes: [MonthlyNote]
    @State private var draftNoteText = ""
    @State private var isEditingCurrentNote = false
    @FocusState private var isCurrentNoteFocused: Bool
    @State private var saveError: String?

    private let noteCharacterLimit = 100
    private let noteVerticalSpacing: CGFloat = 32
    private let calendar = Calendar.current
    private var today: Date { Date() }
    private var startOfCurrentMonth: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today }
    private var visibleMonthDates: [Date] {
        let savedMonthKeys = Set(entries.map { String($0.dayKey.prefix(7)) } + monthlyNotes.map(\.monthKey))
        let historicalMonths = savedMonthKeys.compactMap(monthDate(for:))
            .filter { $0 < startOfCurrentMonth }
        return ([startOfCurrentMonth] + historicalMonths).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("月便签"))
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visibleMonthDates.enumerated()), id: \.element) { index, date in
                            if index == 1 { historyDivider }
                            if index > 0 && calendar.component(.year, from: date) != calendar.component(.year, from: visibleMonthDates[index - 1]) {
                                yearHeader(for: date)
                            }
                            monthSection(
                                for: date,
                                isFirstHistoricalMonth: index == 1,
                                isLastHistoricalMonth: index == visibleMonthDates.count - 1
                            )
                        }

                        if visibleMonthDates.count == 1 {
                            historyDivider
                            historyEmptyState
                        }
                    }
                    .padding(.bottom, 120)
                }
                .padding(24)
            }
            .background(theme.palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: monthlyNotes.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
                try? MonthlyNoteStore(context: modelContext).reconcileDuplicates()
            }
            .alert(localized("保存失败"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(localized("确定"), role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? localized("请稍后再试。"))
            }
        }
    }

    private func yearHeader(for date: Date) -> some View {
        Text(String(calendar.component(.year, from: date)))
            .font(.subheadline)
            .foregroundStyle(Color.gray)
            .padding(.top, 2)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private var historyDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)
            Text(localized("往月记录"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.top, 60)
        .padding(.bottom, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("之前的月份"))
    }

    private var historyEmptyState: some View {
        VStack(spacing: 8) {
            Text(localized("还没有留下记录"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary.opacity(0.76))
            Text(localized("试试来写吧"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .center)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localized("之前还没有留下记录，试试来写吧"))
    }

    private func monthSection(
        for date: Date,
        isFirstHistoricalMonth: Bool,
        isLastHistoricalMonth: Bool
    ) -> some View {
        let isCurrent = calendar.isDate(date, equalTo: startOfCurrentMonth, toGranularity: .month)
        let data = monthData(for: date)
        return HStack(alignment: .top, spacing: 14) {
            if !isCurrent {
                historyTimelineNode(
                    startsLine: isFirstHistoricalMonth,
                    endsLine: isLastHistoricalMonth
                )
            }
            VStack(alignment: .leading, spacing: 0) {
                if isCurrent {
                    currentMonthSection(for: date)
                } else {
                    historicalMonthHeader(for: date)
                    pastMonthContent(data)
                }
            }
            .padding(.bottom, isCurrent ? 0 : 48)
        }
    }

    private func historyTimelineNode(startsLine: Bool, endsLine: Bool) -> some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let nodeCenterY: CGFloat = 14.5
            Path { path in
                path.move(to: CGPoint(x: centerX, y: startsLine ? nodeCenterY : 0))
                path.addLine(to: CGPoint(x: centerX, y: endsLine ? nodeCenterY : proxy.size.height))
            }
            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)

            Circle()
                .fill(Color.secondary.opacity(0.38))
                .frame(width: 7, height: 7)
                .position(x: centerX, y: nodeCenterY)
        }
        .frame(width: 12)
        .accessibilityHidden(true)
    }

    private func currentMonthSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%02d", calendar.component(.month, from: date)))
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.primary)
            HStack(spacing: 5) {
                Text(monthAbbreviation(for: date))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(localized("本月"))
                    .foregroundStyle(theme.palette.strongAccent)
            }
            .font(.caption)

            currentMonthEditor
                .padding(.top, noteVerticalSpacing)
        }
        .accessibilityElement(children: .contain)
    }

    private var currentMonthEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditingCurrentNote {
                TextEditor(text: $draftNoteText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .focused($isCurrentNoteFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .onChange(of: draftNoteText) { _, value in
                        if value.count > noteCharacterLimit {
                            draftNoteText = String(value.prefix(noteCharacterLimit))
                        }
                    }
                    .accessibilityLabel(localized("编辑本月主题"))

                HStack {
                    Text("\(draftNoteText.count) / \(noteCharacterLimit)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(localized("保存")) { saveCurrentNote() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.palette.strongAccent)
                }
            } else if currentNoteText.isEmpty {
                HStack(spacing: 5) {
                    Text(localized("写一句话，留给这个月。"))
                        .foregroundStyle(.secondary)
                    Text("→")
                        .foregroundStyle(theme.palette.strongAccent)
                }
                .font(.subheadline)
                .contentShape(Rectangle())
                .onTapGesture { beginCurrentNoteEditing() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(localized("写一句话，留给这个月"))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentNoteText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    NoteWaveMark()
                        .stroke(theme.palette.accent.opacity(0.42), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                        .frame(width: 26, height: 7)
                        .padding(.top, noteVerticalSpacing)
                }
                .contentShape(Rectangle())
                    .onTapGesture { beginCurrentNoteEditing() }
                    .accessibilityAddTraits(.isButton)

                // HStack {
                //     Spacer()
                //     Button { beginCurrentNoteEditing() } label: {
                //         Label("编辑", systemImage: "pencil")
                //             .font(.footnote.weight(.medium))
                //             .foregroundStyle(theme.palette.strongAccent.opacity(0.82))
                //     }
                //     .accessibilityLabel("编辑本月主题")
                // }
            }
        }
    }

    private func beginCurrentNoteEditing() {
        draftNoteText = currentNoteText
        isEditingCurrentNote = true
        DispatchQueue.main.async {
            isCurrentNoteFocused = true
        }
    }

    private func saveCurrentNote() {
        let text = String(draftNoteText.prefix(noteCharacterLimit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanges = text != currentNoteText
        do {
            try MonthlyNoteStore(context: modelContext).save(
                monthKey: monthKey(for: startOfCurrentMonth),
                text: text
            )
            if hasChanges { SaveFeedback.play() }
            isCurrentNoteFocused = false
            isEditingCurrentNote = false
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func pastMonthContent(_ data: MonthData) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let note = data.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.76))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let choice = data.choice {
                summaryRow(title: data.recordCount < 3 ? localized("那个月记下了") : localized("出现最多的是"), value: choice.title)
            }
        }
        .padding(.top, 16)
    }

    private func historicalMonthHeader(for date: Date) -> some View {
        Button { onOpenMonth(date) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%02d", calendar.component(.month, from: date)))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.palette.strongAccent)
                Text(monthAbbreviation(for: date))
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(theme.palette.strongAccent.opacity(0.65))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("%@年%@月", String(describing: calendar.component(.year, from: date)), String(describing: calendar.component(.month, from: date))))
        .accessibilityHint(localized("查看这个月的日历"))
    }

    private func monthAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
    }

    private struct MonthData {
        let note: String?
        let choice: DailyChoice?
        let recordCount: Int
    }

    private func monthData(for date: Date) -> MonthData {
        let monthEntries = entriesForEachDay.filter { $0.dayKey.hasPrefix(monthKey(for: date)) }
        return MonthData(note: storedNote(for: date), choice: mostCommon(in: monthEntries), recordCount: monthEntries.compactMap(\.choice).count)
    }

    private var entriesForEachDay: [MoodEntry] {
        Dictionary(grouping: entries, by: \.dayKey).compactMap { _, dayEntries in
            dayEntries.max { $0.updatedAt < $1.updatedAt }
        }
    }

    private func mostCommon(in monthEntries: [MoodEntry]) -> DailyChoice? {
        let choices = monthEntries.compactMap(\.choice)
        guard !choices.isEmpty else { return nil }
        let counts = choices.reduce(into: [DailyChoice: Int]()) { $0[$1, default: 0] += 1 }
        let latest = monthEntries.reduce(into: [DailyChoice: String]()) { result, entry in
            guard let choice = entry.choice else { return }
            if entry.dayKey > (result[choice] ?? "") { result[choice] = entry.dayKey }
        }
        return counts.keys.max { lhs, rhs in
            if counts[lhs] != counts[rhs] { return counts[lhs]! < counts[rhs]! }
            return (latest[lhs] ?? "") < (latest[rhs] ?? "")
        }
    }

    private func monthDate(for key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              monthKey(for: date) == key else { return nil }
        return date
    }

    private func monthKey(for date: Date) -> String {
        String(format: "%04d-%02d", calendar.component(.year, from: date), calendar.component(.month, from: date))
    }

    private func storedNote(for date: Date) -> String? {
        monthlyNotes
            .filter { $0.monthKey == monthKey(for: date) }
            .max { $0.updatedAt < $1.updatedAt }?
            .text
    }
    private var currentNoteText: String { storedNote(for: startOfCurrentMonth) ?? "" }
}

private struct NoteWaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.16, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.34, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.66, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.84, y: rect.maxY)
        )
        return path
    }
}
