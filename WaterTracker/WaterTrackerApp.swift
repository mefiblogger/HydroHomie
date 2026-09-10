import SwiftData
import SwiftUI

@main
struct WaterTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}
