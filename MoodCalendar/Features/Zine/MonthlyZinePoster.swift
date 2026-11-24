/* 暂时停用：界面实现保留，恢复时同时取消对应入口的注释。
import SwiftUI
import UIKit

/// Fixed export typography; height grows with the composition. No source text is silently clipped.
struct MonthlyZinePoster: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let month: Date
    let draft: MonthlyZineDraft
    let memories: [MoodEntry]
    let recordedCount: Int
    let photo: MoodEntry?
    let song: MoodEntry?
    let watch: MoodEntry?

    private var ink: Color { theme.palette.resolved(for: colorScheme).foreground }
    private var accent: Color { theme.palette.strongAccent }
    private var monthNumber: String { String(format: "%02d", Calendar.current.component(.month, from: month)) }
    private var year: String { String(Calendar.current.component(.year, from: month)) }
    private var title: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? localized("这一月，慢慢收藏") : draft.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            masthead
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 31, weight: .medium, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if draft.showsWriting, !draft.introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(draft.introduction)
                        .font(.system(size: 18)).lineSpacing(9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if draft.showsPhoto, let photo, let data = photo.photoData, let image = UIImage(data: data) {
                photoPrint(image, day: photo.dayKey)
            }
            if !memories.isEmpty {
                rule
                VStack(alignment: .leading, spacing: 23) {
                    ForEach(memories, id: \.dayKey) { memory in memoryRow(memory) }
                }
            }
            if draft.showsMusic, let song, let title = song.songTitle {
                mediaStrip(symbol: "opticaldisc", heading: localized("这一月的一首歌"), title: title,
                           subtitle: song.songArtist ?? "")
            }
            if draft.showsWatch, let watch, let title = watch.watchTitle {
                mediaStrip(symbol: "tv", heading: localized("这一月的一部影视"), title: title, subtitle: "")
            }
            rule
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localized("今日份"))
                        .font(.system(size: 13, weight: .medium))
                    Text(verbatim: "LITTLE TODAY · MONTHLY EDITION")
                        .font(.system(size: 8, weight: .medium)).tracking(1.5)
                        .foregroundStyle(ink.opacity(0.65))
                }
                Spacer()
                Text(localized("留作纪念"))
                    .font(.system(size: 11))
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(accent.opacity(0.45), lineWidth: 0.75))
                    .foregroundStyle(accent)
                    .rotationEffect(.degrees(-4))
            }
        }
        .foregroundStyle(ink)
        .padding(38)
        .background(theme.palette.notebookPaper)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent.opacity(0.23)).frame(width: 5)
        }
        .overlay {
            Rectangle().strokeBorder(theme.palette.notebookPageEdge, lineWidth: 1)
                .padding(13)
                .allowsHitTesting(false)
        }
    }

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 20) {
            Text(monthNumber)
                .font(.system(size: 78, weight: .light, design: .serif))
                .tracking(-4)
                .foregroundStyle(accent)
                .fixedSize()
            VStack(alignment: .leading, spacing: 8) {
                Text(year).font(.system(size: 15, weight: .medium, design: .monospaced)).tracking(3)
                Text(month.formatted(.dateTime.locale(AppLanguage.locale).month(.wide)))
                    .font(.system(size: 18, weight: .medium, design: .serif))
            }
            .padding(.bottom, 13)
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 7) {
                Text(localized("本月小刊")).font(.system(size: 12, weight: .medium))
                Text(localized("留下 %d 个日子", recordedCount))
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.65))
            }
            .padding(.bottom, 14)
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { rule }
    }

    private var rule: some View {
        Rectangle().fill(ink.opacity(0.14)).frame(height: 0.75)
    }

    private func memoryRow(_ memory: MoodEntry) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 5) {
                Text(String(memory.dayKey.suffix(2)))
                    .font(.system(size: 22, weight: .light, design: .serif))
                if let date = MonthlyZine.dayDate(memory.dayKey) {
                    Text(date.formatted(.dateTime.locale(AppLanguage.locale).weekday(.abbreviated)))
                        .font(.system(size: 9)).foregroundStyle(ink.opacity(0.65))
                }
            }
            .frame(width: 40)
            if let choice = memory.choice {
                ChoiceArtwork(choice: choice)
                    .scaledToFit().frame(width: 64, height: 48)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(memory.choice?.title ?? "")
                    .font(.system(size: 15, weight: .medium))
                if draft.showsWriting, !memory.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(MonthlyZine.excerpt(DemoData.displayText(memory.note), limit: 90))
                        .font(.system(size: 15)).lineSpacing(7)
                        .foregroundStyle(ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func photoPrint(_ image: UIImage, day: String) -> some View {
        let availableWidth: CGFloat = 488
        let height = min(340, availableWidth * image.size.height / max(1, image.size.width))
        let width = height * image.size.width / max(1, image.size.height)
        return VStack(spacing: 13) {
            Image(uiImage: image).resizable().scaledToFit().frame(width: width, height: height)
            Text(MonthlyZine.dayDate(day)?.formatted(.dateTime.locale(AppLanguage.locale).month().day()) ?? day)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(13)
        .padding(.bottom, 3)
        .background(theme.palette.collectionPhotoMount)
        .overlay(Rectangle().strokeBorder(theme.palette.collectionPaperEdge, lineWidth: 0.75))
    }

    private func mediaStrip(symbol: String, heading: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .ultraLight))
                .frame(width: 32, height: 32)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 7) {
                Text(heading).font(.system(size: 10)).foregroundStyle(ink.opacity(0.65))
                Text(MonthlyZine.excerpt(title, limit: 80))
                    .font(.system(size: 16, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(MonthlyZine.excerpt(subtitle, limit: 60))
                        .font(.system(size: 12)).foregroundStyle(ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 3))
    }
}

*/
