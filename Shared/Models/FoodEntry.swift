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
    /// The portion logged, in the measure below. Named for grams historically;
    /// renaming a stored property risks the rows, and a log cannot be rebuilt.
    var portionGrams: Double = 0
    /// Snapshotted like everything else: a juice logged in ml stays in ml even if
    /// the library entry is later switched to grams.
    var measureRawValue: String = FoodMeasure.grams.rawValue
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
    /// Snapshot like the figures: an entry outlives the food it came from.
    var icon: String = FoodIcon.default.rawValue
    /// The Health samples written for this serving — one per nutrient that was not
    /// zero — so deleting the entry can retract exactly these and nothing else.
    /// Empty when Health sync was off at the time, which is why it is not optional.
    var healthKitSampleIDs: [UUID] = []

    init(
        name: String,
        nutrients: Nutrients,
        portionAmount: Double = 0,
        measure: FoodMeasure = .grams,
        portionCount: Double = 0,
        portionKind: PortionKind? = nil,
        icon: String = FoodIcon.default.rawValue,
        timestamp: Date = Date(),
        itemID: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.portionGrams = portionAmount
        self.measureRawValue = measure.rawValue
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
        self.icon = icon
    }

    /// Convenience for tests and simple entries with only an energy figure.
    convenience init(name: String, calories: Double, timestamp: Date = Date()) {
        self.init(
            name: name,
            nutrients: Nutrients(energyKcal: calories),
            timestamp: timestamp
        )
    }

    var measure: FoodMeasure {
        FoodMeasure(rawValue: measureRawValue) ?? .grams
    }

    /// Reads honestly at the call site: the figure is grams or millilitres
    /// depending on `measure`.
    var portionAmount: Double { portionGrams }

    var portionKind: PortionKind? {
        portionKindRaw.flatMap(PortionKind.init(rawValue:))
    }

    /// "10 pieces" when a named measure was used, otherwise "150 g" or "250 ml".
    var portionLabel: String {
        if let portionKind {
            return portionKind.label(count: portionCount)
        }
        return String(localized: "amount.with-unit",
                      defaultValue: "\(Quantity.whole(portionGrams)) \(measure.shortName)",
                      comment: "An amount followed by its unit symbol, e.g. 750 ml or 150 g")
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
