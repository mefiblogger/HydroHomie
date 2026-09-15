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
        context: ModelContext
    ) {
        let entry = FoodEntry(
            name: item.name,
            nutrients: item.nutrients(forGrams: grams),
            portionGrams: grams,
            portionCount: count,
            portionKind: kind,
            icon: item.icon,
            itemID: item.id
        )
        context.insert(entry)

        // Keeps the library sorted by what you actually eat.
        item.lastUsedAt = Date()
        item.defaultPortionGrams = grams

        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
