// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// Single funnel for adding and removing entries so that haptics, HealthKit mirroring
/// and widget refresh happen consistently wherever a change originates.
@MainActor
enum HydrationLogger {

    static func add(amountML: Double, settings: UserSettings, context: ModelContext) {
        let entry = DrinkEntry(amountML: amountML, source: .app)
        context.insert(entry)
        try? context.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        WidgetCenter.shared.reloadAllTimelines()

        guard settings.healthKitEnabled else { return }
        Task { @MainActor in
            // Record the sample id so a later undo can retract exactly this sample.
            if let sampleID = await HealthKitService.shared.save(
                amountML: amountML, date: entry.timestamp
            ) {
                entry.healthKitSampleID = sampleID
                try? context.save()
            }
        }
    }

    static func delete(_ entry: DrinkEntry, context: ModelContext) {
        let sampleID = entry.healthKitSampleID
        context.delete(entry)
        try? context.save()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        WidgetCenter.shared.reloadAllTimelines()

        if let sampleID {
            Task { await HealthKitService.shared.delete(sampleID: sampleID) }
        }
    }

    static func delete(_ entry: FoodEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Removes the most recent water entry of the day. The quick-add buttons are
    /// labelled with the increment, but the entry removed may be a different size —
    /// a widget tap or a custom amount — so the whole entry goes.
    static func undoLastWater(from entries: [DrinkEntry], context: ModelContext) {
        guard let latest = entries.max(by: { $0.timestamp < $1.timestamp }) else { return }
        delete(latest, context: context)
    }
}
