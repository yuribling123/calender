import SwiftUI
import SwiftData
import UIKit

struct MonthlyGoalScreen: View {
    let onOpenMonth: (Date) -> Void
    var initialMonth: Date? = nil
    var isSearchDestination = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Query private var entries: [MoodEntry]
    @Query private var monthlyNotes: [MonthlyNote]
    @EnvironmentObject private var membership: MembershipStore
    @Query private var monthlySkins: [MonthlyNoteSkinSelection]
    @State private var skinMonth: Date?
    @State private var draftNoteText = ""
    @AppStorage("allowPastDateEditing") private var allowPastDateEditing = true
    @State private var editingMonth: Date?
    @FocusState private var isNoteFocused: Bool
    @State private var saveError: String?
    @State private var isAddingNote = false
    @State private var didScrollToInitialMonth = false

    @ScaledMetric(relativeTo: .body) private var noteFontSize: CGFloat = 14
    private var noteLineSpacing: CGFloat {
        max(0, noteFontSize * 1.7 - UIFont.systemFont(ofSize: noteFontSize).lineHeight)
    }

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
        if isSearchDestination {
            monthlyContent
        } else {
            NavigationStack { monthlyContent }
        }
    }

    private var monthlyContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if isSearchDestination {
                    SearchReturnButton()
                        .padding(.horizontal, 24)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(localized("月便签"))
                                .font(.system(size: 23, weight: .medium))
                                .foregroundStyle(theme.palette.foreground)
                            Spacer()
                            Button { isAddingNote = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 19, weight: .regular))
                                    .foregroundStyle(theme.palette.strongAccent)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(localized("添加月便签"))
                        }
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
                                .id(monthKey(for: date))
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
            }
            .background(theme.palette.resolved(for: colorScheme).background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard !didScrollToInitialMonth, let date = initialMonth else { return }
                didScrollToInitialMonth = true
                await Task.yield()
                proxy.scrollTo(monthKey(for: date), anchor: .top)
            }
            .onChange(of: allowPastDateEditing) { _, enabled in
                if !enabled {
                    if let date = editingMonth, date < startOfCurrentMonth {
                        editingMonth = nil
                        isNoteFocused = false
                    }
                    if let date = skinMonth, date < startOfCurrentMonth {
                        skinMonth = nil
                    }
                }
            }
            .onChange(of: monthlyNotes.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
                try? MonthlyNoteStore(context: modelContext).reconcileDuplicates()
            }
            .onChange(of: monthlySkins.map { "\($0.id.uuidString)-\($0.skinID)-\($0.updatedAt.timeIntervalSince1970)" }) { _, _ in
                try? MonthlyNoteSkinStore(context: modelContext).reconcileDuplicates()
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
        .sheet(isPresented: Binding(
            get: { skinMonth != nil },
            set: { if !$0 { skinMonth = nil } }
        )) {
            if let date = skinMonth {
                MonthlyNoteSkinPicker(
                    monthTitle: date.formatted(.dateTime.locale(AppLanguage.locale).year().month()),
                    ticketNumber: monthKey(for: date).replacingOccurrences(of: "-", with: ""),
                    selected: MonthlyNoteSkinStore.skin(for: monthKey(for: date), in: monthlySkins)
                ) { skin in
                    guard canChangeSkin(for: date),
                          !skin.requiresMembership || membership.hasMembershipAccess else { return }
                    do {
                        try MonthlyNoteSkinStore(context: modelContext).select(
                            skin, for: monthKey(for: date), isMember: membership.hasMembershipAccess
                        )
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        }
        .allowsHitTesting(!isAddingNote)
        .accessibilityHidden(isAddingNote)
        .overlay {
            if isAddingNote {
                MonthlyNoteComposer(
                    notes: Dictionary(grouping: monthlyNotes, by: \.monthKey)
                        .compactMapValues { $0.max { $0.updatedAt < $1.updatedAt }?.text },
                    onClose: { isAddingNote = false }
                ) { date, text in
                    let hasChanges = text != (storedNote(for: date) ?? "")
                    try MonthlyNoteStore(context: modelContext).save(monthKey: monthKey(for: date), text: text)
                    if hasChanges { SaveFeedback.play() }
                }
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
                    HStack(alignment: .top) {
                        historicalMonthHeader(for: date)
                        Spacer()
                        if canChangeSkin(for: date) {
                            skinButton(for: date)
                        }
                    }
                    if editingMonth == date || data.note != nil {
                        MonthlyNoteSurface(
                            skin: displayedSkin(for: date),
                            monthLabel: date.formatted(.dateTime.locale(Locale(identifier: "en_US")).month(.abbreviated).year()).uppercased(),
                            ticketNumber: monthKey(for: date).replacingOccurrences(of: "-", with: "")
                        ) {
                            if editingMonth == date {
                                monthNoteEditor(for: date)
                            } else if let note = data.note {
                                Text(DemoData.displayText(note))
                                    .font(.system(size: noteFontSize, weight: .regular))
                                    .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink : displayedSkin(for: date) == .player ? theme.palette.monthlyPlayerInk : theme.palette.foreground)
                                    .lineSpacing(noteLineSpacing)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 20)
                    }
                    pastMonthSummary(data)
                        .padding(.top, editingMonth == date || data.note != nil ? 28 : 18)
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
                .foregroundStyle(theme.palette.strongAccent)
            HStack(spacing: 5) {
                Text(monthAbbreviation(for: date))
                    .tracking(1.2)
                    .foregroundStyle(theme.palette.strongAccent.opacity(0.7))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(localized("本月"))
                    .foregroundStyle(theme.palette.strongAccent)
                Spacer(minLength: 12)
                skinButton(for: date)
                    .padding(.vertical, -10)
            }
            .font(.caption)
            .frame(minHeight: 24)

            MonthlyNoteSurface(
                skin: displayedSkin(for: date),
                monthLabel: date.formatted(.dateTime.locale(Locale(identifier: "en_US")).month(.abbreviated).year()).uppercased(),
                ticketNumber: monthKey(for: date).replacingOccurrences(of: "-", with: ""),
                showsPlainBorder: false
            ) {
                monthNoteEditor(for: date)
            }
            .padding(.top, noteVerticalSpacing)
        }
        .accessibilityElement(children: .contain)
    }

    private func displayedSkin(for date: Date) -> MonthlyNoteSkin {
        // Preserve restored styles for viewing; membership is checked when selecting a style.
        MonthlyNoteSkinStore.skin(for: monthKey(for: date), in: monthlySkins)
    }

    private func canChangeSkin(for date: Date) -> Bool {
        if date == startOfCurrentMonth { return true }
        let hasNote = !(storedNote(for: date)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return allowPastDateEditing && date < startOfCurrentMonth && hasNote
    }

    private func skinButton(for date: Date) -> some View {
        Button {
            guard canChangeSkin(for: date) else { return }
            isNoteFocused = false
            skinMonth = date
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 17))
                .foregroundStyle(theme.palette.strongAccent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("月便签样式") + " " + date.formatted(.dateTime.locale(AppLanguage.locale).year().month()))
    }

    private func monthNoteEditor(for date: Date) -> some View {
        let noteText = storedNote(for: date) ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            if editingMonth == date {
                TextEditor(text: $draftNoteText)
                    .font(.system(size: noteFontSize, weight: .regular))
                    .lineSpacing(noteLineSpacing)
                    .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink : displayedSkin(for: date) == .player ? theme.palette.monthlyPlayerInk : theme.palette.foreground)
                    .focused($isNoteFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .onChange(of: draftNoteText) { _, value in
                        if value.count > noteCharacterLimit {
                            draftNoteText = String(value.prefix(noteCharacterLimit))
                        }
                    }
                    .accessibilityLabel(localized("月便签") + " " + date.formatted(.dateTime.locale(AppLanguage.locale).year().month()))

                HStack {
                    Text("\(draftNoteText.count) / \(noteCharacterLimit)")
                        .font(.system(size: 13))
                        .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink.opacity(0.7) : Color.secondary)
                    Spacer()
                    Button(localized("保存")) { saveNote(for: date) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink : theme.palette.strongAccent)
                }
            } else if noteText.isEmpty {
                HStack(spacing: 5) {
                    Text(localized("写一句话，留给这个月。"))
                        .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink.opacity(0.7) : Color.secondary)
                    Text("→")
                        .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink : theme.palette.strongAccent)
                }
                .font(.subheadline)
                .contentShape(Rectangle())
                .onTapGesture { beginNoteEditing(for: date) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(localized("写一句话，留给这个月"))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DemoData.displayText(noteText))
                        .font(.system(size: noteFontSize, weight: .regular))
                        /* 复古屏幕文字样式，保留供参考。
                        .tracking(MonthlyNoteSkinStore.skin(for: monthKey(for: date), in: monthlySkins) == .screen ? 1 : 0)
                        .foregroundStyle(MonthlyNoteSkinStore.skin(for: monthKey(for: date), in: monthlySkins) == .screen
                                         ? theme.palette.monthlyScreenInk : theme.palette.foreground)
                        .lineSpacing(MonthlyNoteSkinStore.skin(for: monthKey(for: date), in: monthlySkins) == .screen ? 8 : 6)
                        */
                        .foregroundStyle(displayedSkin(for: date) == .player2 ? theme.palette.monthlyPlayer2Ink : displayedSkin(for: date) == .player ? theme.palette.monthlyPlayerInk : theme.palette.foreground)
                        .lineSpacing(noteLineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)


                }
                .contentShape(Rectangle())
                    .onTapGesture { beginNoteEditing(for: date) }
                    .accessibilityAddTraits(.isButton)


            }
        }
    }

    private func beginNoteEditing(for date: Date) {
        guard date == startOfCurrentMonth || (allowPastDateEditing && date < startOfCurrentMonth) else { return }
        draftNoteText = DemoData.displayText(storedNote(for: date) ?? "")
        editingMonth = date
        DispatchQueue.main.async {
            isNoteFocused = true
        }
    }

    private func saveNote(for date: Date) {
        let text = String(draftNoteText.prefix(noteCharacterLimit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanges = text != (storedNote(for: date) ?? "")
        do {
            try MonthlyNoteStore(context: modelContext).save(
                monthKey: monthKey(for: date), text: text
            )
            if hasChanges { SaveFeedback.play() }
            isNoteFocused = false
            editingMonth = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func pastMonthSummary(_ data: MonthData) -> some View {
        Group {
            if let entry = data.summaryEntry, let choice = entry.choice {
                Button {
                    let parts = entry.dayKey.split(separator: "-").compactMap { Int($0) }
                    if parts.count == 3,
                       let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                        onOpenMonth(date)
                    }
                } label: {
                    summaryRow(title: data.recordCount < 3 ? localized("那个月记下了") : localized("出现最多的是"), choice: choice, entryNote: entry.note.trimmingCharacters(in: .whitespacesAndNewlines))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(localized("查看这个月的日历"))
            }
        }
    }

    private func historicalMonthHeader(for date: Date) -> some View {
        Button { onOpenMonth(date) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%02d", calendar.component(.month, from: date)))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(theme.palette.strongAccent)
                Text(monthAbbreviation(for: date))
                    .font(.caption)
                    .tracking(0.8)
                    .foregroundStyle(theme.palette.strongAccent.opacity(0.7))
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

    private func summaryRow(title: String, choice: DailyChoice, entryNote: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.strongAccent)

            HStack(alignment: .center, spacing: 8) {
                Text(choice.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.black.palette.strongAccent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                ChoiceArtwork(choice: choice)
                    .scaledToFit()
                    .frame(width: 56, height: 28)
                    // Account for the artwork's transparent margins in the row spacing.
                    .frame(width: choice.group == .mood ? 52 : 28, height: 28)
                    .accessibilityHidden(true)

                Text(DemoData.displayText(entryNote))
                    .font(.footnote)
                    .foregroundStyle(theme.palette.foreground.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private struct MonthData {
        let note: String?
        let summaryEntry: MoodEntry?
        let recordCount: Int
    }

    private func monthData(for date: Date) -> MonthData {
        let monthEntries = entriesForEachDay.filter { $0.dayKey.hasPrefix(monthKey(for: date)) }
        return MonthData(note: storedNote(for: date), summaryEntry: mostCommon(in: monthEntries), recordCount: monthEntries.compactMap(\.choice).count)
    }

    private var entriesForEachDay: [MoodEntry] {
        Dictionary(grouping: entries, by: \.dayKey).compactMap { _, dayEntries in
            dayEntries.max { $0.updatedAt < $1.updatedAt }
        }
    }

    private func mostCommon(in monthEntries: [MoodEntry]) -> MoodEntry? {
        let grouped = Dictionary(grouping: monthEntries.filter { $0.choice != nil }, by: { $0.choice! })
        guard let highestCount = grouped.values.map(\.count).max() else { return nil }
        // Only the most frequent stickers compete. Prefer a written entry, then the latest day.
        let candidates = grouped.values.filter { $0.count == highestCount }.flatMap { $0 }
        let writtenEntries = candidates.filter {
            !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return (writtenEntries.isEmpty ? candidates : writtenEntries).max { $0.dayKey < $1.dayKey }
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

/// A date stamp with two physical-looking wheels and one shared note editor.
private struct MonthlyNoteComposer: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    let notes: [String: String]
    let onClose: () -> Void
    let onSave: (Date, String) throws -> Void
    @State private var year = NoteMonthSelection().currentYear
    @State private var month = NoteMonthSelection().currentMonth
    @State private var isEditing = false
    @State private var draft = ""
    @State private var errorMessage: String?

    private var selection: NoteMonthSelection { NoteMonthSelection() }
    private var key: String { selection.key(year: year, month: month) }
    private var hasNote: Bool { notes[key]?.isEmpty == false }

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture { isFocused = false }
                .accessibilityHidden(true)
            GeometryReader { geometry in
                ScrollView {
                    device
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .tint(theme.palette.strongAccent)
        .accessibilityAddTraits(.isModal)
        .alert(localized("保存失败"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(localized("确定"), role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var device: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: "DATE STAMP")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(theme.palette.strongAccent.opacity(0.7))
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    isFocused = false
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(theme.palette.foreground.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("取消"))
            }
            .padding(.bottom, 16)

            display
                .padding(.bottom, 20)

            Button {
                if isEditing { save() } else { beginEditing() }
            } label: {
                Text(localized(isEditing ? "保存" : hasNote ? "打开便签" : "写下这个月"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.palette.strongAccent)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(StampPressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
        .background {
            RoundedRectangle(cornerRadius: 34)
                .fill(theme.palette.memoBody)
                .shadow(color: .black.opacity(0.14), radius: 24, y: 14)
        }
        .frame(maxWidth: 340)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isEditing)
        .task(id: isEditing) {
            guard isEditing else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(220)) }
                catch { return }
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled, isEditing else { return }
            isFocused = true
        }
        .onDisappear { isFocused = false }
    }

    private var display: some View {
        VStack(spacing: 12) {
            if isEditing {
                HStack {
                    Text(verbatim: String(format: "%04d", year) + " · " + monthAbbreviation(month))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.palette.strongAccent)
                    Spacer()
                    Button {
                        isFocused = false
                        isEditing = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("选择月份"))
                }
                TextEditor(text: $draft)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.palette.foreground)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(height: 112)
                    .padding(10)
                    .background(theme.palette.playerScreenBackground, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(localized("月便签"))
                    .onChange(of: draft) { _, text in
                        if text.count > 100 { draft = String(text.prefix(100)) }
                    }
                Text("\(draft.count) / 100")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    wheelWindow("YEAR", label: localized("选择年份")) {
                        Picker(localized("选择年份"), selection: Binding(
                            get: { year },
                            set: { value in
                                year = value
                                if year == selection.currentYear { month = min(month, selection.currentMonth) }
                            }
                        )) {
                            ForEach(1...selection.currentYear, id: \.self) { value in
                                Text(verbatim: String(format: "%04d", value))
                                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                                    .tag(value)
                            }
                        }
                    }
                    wheelWindow("MONTH", label: localized("选择月份")) {
                        Picker(localized("选择月份"), selection: $month) {
                            ForEach(1...(year == selection.currentYear ? selection.currentMonth : 12), id: \.self) { value in
                                Text(monthAbbreviation(value))
                                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                                    .tag(value)
                                    .accessibilityLabel(selection.monthName(value, locale: AppLanguage.locale))
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.palette.stampWheelBackground.shadow(
                            .inner(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 3, y: 2)
                        ))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(LinearGradient(
                                    colors: [theme.palette.playerScreenTopEdge.opacity(0.6), theme.palette.playerScreenBottomEdge],
                                    startPoint: .top, endPoint: .bottom
                                ), lineWidth: 0.7)
                        }
                }
                .overlay {
                    Rectangle()
                        .fill(theme.palette.foreground.opacity(0.08))
                        .frame(width: 0.5, height: 76)
                        .offset(y: 10)
                        .allowsHitTesting(false)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.palette.stampIndicator)
                        .frame(width: 5, height: 5)
                        .opacity(hasNote ? 1 : 0)
                        .accessibilityHidden(true)
                    Text(localized(hasNote ? "已有月便签" : "留一句话给这个月"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func wheelWindow<Content: View>(_ title: String, label: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(theme.palette.strongAccent.opacity(0.75))
                .accessibilityHidden(true)
            content()
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 104)
                .clipped()
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity)
    }

    private func monthAbbreviation(_ value: Int) -> String {
        var calendar = selection.calendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar.shortMonthSymbols[value - 1].uppercased()
    }

    private func beginEditing() {
        guard selection.isAllowed(year: year, month: month, allowPastDates: true) else { return }
        draft = DemoData.displayText(notes[key] ?? "")
        isEditing = true
    }

    private func save() {
        guard let date = selection.date(year: year, month: month) else { return }
        do {
            try onSave(date, String(draft.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines))
            isFocused = false
            onClose()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct StampPressStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(theme.palette.memoBody)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(LinearGradient(
                                colors: [theme.palette.accent.opacity(0.14), theme.palette.accent.opacity(0.24)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(LinearGradient(
                                colors: [.white.opacity(colorScheme == .dark ? 0.15 : 0.85), theme.palette.accent.opacity(0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.02 : 0.08),
                            radius: configuration.isPressed ? 0 : 2,
                            y: configuration.isPressed ? 0 : 2)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
    }
}
