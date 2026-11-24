import Foundation
import Combine

@MainActor
final class AppUpdateChecker: ObservableObject {
    @Published var availableUpdate: AppStoreUpdate?
    private var isChecking = false
    private let defaults = UserDefaults.standard
    private let lastAttemptKey = "appUpdate.lastAttempt"
    private let dismissedVersionsKey = "appUpdate.dismissedVersions"

    func checkIfNeeded() async {
        guard !DemoData.isEnabled, !isChecking, availableUpdate == nil,
              let bundleID = Bundle.main.bundleIdentifier,
              let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              AppUpdatePolicy.shouldCheck(now: Date(), lastAttempt: defaults.object(forKey: lastAttemptKey) as? Date)
        else { return }

        isChecking = true
        // Count attempts, including failures, so offline launches never repeatedly retry.
        defaults.set(Date(), forKey: lastAttemptKey)
        defer { isChecking = false }

        var endpoint = URLComponents(string: "https://itunes.apple.com/lookup")!
        endpoint.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US")
        ]
        guard let url = endpoint.url else { return }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(from: url)
            guard !Task.isCancelled,
                  let response = response as? HTTPURLResponse, response.statusCode == 200 else { return }
            let result = try JSONDecoder().decode(LookupResponse.self, from: data)
            let dismissed = defaults.stringArray(forKey: dismissedVersionsKey) ?? []
            guard let update = result.results.first(where: { $0.bundleId == bundleID }),
                  AppUpdatePolicy.shouldOffer(update, bundleID: bundleID, installed: installed, dismissed: dismissed) else { return }
            availableUpdate = update
        } catch {
            // Checking for updates is optional; networking failures stay silent.
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
