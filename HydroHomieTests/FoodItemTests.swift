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
