import SwiftUI
import SwiftData

@main
struct MoodCalendarApp: App {
    private let container: ModelContainer = {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: DemoData.isEnabled)
            return try ModelContainer(for: MoodEntry.self, configurations: configuration)
        } catch {
            fatalError("Unable to create the mood store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            CalendarScreen()
                .task {
                    #if DEBUG
                    if DemoData.isEnabled {
                        try? await MainActor.run { try DemoData.seed(into: container.mainContext) }
                    }
                    #endif
                }
        }
        .modelContainer(container)
    }
}
