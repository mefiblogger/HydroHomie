// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// The six nutrients tracked, as an absolute amount for some quantity of food.
/// Sugar and fibre are subsets of carbohydrate, not siblings of it — do not add
/// the three together.
struct Nutrients: Equatable, Sendable {
    var energyKcal: Double = 0
    var carbs: Double = 0
    var sugar: Double = 0
    var fiber: Double = 0
    var protein: Double = 0
    var fat: Double = 0

    /// These values describe 100 g; return the same nutrients for `grams` instead.
    func scaled(toGrams grams: Double) -> Nutrients {
        let factor = grams / 100
        return Nutrients(
            energyKcal: energyKcal * factor,
            carbs: carbs * factor,
            sugar: sugar * factor,
            fiber: fiber * factor,
            protein: protein * factor,
            fat: fat * factor
        )
    }
}

/// A reusable food definition in the user's own library.
///
/// Everything is held per 100 g, which is how both USDA FoodData Central and Open
/// Food Facts report nutrition — so a lookup against either can populate one of
/// these without any conversion.
@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""

    var energyKcal: Double = 0
    var carbsGrams: Double = 0
    var sugarGrams: Double = 0
    var fiberGrams: Double = 0
    var proteinGrams: Double = 0
    var fatGrams: Double = 0

    /// Offered as the portion when logging this food again.
    var defaultPortionGrams: Double = 100
    var createdAt: Date = Date()
    /// Drives the ordering of the library, so what you eat often stays at the top.
    var lastUsedAt: Date = Date()
    /// Set when an item came from a barcode. Unused until a lookup source lands.
    var barcode: String?

    init(
        name: String,
        per100g: Nutrients,
        defaultPortionGrams: Double = 100,
        barcode: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.energyKcal = per100g.energyKcal
        self.carbsGrams = per100g.carbs
        self.sugarGrams = per100g.sugar
        self.fiberGrams = per100g.fiber
        self.proteinGrams = per100g.protein
        self.fatGrams = per100g.fat
        self.defaultPortionGrams = defaultPortionGrams
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.barcode = barcode
    }

    var per100g: Nutrients {
        Nutrients(
            energyKcal: energyKcal,
            carbs: carbsGrams,
            sugar: sugarGrams,
            fiber: fiberGrams,
            protein: proteinGrams,
            fat: fatGrams
        )
    }

    func nutrients(forGrams grams: Double) -> Nutrients {
        per100g.scaled(toGrams: grams)
    }
}
