import SwiftData
import SwiftUI

@main
struct HydroHomieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}
