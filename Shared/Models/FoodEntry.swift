// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// A single logged serving. Energy is kilocalories, everything else grams.
///
/// The figures are a snapshot taken at the moment of logging, not a live reference
/// to the `FoodItem` they came from: correcting a food's nutrition later should not
/// silently rewrite what you ate last week, and deleting it should not void the log.
@Model
final class FoodEntry {
    var id: UUID = UUID()
    var name: String = ""
    var portionGrams: Double = 0
    var calories: Double = 0
    var carbsGrams: Double = 0
    var sugarGrams: Double = 0
    var fiberGrams: Double = 0
    var proteinGrams: Double = 0
    var fatGrams: Double = 0
    var timestamp: Date = Date()
    /// The library item this came from, for "log it again" later. Deliberately a
    /// plain id rather than a relationship, so the entry outlives the item.
    var itemID: UUID?
    /// How many of `portionKind` were logged. Meaningless when the entry was
    /// logged straight in grams.
    var portionCount: Double = 0
    var portionKindRaw: String?

    init(
        name: String,
        nutrients: Nutrients,
        portionGrams: Double = 0,
        portionCount: Double = 0,
        portionKind: PortionKind? = nil,
        timestamp: Date = Date(),
        itemID: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.portionGrams = portionGrams
        self.calories = nutrients.energyKcal
        self.carbsGrams = nutrients.carbs
        self.sugarGrams = nutrients.sugar
        self.fiberGrams = nutrients.fiber
        self.proteinGrams = nutrients.protein
        self.fatGrams = nutrients.fat
        self.timestamp = timestamp
        self.itemID = itemID
        self.portionCount = portionCount
        self.portionKindRaw = portionKind?.rawValue
    }

    /// Convenience for tests and simple entries with only an energy figure.
    convenience init(name: String, calories: Double, timestamp: Date = Date()) {
        self.init(
            name: name,
            nutrients: Nutrients(energyKcal: calories),
            timestamp: timestamp
        )
    }

    var portionKind: PortionKind? {
        portionKindRaw.flatMap(PortionKind.init(rawValue:))
    }

    /// "10 pieces" when a named measure was used, otherwise "150 g".
    var portionLabel: String {
        if let portionKind {
            return portionKind.label(count: portionCount)
        }
        return "\(Int(portionGrams.rounded())) g"
    }

    var nutrients: Nutrients {
        Nutrients(
            energyKcal: calories,
            carbs: carbsGrams,
            sugar: sugarGrams,
            fiber: fiberGrams,
            protein: proteinGrams,
            fat: fatGrams
        )
    }
}
