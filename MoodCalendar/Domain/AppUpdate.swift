import Foundation

/// App Store marketing versions contain dot-separated, nonnegative integers.
enum AppVersion {
    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        func components(_ value: String) -> [Int]? {
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            guard !parts.isEmpty else { return nil }
            var numbers: [Int] = []
            for part in parts {
                guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                      let number = Int(part) else { return nil }
                numbers.append(number)
            }
            return numbers
        }
        guard let lhs = components(candidate), let rhs = components(installed) else { return false }
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}

struct AppStoreUpdate: Decodable, Identifiable {
    let bundleId: String
    let version: String
    let trackViewUrl: URL
    var id: String { version }

    var productURL: URL? {
        guard trackViewUrl.scheme == "https", trackViewUrl.host == "apps.apple.com" else { return nil }
        return trackViewUrl
    }
}

struct AppUpdatePolicy {
    static func shouldOffer(_ update: AppStoreUpdate, bundleID: String, installed: String, dismissed: [String]) -> Bool {
        update.bundleId == bundleID && AppVersion.isNewer(update.version, than: installed)
            && !dismissed.contains(update.version) && update.productURL != nil
    }

    static func shouldCheck(now: Date, lastAttempt: Date?, calendar: Calendar = .current) -> Bool {
        guard let lastAttempt else { return true }
        // Clock rollback must not cause repeated requests.
        return now > lastAttempt && !calendar.isDate(now, inSameDayAs: lastAttempt)
    }
}
