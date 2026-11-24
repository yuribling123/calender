import Foundation
import Combine

/// Small, device-local preferences. Demo never reads or writes the persistent list.
@MainActor
final class MemoryDiscoveryStore: ObservableObject {
    @Published private(set) var hiddenDays: Set<String>
    private let defaults: UserDefaults?
    private let key = "memoryDiscovery.hiddenDays.v1"

    init(defaults: UserDefaults = .standard, inMemory: Bool = false) {
        self.defaults = inMemory ? nil : defaults
        hiddenDays = inMemory ? [] : Set(defaults.stringArray(forKey: key) ?? [])
    }

    func hide(_ dayKey: String) {
        guard MemoryShuffle.date(for: dayKey) != nil else { return }
        hiddenDays.insert(dayKey)
        persist()
    }

    func restore(_ dayKey: String) {
        hiddenDays.remove(dayKey)
        persist()
    }

    func restoreAll() {
        hiddenDays.removeAll()
        persist()
    }

    private func persist() { defaults?.set(hiddenDays.sorted(), forKey: key) }
}
