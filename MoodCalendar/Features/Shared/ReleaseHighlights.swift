import SwiftUI
import AVFoundation
import UIKit

/// One page in the reusable "what's new" presentation.
struct ReleaseHighlightPage: Identifiable {
    let id: String
    let videoName: String
    let title: String
    let message: String
}

/// Update this configuration when preparing a new release.
/// Keep `id` stable for a published release so the presentation is only shown once.
struct ReleaseHighlights {
    let id: String
    let version: String
    let pages: [ReleaseHighlightPage]

    static let current = ReleaseHighlights(
        id: "release-highlights-1.1.1",
        version: "1.1.1",
        pages: [
            ReleaseHighlightPage(
                id: "weather-reactions",
                videoName: "weather-reactions",
                title: localized("天气也有小表情了"),
                message: localized("晴天、雨天，把今天的天气也一起记下来。")
            ),
            ReleaseHighlightPage(
                id: "heart-palettes",
                videoName: "heart-palettes",
                title: localized("给便签换颗爱心"),
                message: localized("新的爱心色卡，挑一张装下这个月的心情。")
            ),
            ReleaseHighlightPage(
                id: "entry-location",
                videoName: "entry-location",
                title: localized("把地点也留下"),
                message: localized("写下今天去过的地方，让回忆多一个小坐标。")
            ),
            ReleaseHighlightPage(
                id: "card-preview",
                videoName: "card-preview",
                title: localized("轻点卡片，展开看看"),
                message: localized("点开记录卡片，藏在里面的细节会完整出现。")
            ),
            ReleaseHighlightPage(
                id: "monthly-note-skins",
                videoName: "monthly-note-skins",
                title: localized("月便签换新衣了"),
                message: localized("新皮肤已经准备好，选一张陪你度过这个月。")
            )
        ]
    )
}

struct ReleaseHighlightsOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let release: ReleaseHighlights
    let theme: AppTheme
    let onDismiss: () -> Void

    @State private var selectedPage = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 0) {
                header

                TabView(selection: $selectedPage) {
                    ForEach(Array(release.pages.enumerated()), id: \.element.id) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 340)

                pageIndicator
                    .padding(.top, 4)

                Button(action: advance) {
                    Text(selectedPage == release.pages.count - 1 ? localized("收下啦") : localized("继续看看"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(theme.palette.onStrongAccent)
                        .background(buttonFill, in: Capsule())
                }
                .padding(.top, 22)
                .accessibilityHint(selectedPage == release.pages.count - 1
                    ? localized("关闭新功能介绍")
                    : localized("查看下一项新功能"))
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(theme.palette.accent.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            .padding(.horizontal, 24)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localized("这次带来了……"))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("V\(release.version)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("关闭"))
        }
    }

    private func pageView(_ page: ReleaseHighlightPage) -> some View {
        VStack(spacing: 16) {
            LoopingReleaseVideo(
                resourceName: page.videoName,
                isPlaying: page.id == release.pages[selectedPage].id
                    && scenePhase == .active
                    && !reduceMotion
            )
            .frame(maxWidth: .infinity)
            .frame(height: 236)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text(page.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(release.pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == selectedPage ? theme.palette.strongAccent : theme.palette.accent.opacity(0.3))
                    .frame(width: index == selectedPage ? 8 : 6, height: index == selectedPage ? 8 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selectedPage)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(format: localized("第 %d 页，共 %d 页"), selectedPage + 1, release.pages.count))
    }

    private func advance() {
        guard selectedPage < release.pages.count - 1 else {
            onDismiss()
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            selectedPage += 1
        }
    }

    private var buttonFill: Color {
        theme == .black ? theme.palette.selectionFill : theme.palette.todayButtonFill
    }
}

private struct LoopingReleaseVideo: UIViewRepresentable {
    let resourceName: String
    let isPlaying: Bool

    func makeUIView(context: Context) -> LoopingReleaseVideoView {
        LoopingReleaseVideoView()
    }

    func updateUIView(_ view: LoopingReleaseVideoView, context: Context) {
        view.configure(resourceName: resourceName)
        view.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: LoopingReleaseVideoView, coordinator: ()) {
        view.stop()
    }
}

private final class LoopingReleaseVideoView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var loadedResourceName: String?
    private var isPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(resourceName: String) {
        guard loadedResourceName != resourceName else { return }
        stop()
        loadedResourceName = resourceName

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mov") else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: item)
        playerLayer.player = queue
    }

    func setPlaying(_ shouldPlay: Bool) {
        guard shouldPlay != isPlaying else { return }
        isPlaying = shouldPlay
        if shouldPlay {
            player?.seek(to: .zero)
            player?.play()
        } else {
            player?.pause()
        }
    }

    func stop() {
        isPlaying = false
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
    }
}
