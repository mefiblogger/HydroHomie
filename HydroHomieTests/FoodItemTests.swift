// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

final class FoodItemTests: XCTestCase {

    private let oats = Nutrients(
        energyKcal: 379, carbs: 67.7, sugar: 0.99, fiber: 10.1, protein: 13.2, fat: 6.5
    )

    func testOneHundredGramsIsTheStoredValue() {
        let scaled = oats.scaled(toGrams: 100)
        XCTAssertEqual(scaled, oats)
    }

    func testScalingHalvesEveryNutrient() {
        let scaled = oats.scaled(toGrams: 50)
        XCTAssertEqual(scaled.energyKcal, 189.5, accuracy: 0.0001)
        XCTAssertEqual(scaled.carbs, 33.85, accuracy: 0.0001)
        XCTAssertEqual(scaled.sugar, 0.495, accuracy: 0.0001)
        XCTAssertEqual(scaled.fiber, 5.05, accuracy: 0.0001)
        XCTAssertEqual(scaled.protein, 6.6, accuracy: 0.0001)
        XCTAssertEqual(scaled.fat, 3.25, accuracy: 0.0001)
    }

    func testScalingAboveOneHundredGrams() {
        XCTAssertEqual(oats.scaled(toGrams: 250).energyKcal, 947.5, accuracy: 0.0001)
    }

    func testZeroPortionYieldsNothing() {
        XCTAssertEqual(oats.scaled(toGrams: 0), Nutrients())
    }

    func testItemExposesItsOwnPer100gUnchanged() {
        let item = FoodItem(name: "Oats", per100g: oats)
        XCTAssertEqual(item.per100g, oats)
    }

    func testItemScalesToAPortion() {
        let item = FoodItem(name: "Oats", per100g: oats)
        XCTAssertEqual(item.nutrients(forGrams: 40).energyKcal, 151.6, accuracy: 0.0001)
    }

    func testEntrySnapshotsTheScaledValuesRatherThanTheItem() {
        let item = FoodItem(name: "Oats", per100g: oats)
        let entry = FoodEntry(
            name: item.name,
            nutrients: item.nutrients(forGrams: 50),
            portionGrams: 50,
            itemID: item.id
        )

        // Correcting the library afterwards must not rewrite what was logged.
        item.energyKcal = 1000

        XCTAssertEqual(entry.calories, 189.5, accuracy: 0.0001)
        XCTAssertEqual(entry.portionGrams, 50, accuracy: 0.0001)
        XCTAssertEqual(entry.itemID, item.id)
    }
}

final class NamedPortionTests: XCTestCase {

    private let grapes = FoodItem(
        name: "Grapes",
        per100g: Nutrients(energyKcal: 69, carbs: 18, sugar: 16, fiber: 0.9, protein: 0.7, fat: 0.2),
        portions: [NamedPortion(kind: .piece, grams: 2)]
    )

    func testGramsForADefinedMeasure() {
        XCTAssertEqual(grapes.grams(for: .piece), 2)
    }

    func testGramsForAnUndefinedMeasureIsNil() {
        XCTAssertNil(grapes.grams(for: .can))
        XCTAssertNil(grapes.grams(count: 2, of: .bottle))
    }

    func testCountingPiecesMultipliesTheWeight() {
        XCTAssertEqual(grapes.grams(count: 10, of: .piece), 20)
    }

    func testNutrientsForTenGrapes() {
        let grams = grapes.grams(count: 10, of: .piece) ?? 0
        let nutrients = grapes.nutrients(forGrams: grams)
        XCTAssertEqual(nutrients.energyKcal, 13.8, accuracy: 0.0001)
        XCTAssertEqual(nutrients.sugar, 3.2, accuracy: 0.0001)
    }

    func testLabelSingularAndPlural() {
        XCTAssertEqual(PortionKind.piece.label(count: 1), "1 piece")
        XCTAssertEqual(PortionKind.piece.label(count: 10), "10 pieces")
        XCTAssertEqual(PortionKind.can.label(count: 2), "2 cans")
    }

    func testEachStaysEachWhenPlural() {
        XCTAssertEqual(PortionKind.each.label(count: 3), "3 each")
    }

    func testFractionalCountsKeepOneDecimal() {
        XCTAssertEqual(PortionKind.serving.label(count: 1.5), "1.5 servings")
    }

    func testEntryLabelsANamedPortion() {
        let entry = FoodEntry(
            name: "Grapes",
            nutrients: Nutrients(energyKcal: 13.8),
            portionGrams: 20,
            portionCount: 10,
            portionKind: .piece
        )
        XCTAssertEqual(entry.portionLabel, "10 pieces")
        XCTAssertEqual(entry.portionKind, .piece)
    }

    func testEntryFallsBackToGramsWithoutANamedPortion() {
        let entry = FoodEntry(
            name: "Oats",
            nutrients: Nutrients(energyKcal: 150),
            portionGrams: 40
        )
        XCTAssertEqual(entry.portionLabel, "40 g")
        XCTAssertNil(entry.portionKind)
    }
}
