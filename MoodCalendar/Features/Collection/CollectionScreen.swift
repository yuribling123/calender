import SwiftUI
import SwiftData
import UIKit

struct CollectionScreen: View {
    @Environment(\.appTheme) private var theme
// //     @AppStorage("collectionVinylSkin") private var storedVinylSkin = CollectionVinylSkin.original.rawValue
// //     @AppStorage("collectionTapeSkin") private var storedTapeSkin = CollectionTapeSkin.original.rawValue
    @ScaledMetric(relativeTo: .caption) private var thumbnailSize: CGFloat = 84
    @ScaledMetric(relativeTo: .footnote) private var songShelfWidth: CGFloat = 84
    @ScaledMetric(relativeTo: .footnote) private var watchShelfWidth: CGFloat = 84
    @Query private var entries: [MoodEntry]
    let onOpenDay: (Date) -> Void
    var category: CollectionCategory? = nil

    private var tabletItemScale: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 4.0 / 3.0 : 1 }
    private var photoItemSize: CGFloat { thumbnailSize * tabletItemScale }
    private var songItemWidth: CGFloat { songShelfWidth * tabletItemScale }
    private var watchItemWidth: CGFloat { watchShelfWidth * tabletItemScale }

    private var songs: [CollectedSong] { EntryCollection.songs(from: entries) }
    private var watches: [CollectedWatch] { EntryCollection.watches(from: entries) }
    private var photos: [CollectedMemory] { EntryCollection.photos(from: entries) }
    private var isEmpty: Bool { songs.isEmpty && watches.isEmpty && photos.isEmpty }

    var body: some View {
        if category == nil {
            NavigationStack { routedPage }
        } else {
            page
        }
    }

    private var page: some View {
        GeometryReader { geometry in
            Group {
                if category == .music, !songs.isEmpty {
                    SongCollectionList(songs: songs, onOpenDay: onOpenDay,
                                       usesColumns: UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 1000)
                } else if category == .watch, !watches.isEmpty {
                    WatchCollectionList(watches: watches, onOpenDay: onOpenDay,
                                        usesColumns: UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 1000)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if category == nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(localized("收藏"))
                                            .font(.system(size: 23, weight: .medium))
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44, alignment: .leading)
                                    .padding(.top, 4)
                                    Text(localized("生活里慢慢积攒的片段"))
                                        .font(.footnote)
                                        .foregroundStyle(theme.palette.collectionSecondaryInk)
                                }

                                collectionRack(spacing: UIDevice.current.userInterfaceIdiom == .pad
                                    ? max(48, min(100, (geometry.size.height - 600) / 2)) : 48)

                                if isEmpty {
                                    Text(localized("记下的歌曲、影视和照片，会自动汇集在这里。").trimmingCharacters(in: CharacterSet(charactersIn: "。.!！")))
                                        .font(.footnote)
                                        .foregroundStyle(theme.palette.collectionSecondaryInk)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 4)
                                }
                            } else if let category {
                                if category == .photo || count(category) == 0 {
                                    Text(countLabel(category))
                                        .font(.caption).foregroundStyle(theme.palette.collectionSecondaryInk)
                                        .padding(.top, 8)
                                }
                                categoryContent(category)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, category == nil ? 24 : 0)
                        .padding(.bottom, category == nil ? 16 : 32)
                    }
                }
            }
            .iPadFillPage()
            .background(theme.palette.collectionBackground)
            .foregroundStyle(theme.palette.collectionInk)
            .navigationTitle(category.map { localized($0.rawValue) } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(category == nil ? .hidden : .visible, for: .navigationBar)
        }
    }

    private var routedPage: some View {
        page
        .navigationDestination(for: CollectionCategory.self) { category in
            CollectionScreen(onOpenDay: onOpenDay, category: category)
        }
    }

    private func collectionRack(spacing: CGFloat) -> some View {
        // Keep the same gap from each shelf to the next heading, regardless of artwork height.
        VStack(spacing: spacing) {
            ForEach(CollectionCategory.allCases) { category in
                overviewSection(category)
            }
        }
        .padding(.top, 4)
    }

    private func overviewSection(_ category: CollectionCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader(category)
                .padding(.horizontal, 6)

            shelfContent(category)
                .frame(maxWidth: .infinity, minHeight: category == .music ? 68 : (category == .watch ? 60 : 100),
                       alignment: count(category) == 0 ? .center : .bottomLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.top, 32)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) {
                    CollectionWoodShelf().offset(y: 3)
                }
        }
    }

    @ViewBuilder
    private func shelfContent(_ category: CollectionCategory) -> some View {
        if count(category) == 0 {
            Color.clear
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: category == .photo ? 22 : 16) {
                    switch category {
                    case .music:
                        ForEach(songs) { song in
//                             CollectionSongRecord(song: song, diameter: songItemWidth, skin: .resolve(storedVinylSkin))
                            CollectionSongRecord(song: song, diameter: songItemWidth)
                                .frame(width: songItemWidth)
                        }
                    case .watch:
                        ForEach(watches) { watch in
//                             CollectionWatchTape(title: watch.title, kind: watch.kind, width: watchItemWidth, skin: .resolve(storedTapeSkin))
                            CollectionWatchTape(title: watch.title, kind: watch.kind, width: watchItemWidth)
                                .frame(width: watchItemWidth)
                        }
                    case .photo:
                        ForEach(photos) { memory in
                            photoItem(memory, thumbnail: true)
                                .frame(width: photoItemSize + 8)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func collectionHeader(_ category: CollectionCategory) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                sectionTitle(category)
                Spacer(minLength: 8)
                if count(category) > 0 {
                    viewAll(category)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle(category)
                if count(category) > 0 {
                    viewAll(category)
                }
            }
        }
    }

    private func sectionTitle(_ category: CollectionCategory) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(localized(category.sectionTitle))
                .font(.subheadline.weight(.medium))
            Text(countLabel(category))
                .font(.caption)
                .foregroundStyle(theme.palette.collectionSecondaryInk.opacity(0.9))
        }
    }

    private func viewAll(_ category: CollectionCategory) -> some View {
        NavigationLink(value: category) {
            HStack(spacing: 5) {
                Text(localized("查看全部"))
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium))
            }
            .font(.caption2)
            .foregroundStyle(theme.palette.strongAccent.opacity(0.85))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("查看全部") + localized(category.rawValue))
    }

    @ViewBuilder
    private func categoryContent(_ category: CollectionCategory) -> some View {
        if count(category) == 0 {
            Text(localized(category.emptyMessage).trimmingCharacters(in: CharacterSet(charactersIn: "。.!！")))
                .font(.subheadline).foregroundStyle(theme.palette.collectionSecondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
        } else {
            switch category {
            case .music:
                SongCollectionList(songs: songs, onOpenDay: onOpenDay)
            case .watch:
                WatchCollectionList(watches: watches, onOpenDay: onOpenDay)
            case .photo:
                LazyVGrid(columns: UIDevice.current.userInterfaceIdiom == .pad
                          ? [GridItem(.adaptive(minimum: 180), spacing: 24, alignment: .top)]
                          : [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 26) {
                    ForEach(photos) { memory in photoItem(memory, thumbnail: false) }
                }
            }
        }
    }

    private func photoItem(_ memory: CollectedMemory, thumbnail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CollectionPhoto(data: memory.entry.photoData, cropped: thumbnail)
                .aspectRatio(thumbnail ? 1 : photoRatio(memory.entry.photoData), contentMode: .fit)
                .frame(maxWidth: thumbnail ? photoItemSize : .infinity)
                .padding(thumbnail ? 4 : 0)
                .padding(.bottom, thumbnail ? 12 : 0)
                .background(thumbnail ? theme.palette.collectionPhotoMount : .clear)
                .overlay {
                    if thumbnail {
                        Rectangle().strokeBorder(theme.palette.collectionPaperEdge, lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
                }
                .shadow(color: thumbnail ? theme.palette.collectionShadow.opacity(0.65) : .clear, radius: 1, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localized("照片"))
    }

    private func count(_ category: CollectionCategory) -> Int {
        switch category { case .music: songs.count; case .watch: watches.count; case .photo: photos.count }
    }

    private func countLabel(_ category: CollectionCategory) -> String {
        switch category {
        case .music: localized("%lld 首", Int64(count(category)))
        case .watch: localized("%lld 部", Int64(count(category)))
        case .photo: localized("%lld 张", Int64(count(category)))
        }
    }

    private func photoRatio(_ data: Data?) -> CGFloat {
        guard let data, let image = UIImage(data: data), image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

}

enum CollectionCategory: String, CaseIterable, Identifiable {
    case music = "歌曲", photo = "照片", watch = "影视"
    var id: Self { self }
    var sectionTitle: String { rawValue }
    var symbol: String {
        switch self { case .music: "music.note.list"; case .watch: "film"; case .photo: "photo" }
    }
    var emptyMessage: String {
        switch self {
        case .music: "在每日记录里添加歌曲，它们会出现在这里。"
        case .watch: "在每日记录里添加影视，它们会出现在这里。"
        case .photo: "在每日记录里留下照片，它们会出现在这里。"
        }
    }
}

/// A matte walnut ledge with a softly lit top, rounded front and quiet horizontal grain.
private struct CollectionWoodShelf: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [theme.palette.collectionWoodHighlight, theme.palette.collectionWoodTop],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 3)
            Rectangle()
                .fill(LinearGradient(
                    colors: [theme.palette.collectionWoodFace, theme.palette.collectionWoodEdge],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 7)
                .overlay {
                    Canvas { context, size in
                        for index in 0..<4 {
                            let y = size.height * (CGFloat(index) + 0.5) / 4
                            var grain = Path()
                            grain.move(to: CGPoint(x: -4, y: y))
                            grain.addCurve(
                                to: CGPoint(x: size.width + 4, y: y + 0.3),
                                control1: CGPoint(x: size.width * 0.32, y: y - 1.2),
                                control2: CGPoint(x: size.width * 0.68, y: y + 1.2)
                            )
                            context.stroke(grain, with: .color(theme.palette.collectionWoodGrain),
                                           lineWidth: index.isMultiple(of: 2) ? 0.4 : 0.25)
                        }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .shadow(color: theme.palette.collectionShadow, radius: 3, x: 0, y: 3)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct CollectionPhoto: View {
    @Environment(\.appTheme) private var theme
    let data: Data?
    var cropped = false
    var body: some View {
        Color.clear.overlay {
            if let data, let image = UIImage(data: data) {
                if cropped {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            } else {
                Image(systemName: "photo").foregroundStyle(theme.palette.collectionSecondaryInk)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }
}

/// Shared record artwork keeps shelf and settings previews identical.
private struct CollectionSongRecord: View {
    let song: CollectedSong
    let diameter: CGFloat
    // let skin: CollectionVinylSkin

    var body: some View {
        CollectionVinylArtwork(title: song.title, artist: song.artist, diameter: diameter /*, skin: skin */)
    }
}

struct CollectionVinylArtwork: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let artist: String
    let diameter: CGFloat
    // let skin: CollectionVinylSkin

    var body: some View {
        CollectionDisc(/* skin: skin */)
            .frame(width: diameter, height: diameter)
            .overlay {
                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: diameter / 104 * 10, weight: .medium))
                        .foregroundStyle(theme.palette.collectionInk)
                        .lineLimit(2)
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: diameter / 104 * 9, weight: .regular))
                            .foregroundStyle(theme.palette.collectionSecondaryInk)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
                .frame(width: diameter * 0.52)
            }
            .shadow(color: theme.palette.collectionShadow, radius: 0.75, x: 0, y: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([title, artist].filter { !$0.isEmpty }.joined(separator: "，"))
    }
}

/// A plain black record with subtle grooves and a transparent center hole.
// Collection skin customization is temporarily disabled.
// struct CollectionDisc: View {
//     @Environment(\.appTheme) private var theme
//
//     var skin: CollectionVinylSkin = .original
//
//     var body: some View {
//         Canvas { context, size in
//             let diameter = min(size.width, size.height)
//             let bounds = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2,
//                                 width: diameter, height: diameter).insetBy(dx: 1, dy: 1)
//             let holeSize = diameter * 0.60
//             let hole = CGRect(x: bounds.midX - holeSize / 2, y: bounds.midY - holeSize / 2,
//                               width: holeSize, height: holeSize)
//             var surface = Path(ellipseIn: bounds)
//             surface.addEllipse(in: hole)
//             context.clip(to: surface, style: FillStyle(eoFill: true))
//             if skin == .rose {
//                 drawRoseVinyl(in: context, bounds: bounds, hole: hole)
//                 return
//             }
//             context.fill(Path(ellipseIn: bounds), with: .color(skin != .smoked ? theme.palette.collectionBlackDisc : theme.palette.collectionSmokedVinyl.opacity(0.82)))
//             for track in 1...(skin != .smoked ? 6 : 4) {
//                 let inset = diameter * (0.035 + CGFloat(track) * 0.029)
//                 context.stroke(Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
//                                with: .color(theme.palette.collectionDiscPrint.opacity(skin == .original ? 0.085 : (skin == .rose ? 0.13 : 0.22))),
//                                lineWidth: 0.5)
//             }
//             if skin == .smoked {
//                 let ring = bounds.insetBy(dx: diameter * 0.1, dy: diameter * 0.1)
//                 context.stroke(Path(ellipseIn: ring), with: .color(theme.palette.collectionSmokedVinyl.opacity(0.32)), lineWidth: diameter * 0.12)
//                 for (inset, thickness) in [(0.06, 0.025), (0.12, 0.01)] {
//                     var arc = Path()
//                     arc.addArc(center: CGPoint(x: bounds.midX, y: bounds.midY), radius: diameter * (0.5 - inset),
//                                startAngle: .degrees(-65), endAngle: .degrees(-20), clockwise: false)
//                     context.stroke(arc, with: .color(.white.opacity(0.18)), lineWidth: diameter * thickness)
//                 }
//             }
//             context.stroke(Path(ellipseIn: bounds.insetBy(dx: 1, dy: 1)),
//                            with: .linearGradient(Gradient(colors: [theme.palette.collectionDiscShade.opacity(0.24),
//                                                                    theme.palette.collectionDiscGleam.opacity(0.18),
//                                                                    theme.palette.collectionDiscShade.opacity(0.12)]),
//                                                  startPoint: .zero,
//                                                  endPoint: CGPoint(x: size.width, y: size.height)),
//                            lineWidth: 0.5)
//             context.stroke(Path(ellipseIn: hole.insetBy(dx: -diameter * 0.005, dy: -diameter * 0.005)),
//                            with: .color(skin == .rose ? theme.palette.collectionRecordLabelPaper.opacity(0.65)
//                                         : theme.palette.collectionDiscGleam.opacity(0.28)),
//                            lineWidth: diameter * 0.008)
//         }
//         .aspectRatio(1, contentMode: .fit)
//         .accessibilityHidden(true)
//     }
//
//     private func drawRoseVinyl(in context: GraphicsContext, bounds: CGRect, hole: CGRect) {
//         let palette = theme.palette
//         let diameter = bounds.width
//         func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
//             CGPoint(x: bounds.minX + x * diameter, y: bounds.minY + y * diameter)
//         }
//         context.fill(Path(ellipseIn: bounds), with: .color(palette.collectionRoseVinylBase))
//
//         // Broad, continuous pigment ribbons remain legible at shelf thumbnail sizes.
//         var upper = Path()
//         upper.move(to: point(-0.08, 0.26))
//         upper.addCurve(to: point(0.55, 0.17), control1: point(0.18, 0.03), control2: point(0.22, 0.43))
//         upper.addCurve(to: point(1.10, -0.05), control1: point(0.75, 0), control2: point(0.91, 0.12))
//         var lower = Path()
//         lower.move(to: point(-0.08, 0.64))
//         lower.addCurve(to: point(0.59, 0.84), control1: point(0.14, 0.88), control2: point(0.28, 0.54))
//         lower.addCurve(to: point(1.10, 0.93), control1: point(0.75, 1.02), control2: point(0.93, 0.70))
//         var side = Path()
//         side.move(to: point(0.87, -0.08))
//         side.addCurve(to: point(0.88, 0.70), control1: point(0.72, 0.23), control2: point(1.06, 0.39))
//         side.addCurve(to: point(0.93, 1.08), control1: point(0.76, 0.91), control2: point(0.99, 0.98))
//         for (ribbon, thickness) in [(upper, 0.055), (lower, 0.075), (side, 0.035)] {
//             context.stroke(ribbon, with: .color(palette.collectionRoseVinylLight.opacity(0.80)),
//                            style: StrokeStyle(lineWidth: diameter * thickness, lineCap: .round, lineJoin: .round))
//         }
//         var darkRibbon = Path()
//         darkRibbon.move(to: point(-0.06, 0.38))
//         darkRibbon.addCurve(to: point(0.35, 0.21), control1: point(0.15, 0.16), control2: point(0.12, 0.45))
//         context.stroke(darkRibbon, with: .color(palette.collectionRoseVinylDeep.opacity(0.38)),
//                        style: StrokeStyle(lineWidth: diameter * 0.022, lineCap: .round))
//         for radius in [0.455, 0.405, 0.35] {
//             let inset = diameter * (0.5 - radius)
//             context.stroke(Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
//                            with: .color(palette.collectionRoseVinylDeep.opacity(0.22)), lineWidth: 0.45)
//         }
//         context.stroke(Path(ellipseIn: bounds.insetBy(dx: 0.3, dy: 0.3)),
//                        with: .color(palette.collectionRoseVinylEdge.opacity(0.42)), lineWidth: 0.6)
//         context.stroke(Path(ellipseIn: hole.insetBy(dx: -0.25, dy: -0.25)),
//                        with: .color(palette.collectionRoseVinylDeep.opacity(0.30)), lineWidth: 0.5)
//     }
//
// }
//
struct CollectionDisc: View {
    @Environment(\.appTheme) private var theme


    var body: some View {
        Canvas { context, size in
            let diameter = min(size.width, size.height)
            let bounds = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2,
                                width: diameter, height: diameter).insetBy(dx: 1, dy: 1)
            let holeSize = diameter * 0.60
            let hole = CGRect(x: bounds.midX - holeSize / 2, y: bounds.midY - holeSize / 2,
                              width: holeSize, height: holeSize)
            var surface = Path(ellipseIn: bounds)
            surface.addEllipse(in: hole)
            context.clip(to: surface, style: FillStyle(eoFill: true))
            context.fill(Path(ellipseIn: bounds), with: .color(theme.palette.collectionBlackDisc))
            for track in 1...6 {
                let inset = diameter * (0.035 + CGFloat(track) * 0.029)
                context.stroke(Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
                               with: .color(theme.palette.collectionDiscPrint.opacity(0.085)),
                               lineWidth: 0.5)
            }
            context.stroke(Path(ellipseIn: bounds.insetBy(dx: 1, dy: 1)),
                           with: .linearGradient(Gradient(colors: [theme.palette.collectionDiscShade.opacity(0.24),
                                                                   theme.palette.collectionDiscGleam.opacity(0.18),
                                                                   theme.palette.collectionDiscShade.opacity(0.12)]),
                                                 startPoint: .zero,
                                                 endPoint: CGPoint(x: size.width, y: size.height)),
                           lineWidth: 0.5)
            context.stroke(Path(ellipseIn: hole.insetBy(dx: -diameter * 0.005, dy: -diameter * 0.005)),
                           with: .color(theme.palette.collectionDiscGleam.opacity(0.28)),
                           lineWidth: diameter * 0.008)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

}

private struct CollectionRecordDate: View {
    @Environment(\.appTheme) private var theme
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(theme.palette.collectionSecondaryInk)
            .lineLimit(1)
            .fixedSize()
    }
}

/// Keep selection and history as separate buttons, including for VoiceOver.
private struct CollectionListRow: View {
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .caption) private var numberWidth: CGFloat = 24
    let number: Int
    let title: String
    let subtitle: String
    let selected: Bool
    let isSong: Bool
    let onSelect: () -> Void
    let onShowRecords: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if selected {
                            if isSong {
                                CollectionEqualizer()
                            } else {
                                Image(systemName: "play.fill").font(.system(size: 11)).frame(height: 18)
                            }
                        } else {
                            Text(String(format: "%02d", number)).font(.caption.monospacedDigit())
                        }
                    }
                    .foregroundStyle(isSong ? theme.palette.collectionTrackNumberInk : theme.palette.collectionWatchNumberInk)
                    .frame(width: numberWidth, alignment: .leading)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.collectionInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(theme.palette.collectionSecondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? [.isSelected] : [])

            Button(action: onShowRecords) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.palette.collectionSecondaryInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localized("全部记录") + "，" + title)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(minHeight: 72, alignment: .leading)
        .background(selected ? theme.palette.collectionSelectedRow : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CollectionRecordHistory: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var artworkWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var moodArtworkWidth: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var artworkHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var recordTextSize: CGFloat = 14
    let title: String
    let subtitle: String
    let memories: [CollectedMemory]
    let isWatch: Bool
    let onOpenDay: (Date) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: titleSize, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(theme.palette.collectionSecondaryInk)
                        }
                    }
                    .padding(.bottom, 4)
                    ForEach(memories) { memory in
                        Button { onOpenDay(memory.date) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    CollectionRecordDate(date: memory.date)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(theme.palette.collectionSecondaryInk)
                                }
                                if let choice = memory.entry.choice {
                                    HStack(alignment: .center, spacing: 8) {
                                        ChoiceArtwork(choice: choice)
                                            .frame(width: choice.group == .mood ? moodArtworkWidth : artworkWidth,
                                                   height: artworkHeight)
                                            // Tighten the layout around the artwork's visible content.
                                            .padding(.horizontal, choice.group == .mood
                                                     ? -moodArtworkWidth * 0.06 : -artworkWidth * 0.29)
                                            .accessibilityHidden(true)
                                        Text(choice.title)
                                    }
                                }
                                if isWatch, let note = memory.entry.watchNote,
                                   !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(note)
                                        .lineSpacing(3)
                                }
                                Text(memory.entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? localized("这一天没有写下文字") : memory.entry.note)
                                    .lineSpacing(3)
                            }
                            .font(.system(size: recordTextSize))
                            .foregroundStyle(theme.palette.collectionInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(theme.palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .iPadReadableWidth()
                .foregroundStyle(theme.palette.collectionInk)
            }
            .background(theme.palette.collectionBackground)
            .navigationTitle(localized("全部记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .regular))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(localized("关闭"))
                }
            }
        }
    }
}

private struct CollectionCountLabel: View {
    @Environment(\.appTheme) private var theme
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .foregroundStyle(theme.palette.collectionSecondaryInk)
            CollectionHeart()
                .fill(theme.palette.collectionFavoriteHeart)
                .frame(width: 10, height: 9)
                .accessibilityHidden(true)
        }
        .font(.caption)
    }
}

private struct CollectionHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.height * 0.2),
                      control1: CGPoint(x: -rect.width * 0.4, y: rect.height * 0.38),
                      control2: CGPoint(x: rect.width * 0.1, y: -rect.height * 0.35))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      control1: CGPoint(x: rect.width * 0.9, y: -rect.height * 0.35),
                      control2: CGPoint(x: rect.width * 1.4, y: rect.height * 0.38))
        path.closeSubpath()
        return path
    }
}

private struct CollectionPageControls: View {
    @Environment(\.appTheme) private var theme
    let page: CollectionPage
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button { onSelect(page.index - 1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(page.index == 0)
            .accessibilityLabel(localized("上一页"))
            Text("\(page.index + 1) / \(page.count)")
                .font(.system(.caption, design: .monospaced))
                .accessibilityLabel(localized("第 %lld 页，共 %lld 页", page.index + 1, page.count))
            Button { onSelect(page.index + 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(page.index == page.count - 1)
            .accessibilityLabel(localized("下一页"))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.palette.collectionSecondaryInk)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct CollectionEqualizer: View {
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array([6.0, 13.0, 9.0, 16.0].enumerated()), id: \.offset) { _, height in
                Capsule().frame(width: 2, height: height)
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

/// A personal track list pairs each song with its artist and a quiet track number.
private struct AdaptiveMediaGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var usesColumns: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if usesColumns && !dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible())],
                      alignment: .leading, spacing: 16) {
                content()
            }
        } else {
            LazyVStack(spacing: 16) { content() }
        }
    }
}

private struct SongCollectionList: View {
    @Environment(\.appTheme) private var theme
// //     @AppStorage("collectionVinylSkin") private var storedVinylSkin = CollectionVinylSkin.original.rawValue
    @ScaledMetric(relativeTo: .body) private var headerDiscSize: CGFloat = 34
    @State private var pageIndex = 0
    @State private var selectedSongID: CollectedSong.Identity?
    @State private var recordSong: CollectedSong?
    let songs: [CollectedSong]
    let onOpenDay: (Date) -> Void
    var usesColumns = false
    private var page: CollectionPage { CollectionPage(itemCount: songs.count, requestedIndex: pageIndex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
//                     CollectionDisc(skin: .resolve(storedVinylSkin))
                    CollectionDisc()
                        .frame(width: headerDiscSize, height: headerDiscSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("我的歌单"))
                            .font(.headline.weight(.medium))
                            .foregroundStyle(theme.palette.collectionInk)
                        CollectionCountLabel(text: localized("%lld 首收藏", songs.count))
                    }
                }
                .padding(.top, 12)

                AdaptiveMediaGrid(usesColumns: usesColumns) {
                    ForEach(Array(songs.enumerated())[page.range], id: \.element.id) { index, song in
                        let selected = selectedSongID.map { $0 == song.id } ?? (index == page.range.lowerBound)
                        CollectionListRow(number: index + 1, title: song.title,
                                          subtitle: song.artist, selected: selected, isSong: true,
                                          onSelect: { selectedSongID = song.id },
                                          onShowRecords: { recordSong = song })
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CollectionPageControls(page: page) { index in
                pageIndex = index
                selectedSongID = nil
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(theme.palette.collectionBackground)
        }
        .sheet(item: $recordSong) { item in
            CollectionRecordHistory(title: item.title,
                                    subtitle: item.artist,
                                    memories: item.memories, isWatch: false) { date in
                recordSong = nil
                onOpenDay(date)
            }
        }
        .onChange(of: songs.map(\.id)) { _, _ in
            pageIndex = page.index
            selectedSongID = nil
        }
    }
}

/// A VHS cassette with tall reel windows flanking its central paper title label.
private struct OriginalCollectionWatchTape: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let kind: String
    let width: CGFloat

    var body: some View {
        ZStack {
            // A narrow lid sits above the broad textured face, as on a real VHS.
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.palette.collectionTapePack)
                .frame(width: width * 0.94, height: width * 0.045)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)

            HStack(spacing: width * 0.025) {
                tapeReel(offset: width * 0.075)

                Text(title)
                    .font(.system(size: width * 0.085, weight: .medium))
                    .foregroundStyle(theme.palette.collectionInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(width * 0.012)
                    // Six full-width characters use 0.51 of the shell width at this font size.
                    .frame(width: width * 0.58, height: width * 0.25)
                    .background(theme.palette.collectionBackground, in: RoundedRectangle(cornerRadius: 2))
                    .padding(width * 0.012)

                tapeReel(offset: -width * 0.075)
            }
            .offset(y: width * 0.005)

            RoundedRectangle(cornerRadius: 0.5)
                .fill(theme.palette.collectionTapeEdge.opacity(0.35))
                .frame(width: width * 0.94, height: 0.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, width * 0.025)
                .accessibilityHidden(true)
        }
        .frame(width: width, height: width * 0.56)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [theme.palette.collectionTapeBevel, theme.palette.collectionTapeShell],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Canvas { context, size in
                        // Fine molded plastic stippling, like the reference cassette shell.
                        for y in stride(from: 1.5, to: size.height, by: 1.5) {
                            for x in stride(from: 1.5, to: size.width, by: 1.5) {
                                let dot = CGRect(x: x, y: y, width: 0.45, height: 0.45)
                                context.fill(Path(ellipseIn: dot),
                                             with: .color(theme.palette.collectionTapeEdge.opacity(0.23)))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(theme.palette.collectionTapeEdge.opacity(0.28), lineWidth: 0.5)
                }
        }
        .shadow(color: theme.palette.collectionShadow, radius: 0.75, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + "，" + WatchKind.title(for: kind))
    }

    private func tapeReel(offset: CGFloat) -> some View {
        ZStack {
            theme.palette.collectionTapeWindow
            ZStack {
                Circle()
                    .strokeBorder(theme.palette.collectionTapePack, lineWidth: width * 0.055)
                ForEach(0..<6) { spoke in
                    Rectangle()
                        .fill(theme.palette.collectionTapeEdge.opacity(0.4))
                        .frame(width: 0.6, height: width * 0.09)
                        .offset(y: -width * 0.085)
                        .rotationEffect(.degrees(Double(spoke) * 60 + 15))
                }
                Circle()
                    .fill(theme.palette.collectionTapeHub)
                    .frame(width: width * 0.055, height: width * 0.055)
                Circle()
                    .fill(theme.palette.collectionTapeWindow)
                    .frame(width: 2, height: 2)
            }
            .frame(width: width * 0.33, height: width * 0.33)
            .offset(x: offset)
        }
        .frame(width: width * 0.16, height: width * 0.28)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    stops: [.init(color: .white.opacity(0.14), location: 0),
                            .init(color: .clear, location: 0.35),
                            .init(color: .clear, location: 0.7),
                            .init(color: .white.opacity(0.2), location: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(theme.palette.collectionTapeEdge.opacity(0.28), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

// Collection skin customization is temporarily disabled.
// struct CollectionWatchTape: View {
//     @Environment(\.appTheme) private var theme
//     let title: String
//     let kind: String
//     let width: CGFloat
//     var skin: CollectionTapeSkin = .original
//
//     var body: some View {
//         if skin == .original {
//             OriginalCollectionWatchTape(title: title, kind: kind, width: width)
//         } else {
//             styledTape
//         }
//     }
//
//     private var styledTape: some View {
//         ZStack {
//             if skin == .home {
//                 // A continuous smoky window and pale reels evoke a rental-store VHS.
//                 ZStack {
//                     RoundedRectangle(cornerRadius: width * 0.035)
//                         .fill(theme.palette.collectionTapeWindow)
//                         .overlay {
//                             RoundedRectangle(cornerRadius: width * 0.035)
//                                 .strokeBorder(theme.palette.collectionTapeEdge.opacity(0.4), lineWidth: 0.5)
//                         }
//                     HStack {
//                         rentalReel
//                         Spacer(minLength: 0)
//                         rentalReel
//                     }
//                     .padding(.horizontal, width * 0.01)
//                     label(labelWidth: 0.58, labelHeight: 0.29)
//                         .overlay {
//                             VStack {
//                                 Rectangle().frame(height: width * 0.012)
//                                 Spacer(minLength: 0)
//                                 Rectangle().frame(height: width * 0.012)
//                             }
//                             .foregroundStyle(theme.palette.collectionRentalRed)
//                             .padding(.vertical, width * 0.018)
//                             .padding(.horizontal, width * 0.02)
//                             .allowsHitTesting(false)
//                         }
//                 }
//                 .frame(width: width * 0.94, height: width * 0.32)
//                 .offset(y: width * 0.005)
//             } else {
//                 HStack {
//                     reel(diameter: width * 0.15)
//                     Rectangle().fill(theme.palette.collectionTapePack).frame(height: width * 0.01)
//                     reel(diameter: width * 0.15)
//                 }
//                 .padding(.horizontal, width * 0.09)
//                 .frame(width: width * 0.82, height: width * 0.18)
//                 .background(theme.palette.collectionTapeWindow, in: RoundedRectangle(cornerRadius: width * 0.02))
//                 .offset(y: -width * 0.10)
//
//                 label(labelWidth: 0.82, labelHeight: 0.22)
//                     .overlay(alignment: .leading) {
//                         Rectangle().fill(theme.palette.collectionWatchNumberInk.opacity(0.65))
//                             .frame(width: width * 0.025)
//                     }
//                     .clipShape(RoundedRectangle(cornerRadius: width * 0.012))
//                     .offset(y: width * 0.125)
//             }
//             VStack {
//                 Rectangle().frame(width: width * 0.94, height: width * 0.025)
//                 Spacer()
//                 Rectangle().frame(width: width * 0.90, height: 0.5)
//             }
//             .foregroundStyle(theme.palette.collectionTapeEdge.opacity(0.25))
//             .padding(.vertical, width * 0.025)
//         }
//         .frame(width: width, height: width * 0.56)
//         .background {
//             RoundedRectangle(cornerRadius: 3)
//                 .fill(LinearGradient(colors: skin == .home
//                     ? [theme.palette.collectionTapeBevel, theme.palette.collectionTapeShell]
//                     : [theme.palette.collectionTapeLabel, theme.palette.collectionArchiveTapeShell],
//                     startPoint: .topLeading, endPoint: .bottomTrailing))
//                 .overlay {
//                     if skin == .home {
//                         Canvas { context, size in
//                             for y in stride(from: 2.5, to: size.height, by: 2.5) {
//                                 for x in stride(from: 2.5, to: size.width, by: 2.5) {
//                                     context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.45, height: 0.45)),
//                                                  with: .color(theme.palette.collectionTapeEdge.opacity(0.08)))
//                                 }
//                             }
//                         }
//                         .clipShape(RoundedRectangle(cornerRadius: 3))
//                     }
//                 }
//                 .overlay {
//                     RoundedRectangle(cornerRadius: 3)
//                         .strokeBorder(theme.palette.collectionTapeEdge.opacity(0.28), lineWidth: 0.5)
//                 }
//         }
//         .shadow(color: theme.palette.collectionShadow, radius: 0.75, x: 0, y: 1)
//         .accessibilityElement(children: .ignore)
//         .accessibilityLabel(title + "，" + WatchKind.title(for: kind))
//     }
//
//     private func label(labelWidth: CGFloat, labelHeight: CGFloat) -> some View {
//         Text(title)
//             .font(.system(size: width * 0.085, weight: .medium))
//             .foregroundStyle(theme.palette.collectionTapeLabelInk)
//             .multilineTextAlignment(.center)
//             .lineLimit(2)
//             // Even the narrower label leaves 0.556W for six characters (0.51W).
//             .padding(.horizontal, width * 0.012)
//             .frame(width: width * labelWidth, height: width * labelHeight)
//             .background(skin == .home ? theme.palette.collectionRentalPaper : theme.palette.collectionVinylCreamPaper,
//                         in: RoundedRectangle(cornerRadius: 2))
//     }
//
//     private var rentalReel: some View {
//         ZStack {
//             Circle().fill(theme.palette.collectionRentalReel)
//             Circle().strokeBorder(theme.palette.collectionTapePack.opacity(0.6), lineWidth: width * 0.012)
//             ForEach(0..<3) { spoke in
//                 Capsule().fill(theme.palette.collectionTapeWindow.opacity(0.75))
//                     .frame(width: width * 0.026, height: width * 0.055)
//                     .offset(y: -width * 0.062)
//                     .rotationEffect(.degrees(Double(spoke) * 120))
//             }
//             Circle().fill(theme.palette.collectionTapePack)
//                 .frame(width: width * 0.05, height: width * 0.05)
//             Circle().fill(theme.palette.collectionRentalReel)
//                 .frame(width: width * 0.018, height: width * 0.018)
//         }
//         .frame(width: width * 0.23, height: width * 0.23)
//     }
//
//     private func reel(diameter: CGFloat) -> some View {
//         ZStack {
//             Circle().strokeBorder(theme.palette.collectionTapePack, lineWidth: diameter * 0.14)
//             ForEach(0..<3) { spoke in
//                 Rectangle().fill(theme.palette.collectionTapeEdge.opacity(0.5))
//                     .frame(width: 0.6, height: diameter * 0.24)
//                     .offset(y: -diameter * 0.29)
//                     .rotationEffect(.degrees(Double(spoke) * 120 + 15))
//             }
//             Circle().fill(theme.palette.collectionTapeHub)
//                 .frame(width: diameter * 0.25, height: diameter * 0.25)
//             Circle().fill(theme.palette.collectionTapeWindow).frame(width: 1.5, height: 1.5)
//         }
//         .frame(width: diameter, height: diameter)
//     }
// }
//
struct CollectionWatchTape: View {
    let title: String
    let kind: String
    let width: CGFloat

    var body: some View {
        OriginalCollectionWatchTape(title: title, kind: kind, width: width)
    }
}

/// A personal watchlist uses the same reading rhythm as the playlist.
private struct WatchCollectionList: View {
    @Environment(\.appTheme) private var theme
// //     @AppStorage("collectionTapeSkin") private var storedTapeSkin = CollectionTapeSkin.original.rawValue
    @ScaledMetric(relativeTo: .body) private var headerTapeWidth: CGFloat = 34
    @State private var pageIndex = 0
    @State private var selectedWatchID: CollectedWatch.Identity?
    @State private var recordWatch: CollectedWatch?
    let watches: [CollectedWatch]
    let onOpenDay: (Date) -> Void
    var usesColumns = false
    private var page: CollectionPage { CollectionPage(itemCount: watches.count, requestedIndex: pageIndex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    // CollectionWatchTape(title: "", kind: "", width: headerTapeWidth,
                    //                     skin: .resolve(storedTapeSkin))
                    CollectionWatchTape(title: "", kind: "", width: headerTapeWidth)
                        .frame(height: headerTapeWidth)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("我的片单"))
                            .font(.headline.weight(.medium))
                            .foregroundStyle(theme.palette.collectionInk)
                        CollectionCountLabel(text: localized("%lld 部收藏", watches.count))
                    }
                }
                .padding(.top, 12)

                AdaptiveMediaGrid(usesColumns: usesColumns) {
                    ForEach(Array(watches.enumerated())[page.range], id: \.element.id) { index, watch in
                        let selected = selectedWatchID.map { $0 == watch.id } ?? (index == page.range.lowerBound)
                        CollectionListRow(number: index + 1, title: watch.title,
                                          subtitle: WatchKind.title(for: watch.kind), selected: selected, isSong: false,
                                          onSelect: { selectedWatchID = watch.id },
                                          onShowRecords: { recordWatch = watch })
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CollectionPageControls(page: page) { index in
                pageIndex = index
                selectedWatchID = nil
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(theme.palette.collectionBackground)
        }
        .sheet(item: $recordWatch) { item in
            CollectionRecordHistory(title: item.title,
                                    subtitle: WatchKind.title(for: item.kind),
                                    memories: item.memories, isWatch: true) { date in
                recordWatch = nil
                onOpenDay(date)
            }
        }
        .onChange(of: watches.map(\.id)) { _, _ in
            pageIndex = page.index
            selectedWatchID = nil
        }
    }
}

// Collection skin customization is temporarily disabled.
// #Preview("收藏皮肤 · 浅色") {
//     CollectionSkinPreview().preferredColorScheme(.light)
// }
//
// #Preview("收藏皮肤 · 深色") {
//     CollectionSkinPreview().preferredColorScheme(.dark)
// }
//
// private struct CollectionSkinPreview: View {
//     @Environment(\.appTheme) private var theme
//     var body: some View {
//         VStack(spacing: 32) {
//             HStack(spacing: 12) {
//                 ForEach(CollectionVinylSkin.allCases) { skin in
//                     VStack(spacing: 12) {
//                         CollectionVinylArtwork(title: "晴天", artist: "周杰伦", diameter: 96, skin: skin)
//                         Text(skin.title)
//                     }
//                 }
//             }
//             HStack(spacing: 12) {
//                 ForEach(CollectionTapeSkin.allCases) { skin in
//                     VStack(spacing: 12) {
//                         CollectionWatchTape(title: "六个字的电影", kind: "movie", width: 100, skin: skin)
//                         Text(skin.title)
//                     }
//                 }
//             }
//         }
//         .font(.footnote)
//         .foregroundStyle(theme.palette.collectionInk)
//         .frame(maxWidth: .infinity, maxHeight: .infinity)
//         .background(theme.palette.collectionBackground)
//     }
// }
