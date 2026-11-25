import Foundation
import Combine

@MainActor
final class AppUpdateChecker: ObservableObject {
    @Published var availableUpdate: AppStoreUpdate?
    @Published private(set) var isChecking = false
    enum CheckResult {
        case update(AppStoreUpdate)
        case upToDate
        case failed
        case skipped
    }
    private let defaults = UserDefaults.standard
    private let lastAttemptKey = "appUpdate.lastAttempt"
    private let dismissedVersionsKey = "appUpdate.dismissedVersions"

    @discardableResult
    func checkIfNeeded(manually: Bool = false) async -> CheckResult {
        guard (manually || !DemoData.isEnabled), !isChecking,
              (manually || availableUpdate == nil),
              let bundleID = Bundle.main.bundleIdentifier,
              let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              manually || AppUpdatePolicy.shouldCheck(now: Date(), lastAttempt: defaults.object(forKey: lastAttemptKey) as? Date)
        else { return .skipped }

        isChecking = true
        // One daily batch, including failures, contains at most three requests.
        defaults.set(Date(), forKey: lastAttemptKey)
        defer { isChecking = false }

        var endpoint = URLComponents(string: "https://itunes.apple.com/lookup")!
        endpoint.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US")
        ]
        guard let url = endpoint.url else { return .failed }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var lastResult = CheckResult.failed
        for _ in 0..<(manually ? 1 : 3) {
            guard !Task.isCancelled else { return .failed }
            lastResult = await performCheck(url: url, session: session, bundleID: bundleID, installed: installed, manually: manually)
            if case .update = lastResult { return lastResult }
        }
        return lastResult
    }

    private func performCheck(url: URL, session: URLSession, bundleID: String, installed: String, manually: Bool) async -> CheckResult {
        do {
            let (data, response) = try await session.data(from: url)
            guard !Task.isCancelled,
                  let response = response as? HTTPURLResponse, response.statusCode == 200 else { return .failed }
            let result = try JSONDecoder().decode(LookupResponse.self, from: data)
            let dismissed = defaults.stringArray(forKey: dismissedVersionsKey) ?? []
            guard let update = result.results.first(where: { $0.bundleId == bundleID }),
                  update.productURL != nil else { return .failed }
            if manually {
                return AppVersion.isNewer(update.version, than: installed) ? .update(update) : .upToDate
            }
            guard AppUpdatePolicy.shouldOffer(update, bundleID: bundleID, installed: installed, dismissed: dismissed) else { return .skipped }
            availableUpdate = update
            return .update(update)
        } catch {
            // Checking for updates is optional; networking failures stay silent.
            return .failed
        }
    }

    func dismiss(_ update: AppStoreUpdate) {
        var versions = defaults.stringArray(forKey: dismissedVersionsKey) ?? []
        if !versions.contains(update.version) { versions.append(update.version) }
        defaults.set(versions, forKey: dismissedVersionsKey)
        availableUpdate = nil
    }

    private struct LookupResponse: Decodable {
        let results: [AppStoreUpdate]
    }
}
