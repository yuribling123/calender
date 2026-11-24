import SwiftUI
import UIKit

@MainActor
private enum MemoryDiscoverySession {
    static let store = MemoryDiscoveryStore(inMemory: DemoData.isEnabled)
}

/// Read-only rediscovery uses the same paper and content as the calendar.
struct MemoryShuffleScreen: View {
    private enum CardIdentity: Hashable {
        case preview(String)
        case draw(UUID)
    }

    let cardWidth: CGFloat
    let entries: [MoodEntry]
    var previewMemory: RediscoveredMemory? = nil
    var initialCardHeight: CGFloat = 0
    var isPreviewVisible = true
    let onClose: () -> Void
    let onOpenDay: (Date) -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .subheadline) private var referenceTextSize: CGFloat = 14
    @StateObject private var discovery = MemoryDiscoverySession.store
    @State private var draw: MemoryDraw?
    @State private var today = Date()
    @State private var showsHiddenDays = false
    @State private var isSwitching = false
    @State private var isLifted = false
    @State private var shuffleRequest = 0
    @State private var selectionGeneration = 0
    @State private var actionHeight: CGFloat = 84
    @State private var contentHeights: [String: CGFloat] = [:]
    @State private var allMemories: [RediscoveredMemory] = []

    private var palette: ThemePalette { theme.palette.resolved(for: colorScheme) }
    private var memories: [RediscoveredMemory] {
        allMemories.filter { !discovery.hiddenDays.contains($0.id) }
    }
    private var selected: RediscoveredMemory? {
        previewMemory ?? memories.first { $0.id == draw?.dayKey }
    }
    private var cardIdentity: CardIdentity? {
        if let previewMemory { return .preview(previewMemory.id) }
        return draw.map { .draw($0.id) }
    }
    private var entryRevision: [String] { entries.map { "\($0.id):\($0.updatedAt.timeIntervalSince1970)" } }

    var body: some View {
        GeometryReader { geometry in
            let availableCardHeight = max(1, geometry.size.height - (previewMemory == nil ? actionHeight : 0) - 36)
            // Same typography as the diary: date/sticker/padding plus twelve note lines.
            let twelveLineHeight = UIFont.systemFont(ofSize: referenceTextSize).lineHeight * 12 + 9 * 11
            let maximumCardHeight = max(1, min(114 + twelveLineHeight + 18, availableCardHeight))
            let measuredHeight: CGFloat? = selected.flatMap { memory in
                contentHeights[memory.id]
            }
            let fallbackHeight: CGFloat = previewMemory == nil
                ? maximumCardHeight : max(1, initialCardHeight)
            let requestedHeight: CGFloat = measuredHeight ?? fallbackHeight
            let cardHeight: CGFloat = min(maximumCardHeight, requestedHeight)
            let groupHeight = cardHeight + (previewMemory == nil ? 8 + actionHeight : 0)
            let upwardOffset = min(40, max(0, (geometry.size.height - groupHeight) / 2 - 12))
            ZStack {
                Color.black.opacity(colorScheme == .dark ? 0.32 : 0.16)
                    .ignoresSafeArea()
                    .opacity(previewMemory == nil || isPreviewVisible ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { if !isSwitching { onClose() } }
                    .accessibilityLabel(localized("关闭"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { if !isSwitching { onClose() } }
                VStack(spacing: 8) {
                    ZStack {
                        if let memory = selected {
                            cardPage(memory)
                                .offset(y: isLifted ? -5 : 0)
                                .scaleEffect(isLifted ? 1.005 : 1, anchor: .top)
                                .scaleEffect(previewMemory == nil || isPreviewVisible ? 1 : 0.94)
                                .opacity(previewMemory == nil || isPreviewVisible ? 1 : 0)
                                .id(cardIdentity)
                                .transition(cardTransition(width: geometry.size.width))
                                .zIndex(-Double(selectionGeneration))
                        } else {
                            emptyState
                        }
                    }
                    .frame(height: cardHeight)
                    .allowsHitTesting(!isSwitching)
                    .accessibilityHidden(isSwitching)
                    if previewMemory == nil { bottomActions
                        .transaction { $0.animation = nil }
                        .background {
                            GeometryReader { actions in
                                Color.clear.preference(key: MemoryActionHeightKey.self, value: actions.size.height)
                            }
                        }
                    }
                }
                .frame(width: min(cardWidth > 0 ? cardWidth : geometry.size.width - 48,
                                  geometry.size.width - 48))
                .offset(y: -upwardOffset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onPreferenceChange(MemoryActionHeightKey.self) { height in
            if abs(actionHeight - height) > 0.5 { actionHeight = height }
        }
        .onPreferenceChange(MemoryContentHeightKey.self) { heights in
            let updated = contentHeights.merging(heights) { _, new in new }
            if updated != contentHeights { contentHeights = updated }
        }
        .onChange(of: cardWidth) { _, _ in contentHeights = [:] }
        .onChange(of: referenceTextSize) { _, _ in contentHeights = [:] }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { if !isSwitching { onClose() } }
        .task(id: shuffleRequest) {
            if isSwitching { await shuffle() } else { refreshDay() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshDay()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            if !Calendar.current.isDate(date, inSameDayAs: today) { refreshDay() }
        }
        .onChange(of: entryRevision) { _, _ in refreshMemories(invalidateMeasurements: true) }
        .onChange(of: discovery.hiddenDays) { _, _ in ensureSelection() }
        .sheet(isPresented: $showsHiddenDays) { hiddenDaysScreen }
    }

    private func open(_ memory: RediscoveredMemory) {
        guard !isSwitching else { return }
        onOpenDay(memory.date)
    }

    private func cardPage(_ memory: RediscoveredMemory) -> some View {
        let paper = CardPaper.resolve(memory.entry.cardPaperID)
        return ScrollView {
            recordCard(memory)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { content in
                        Color.clear.preference(key: MemoryContentHeightKey.self,
                                               value: [memory.id: content.size.height])
                    }
                }
        }
        .scrollDisabled(isSwitching)
        .scrollBounceBehavior(.basedOnSize)
        .background {
            CardPaperBackground(paper: paper, cornerRadius: 18)
                .environment(\.colorScheme, paper == .nightHearts ? .dark : colorScheme)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: palette.foreground.opacity(isLifted ? 0.12 : 0.04),
                radius: isLifted ? 12 : 4, x: 0, y: isLifted ? 8 : 3)
    }

    private func recordCard(_ memory: RediscoveredMemory) -> some View {
        SelectedDateDetail(
            date: memory.date,
            entry: memory.entry,
            isReadOnly: true,
            showsYear: true,
            showsPaperBackground: false,
            onOpenRecord: { open(memory) },
            onRecordMood: { _ in },
            onEdit: {}
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { open(memory) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(memory.date.formatted(.dateTime.locale(AppLanguage.locale).year().month().day())), \(memory.entry.choice?.title ?? ""), \(memory.entry.locationName.map { "\(localized("地点"))：\($0)，" } ?? "")\(DemoData.displayText(memory.entry.note))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(localized("回到这一天"))
        .accessibilityAction { open(memory) }
    }

    private func cardTransition(width: CGFloat) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                .combined(with: .offset(y: 12)),
            removal: .modifier(
                active: DepartingMemoryCard(offset: -width - 40, angle: -4, opacity: 0),
                identity: DepartingMemoryCard(offset: 0, angle: 0, opacity: 1)
            )
        )
    }

    private var bottomActions: some View {
        VStack(spacing: 8) {
            if selected != nil {
                Button {
                    guard !isSwitching, memories.count > 1 else { return }
                    isSwitching = true
                    shuffleRequest += 1
                } label: {
                    Text(localized(memories.count == 1 ? "只有这一页" : "翻一翻"))
                }
                .buttonStyle(CocoaMemoryButtonStyle())
                .frame(minHeight: 56)
                .disabled(memories.count < 2)
            }
        }
        .padding(.bottom, selected == nil ? 0 : 12)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "book.closed")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(palette.strongAccent)
                .accessibilityHidden(true)
            Text(localized(allMemories.isEmpty ? "回忆慢慢来" : "先让这些日子休息一下"))
                .font(.headline)
            Text(localized(allMemories.isEmpty
                 ? "今天留下的片段，明天就能在这里遇见。不急着填满日历。"
                 : "过去的记录都还在。恢复一些日期，就可以继续随便翻翻。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
            if !discovery.hiddenDays.isEmpty {
                Button(localized("管理不再翻到的日期")) { showsHiddenDays = true }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    // Preserve access to dates hidden by the earlier rediscovery feature.
    private var hiddenDaysScreen: some View {
        NavigationStack {
            List {
                Section {
                    Text(localized("这里只显示日期，不展示那天的内容。恢复后，这一天会重新加入随机回忆。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(discovery.hiddenDays.sorted(by: >), id: \.self) { key in
                        HStack(spacing: 12) {
                            Text(MemoryShuffle.date(for: key)?.formatted(.dateTime.locale(AppLanguage.locale).year().month().day()) ?? key)
                                .font(.subheadline)
                            Spacer(minLength: 8)
                            Button(localized("恢复")) { discovery.restore(key) }
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel(localized("恢复 %@ 的回忆", key))
                        }
                    }
                    if discovery.hiddenDays.isEmpty {
                        Text(localized("还没有隐藏的日期"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(localized("不再翻到的日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("完成")) { showsHiddenDays = false }
                }
            }
        }
    }

    private func refreshDay() {
        let previousDay = DayKey(today)
        today = Date()
        refreshMemories(invalidateMeasurements: previousDay != DayKey(today))
    }

    private func refreshMemories(invalidateMeasurements: Bool = false) {
        guard previewMemory == nil else { return }
        allMemories = MemoryShuffle.memories(from: entries, today: today)
        if invalidateMeasurements {
            contentHeights = [:]
        } else {
            let validIDs = Set(allMemories.map(\.id))
            contentHeights = contentHeights.filter { validIDs.contains($0.key) }
        }
        ensureSelection()
    }

    private func ensureSelection() {
        guard !isSwitching, selected == nil else { return }
        draw = MemoryShuffle.draw(from: memories.map(\.id))
    }

    @MainActor
    private func shuffle() async {
        let usesReducedMotion = reduceMotion
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        feedback.prepare()
        defer {
            isLifted = false
            isSwitching = false
            ensureSelection()
        }
        do {
            if !usesReducedMotion {
                withAnimation(.easeOut(duration: 0.1)) { isLifted = true }
                try await Task.sleep(for: .milliseconds(100))
            }
            try Task.checkCancellation()
            guard let next = MemoryShuffle.draw(from: memories.map(\.id)) else { return }
            withAnimation(usesReducedMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.4)) {
                isLifted = false
                selectionGeneration += 1
                draw = next
            }
            try await Task.sleep(for: .milliseconds(usesReducedMotion ? 180 : 400))
            try Task.checkCancellation()
            feedback.impactOccurred(intensity: 0.45)
        } catch {
            // SwiftUI cancels this task when the overlay closes; never finish a stale draw.
        }
    }
}

private struct MemoryActionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MemoryContentHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

private struct CocoaMemoryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.regular))
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .foregroundStyle(theme.palette.background.opacity(isEnabled ? 1 : 0.75))
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? MemoryButtonColors.background : MemoryButtonColors.disabledBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(MemoryButtonColors.topEdge, lineWidth: 0.7)
                            .mask(alignment: .top) { Rectangle().frame(height: 8) }
                    }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

private struct DepartingMemoryCard: ViewModifier {
    let offset: CGFloat
    let angle: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle), anchor: .topLeading)
            .offset(x: offset, y: offset * 0.1)
            .opacity(opacity)
    }
}
