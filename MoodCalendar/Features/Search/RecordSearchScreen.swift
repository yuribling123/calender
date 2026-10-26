import SwiftUI
import SwiftData
import UIKit

struct RecordSearchScreen: View {
    var starredDayKeys: Set<String> = []
    let onClose: () -> Void
    let onOpenResult: (RecordSearchResult) -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var entries: [MoodEntry]
    @State private var query = ""
    @State private var topResultID: String?
    @State private var isKeyboardVisible = false
    @State private var pendingResult: RecordSearchResult?
    @FocusState private var isSearchFocused: Bool
    @ScaledMetric(relativeTo: .body) private var contentFontSize: CGFloat = 14

    private var results: [RecordSearchResult] {
        RecordSearch.results(entries: entries, monthlyNotes: [], query: query)
    }

    private var resultMonths: [JournalMonth] {
        Dictionary(grouping: results) {
            Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }
        .map { JournalMonth(date: $0.key, results: $0.value) }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = min(390, max(0, geometry.size.width - 28))
            let height = min(width / 0.70, max(0, geometry.size.height - 24))

            ZStack {
                Color.black.opacity(colorScheme == .dark ? 0.38 : 0.18)
                    .ignoresSafeArea()
                    .onTapGesture { isSearchFocused = false }
                    .accessibilityHidden(true)

                notebook
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Measure to the same bottom edge before and after the tab bar hides.
        // Keyboard and tab bar safe-area changes must not recenter the notebook.
        .ignoresSafeArea(.all, edges: .bottom)
        .foregroundStyle(theme.palette.foreground)
        .tint(theme.palette.strongAccent)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, closeSearch)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            isKeyboardVisible = false
            // Let the restored keyboard safe area settle before pushing a destination.
            DispatchQueue.main.async { openPendingResult() }
        }
        .onDisappear {
            pendingResult = nil
            isSearchFocused = false
            isKeyboardVisible = false
        }
        .onChange(of: query) { _, _ in topResultID = nil }
    }

    private func requestOpenResult(_ result: RecordSearchResult) {
        guard pendingResult == nil else { return }
        pendingResult = result
        isSearchFocused = false
        if !isKeyboardVisible {
            // This also releases focus when a hardware keyboard is connected.
            DispatchQueue.main.async {
                guard !isKeyboardVisible else { return }
                openPendingResult()
            }
        }
    }

    private func openPendingResult() {
        guard let result = pendingResult else { return }
        pendingResult = nil
        onOpenResult(result)
    }

    private func closeSearch() {
        pendingResult = nil
        isSearchFocused = false
        onClose()
    }

    private var notebook: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 13)
                .fill(theme.palette.notebookCover)
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(theme.palette.foreground.opacity(0.09), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.11), radius: 8, y: 4)

            // Two thin sheets exposed only along the right and bottom edges.
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.palette.notebookPageEdge)
                .shadow(color: .black.opacity(0.12), radius: 0.8, x: 0.5, y: 1)
                .padding(.leading, 14)
                .padding(.trailing, 4.5)
                .padding(.top, 2)
                .padding(.bottom, 3)

            RoundedRectangle(cornerRadius: 7)
                .fill(theme.palette.memoBody)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(theme.palette.foreground.opacity(0.08), lineWidth: 0.5)
                }
                .padding(.leading, 13.5)
                .padding(.trailing, 5.75)
                .padding(.top, 1)
                .padding(.bottom, 4.5)

            notebookContents
                .background(theme.palette.notebookPaper)
                .overlay(alignment: .leading) {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), location: 0),
                            .init(color: .black.opacity(0.035), location: 0.3),
                            .init(color: .white.opacity(0.10), location: 0.65),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 18)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(theme.palette.foreground.opacity(0.10))
                            .frame(width: 0.5)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.leading, 13)
                .padding(.trailing, 7)
                .padding(.top, 0)
                .padding(.bottom, 6)

            ClothNotebookSpine()
                .frame(width: 13)
                .padding(.bottom, 2)
        }
    }

    private var notebookContents: some View {
        VStack(spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                journalHeader
                    .padding(.horizontal, 16)
            }

            ScrollView {
                VStack(spacing: 0) {
                    if dynamicTypeSize.isAccessibilitySize {
                        journalHeader
                            .padding(.horizontal, 16)
                    }
                    journalEntries
                        .padding(.horizontal, 12)
                }
                .padding(.bottom, 24)
            }
            .scrollPosition(id: $topResultID, anchor: .top)
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [theme.palette.notebookPaper.opacity(0), theme.palette.notebookPaper],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 18)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, 8)
    }

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(localized("找一找"))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .tracking(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: closeSearch) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("关闭"))
            }
            // if !isSearchFocused {
            //     Text(localized("那些记下来的日子"))
            //         .font(.caption)
            //         .foregroundStyle(.secondary)
            //         .padding(.top, 2)
            // }

            searchField
                .padding(.top, 6)
                .disabled(pendingResult != nil)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text(localized(
                    query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "共记录了 %@ 个日子" : "找到 %@ 条回忆",
                    String(results.count)
                ))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(theme.palette.foreground.opacity(0.65))
                .accessibilityHidden(true)
            TextField(localized("搜索写过的文字"), text: $query,
                      prompt: Text(localized("搜索写过的文字"))
                        .foregroundColor(theme.palette.foreground.opacity(0.60)))
                .font(.system(size: contentFontSize))
                .foregroundStyle(theme.palette.foreground)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit { isSearchFocused = false }
                .accessibilityLabel(localized("搜索写过的文字"))
            if !query.isEmpty {
                Button { query = ""; isSearchFocused = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("清除搜索"))
            }
        }
        .padding(.leading, 2)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.palette.foreground.opacity(isSearchFocused ? 0.35 : 0.16))
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
    }

    private var journalEntries: some View {
        Group {
            if results.isEmpty {
                emptyState.padding(.horizontal, 12)
            } else {
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(resultMonths) { month in
                        Section {
                            ForEach(month.results) { result in
                                Button {
                                    requestOpenResult(result)
                                } label: {
                                    SearchResultRow(
                                        result: result,
                                        query: query,
                                        isStarred: result.source == .day && starredDayKeys.contains(DayKey(result.date).storageValue)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityHint(localized(result.source == .day ? "查看这一天的日历" : "查看这个月的便签"))
                                .id(result.id)
                            }
                        } header: {
                            monthHeader(month.date, isFirst: month.id == resultMonths.first?.id)
                        }
                    }
                }
                .scrollTargetLayout()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func monthHeader(_ date: Date, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.locale(AppLanguage.locale).year().month(.abbreviated)))
                .font(.system(size: contentFontSize, weight: .medium, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(theme.palette.foreground.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(theme.palette.foreground.opacity(0.12))
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .padding(.top, isFirst ? 6 : 14)
        .padding(.bottom, 5)
        .background(theme.palette.notebookPaper)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        let hasWrittenNotes = entries.contains { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return VStack(spacing: 10) {
            Text(localized(hasWrittenNotes ? "没有找到这段回忆" : "还没有写下文字"))
                .font(.subheadline)
            Text(localized(hasWrittenNotes ? "试试短一点的词。" : "写下的话，以后都能在这里找到。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }

    private struct JournalMonth: Identifiable {
        let date: Date
        let results: [RecordSearchResult]
        var id: Date { date }
    }
}

struct SearchReturnButton: View {
    var title = localized("返回搜索")
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                    Text(title)
                }
                .font(.subheadline)
                .foregroundStyle(theme.palette.strongAccent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }
}

private struct SearchResultRow: View {
    @AppStorage("calendarBookmarkStyle") private var storedBookmarkStyle = CalendarBookmarkStyle.dateColor.rawValue
    let result: RecordSearchResult
    let query: String
    let isStarred: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var noteFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var secondaryFontSize: CGFloat = 11

    private var paper: Color {
        CardPaper.resolve(result.cardPaperID).swatchAccent(for: theme)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 7) {
                    dateStamp
                    noteLine
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    dateStamp.frame(minWidth: 32, alignment: .leading)
                    noteLine
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .foregroundStyle(theme.palette.foreground)
        .overlay(alignment: .bottom) {
            if result.source == .day {
                Rectangle()
                    .fill(theme.palette.foreground.opacity(0.09))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            if result.source == .day {
                Capsule()
                    .fill(paper)
                    .frame(width: 4, height: 22)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    private var noteLine: some View {
        HStack(spacing: 8) {
            if let choice = result.choice {
                // Balance visible subjects rather than their transparent canvases.
                let canvasWidth: CGFloat = switch choice.group {
                case .mood: 42
                case .daily: 50
                case .rabbit: 52
                default: 60
                }
                ChoiceArtwork(choice: choice)
                    .frame(width: canvasWidth, height: canvasWidth / 2)
                    .frame(width: 40, height: 30)
                    .accessibilityLabel(choice.title)
            } else if result.source == .month {
                Image(systemName: "note.text")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(theme.palette.foreground.opacity(0.63))
                    .frame(width: 40, height: 30)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                highlighted(result.preview)
                    .font(.system(size: noteFontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var dateStamp: some View {
        VStack(alignment: .leading, spacing: 2) {
            if result.source == .day {
                Text(result.date.formatted(.dateTime.locale(AppLanguage.locale).day()))
                    .monospacedDigit()
                    .foregroundStyle(isStarred
                        ? (CalendarBookmarkStyle.resolve(storedBookmarkStyle) == .dateColor ? CalendarBookmarkStyle.ink : theme.palette.bookmarkHighlightInk)
                        : theme.palette.foreground.opacity(0.63))
                    .background {
                        if isStarred && CalendarBookmarkStyle.resolve(storedBookmarkStyle) == .highlighter {
                            BookmarkHighlight()
                        }
                    }
                Text(result.date.formatted(.dateTime.locale(AppLanguage.locale).weekday(.abbreviated)))
            } else {
                Text(localized("月便签"))
                    .font(.system(size: secondaryFontSize))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 32, alignment: .leading)
            }
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(theme.palette.foreground.opacity(0.63))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func highlighted(_ text: String) -> Text {
        let keyword = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !keyword.isEmpty else { return Text(text).foregroundColor(theme.palette.foreground) }
        var remaining = text[...]
        var output = Text("")
        while let range = remaining.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive], locale: AppLanguage.locale) {
            output = output
                + Text(String(remaining[..<range.lowerBound])).foregroundColor(theme.palette.foreground)
                + Text(String(remaining[range])).foregroundColor(theme.palette.strongAccent)
            remaining = remaining[range.upperBound...]
        }
        return output + Text(String(remaining)).foregroundColor(theme.palette.foreground)
    }
}

