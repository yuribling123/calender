import Foundation

/// Store stable IDs independently of the app's display language.
enum WatchKind: String, CaseIterable, Identifiable {
    case movie, series

    var id: String { rawValue }
    var title: String {
        switch self {
        case .movie: localized("电影")
        case .series: localized("剧集")
        }
    }

    static func title(for storedValue: String?) -> String {
        guard let storedValue, !storedValue.isEmpty else { return localized("影视") }
        return WatchKind(rawValue: storedValue)?.title ?? localized(storedValue)
    }
}
