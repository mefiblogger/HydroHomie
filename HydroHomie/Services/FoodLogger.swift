// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData
import SwiftUI

/// Single funnel for logging food, mirroring `HydrationLogger` for water.
@MainActor
enum FoodLogger {

    static func log(
        _ item: FoodItem,
        grams: Double,
        count: Double = 0,
        kind: PortionKind? = nil,
        at timestamp: Date = Date(),
        settings: UserSettings,
        context: ModelContext
    ) {
        let nutrients = item.nutrients(forAmount: grams)
        let entry = FoodEntry(
            name: item.name,
            nutrients: nutrients,
            portionAmount: grams,
            measure: item.measure,
            portionCount: count,
            portionKind: kind,
            icon: item.icon,
            timestamp: timestamp,
            itemID: item.id
        )
        context.insert(entry)

        // Keeps the library sorted by what you actually eat.
        item.lastUsedAt = Date()
        item.defaultPortionAmount = grams

        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard settings.healthKitEnabled else { return }
        Task { @MainActor in
            // Record the sample ids so a later delete retracts exactly these.
            let ids = await HealthKitService.shared.saveFood(
                name: entry.name, nutrients: nutrients, date: entry.timestamp
            )
            guard !ids.isEmpty else { return }
            entry.healthKitSampleIDs = ids
            try? context.save()
        }
    }
}
