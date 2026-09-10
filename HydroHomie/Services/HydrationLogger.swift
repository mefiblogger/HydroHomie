import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// Single funnel for adding and removing drinks so that haptics, HealthKit mirroring
/// and widget refresh happen consistently wherever a change originates.
@MainActor
enum HydrationLogger {

    static func add(amountML: Double, settings: UserSettings, context: ModelContext) {
        let entry = DrinkEntry(amountML: amountML, source: .app)
        context.insert(entry)
        try? context.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        WidgetCenter.shared.reloadAllTimelines()

        if settings.healthKitEnabled {
            Task { await HealthKitService.shared.save(amountML: amountML, date: entry.timestamp) }
        }
    }

    static func delete(_ entry: DrinkEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
