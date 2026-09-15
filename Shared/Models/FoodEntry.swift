// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// A single logged food item. Energy is always kilocalories.
@Model
final class FoodEntry {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Double = 0
    var carbsGrams: Double = 0
    var proteinGrams: Double = 0
    var fatGrams: Double = 0
    var timestamp: Date = Date()

    init(
        name: String,
        calories: Double,
        carbsGrams: Double = 0,
        proteinGrams: Double = 0,
        fatGrams: Double = 0,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.timestamp = timestamp
    }
}
