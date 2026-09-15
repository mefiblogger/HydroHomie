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

final class FoodIconTests: XCTestCase {

    func testDefaultIsTheGenericMeal() {
        XCTAssertEqual(FoodIcon.default, .meal)
        XCTAssertEqual(FoodItem(name: "Anything", per100g: Nutrients()).icon,
                       FoodIcon.meal.rawValue)
    }

    func testEveryIconIsDistinct() {
        let all = FoodIcon.allCases.map(\.rawValue)
        XCTAssertEqual(Set(all).count, all.count)
    }

    func testEveryIconHasASpokenName() {
        for icon in FoodIcon.allCases {
            XCTAssertFalse(icon.name.isEmpty, "\(icon) has no name")
        }
    }

    func testChosenIconIsStoredOnTheItem() {
        let item = FoodItem(name: "Cola", per100g: Nutrients(), icon: .softDrink)
        XCTAssertEqual(item.icon, FoodIcon.softDrink.rawValue)
    }

    func testEntrySnapshotsTheIconSoItOutlivesItsFood() {
        let item = FoodItem(name: "Cola", per100g: Nutrients(), icon: .softDrink)
        let entry = FoodEntry(
            name: item.name,
            nutrients: Nutrients(),
            icon: item.icon,
            itemID: item.id
        )
        item.icon = FoodIcon.candy.rawValue
        XCTAssertEqual(entry.icon, FoodIcon.softDrink.rawValue)
    }
}

/// The guarantee that editing the library never rewrites history.
final class EditingDoesNotRewriteHistoryTests: XCTestCase {

    private func loggedEntry(from item: FoodItem, grams: Double) -> FoodEntry {
        FoodEntry(
            name: item.name,
            nutrients: item.nutrients(forGrams: grams),
            portionGrams: grams,
            portionCount: 1,
            portionKind: item.portions.first?.kind,
            icon: item.icon,
            itemID: item.id
        )
    }

    func testCorrectingNutritionLeavesTodaysEntryAlone() {
        let item = FoodItem(
            name: "Cereal",
            per100g: Nutrients(energyKcal: 380, carbs: 70, sugar: 20, fiber: 6, protein: 8, fat: 5)
        )
        let entry = loggedEntry(from: item, grams: 50)

        // Tomorrow the figures turn out to be wrong and get corrected.
        item.energyKcal = 500
        item.carbsGrams = 90
        item.sugarGrams = 40
        item.fiberGrams = 2
        item.proteinGrams = 3
        item.fatGrams = 12

        XCTAssertEqual(entry.calories, 190, accuracy: 0.0001)
        XCTAssertEqual(entry.carbsGrams, 35, accuracy: 0.0001)
        XCTAssertEqual(entry.sugarGrams, 10, accuracy: 0.0001)
        XCTAssertEqual(entry.fiberGrams, 3, accuracy: 0.0001)
        XCTAssertEqual(entry.proteinGrams, 4, accuracy: 0.0001)
        XCTAssertEqual(entry.fatGrams, 2.5, accuracy: 0.0001)
    }

    func testRenamingLeavesTodaysEntryAlone() {
        let item = FoodItem(name: "Cereal", per100g: Nutrients(energyKcal: 380))
        let entry = loggedEntry(from: item, grams: 50)
        item.name = "Bran flakes"
        XCTAssertEqual(entry.name, "Cereal")
    }

    func testChangingTheIconLeavesTodaysEntryAlone() {
        let item = FoodItem(name: "Cereal", per100g: Nutrients(), icon: .meal)
        let entry = loggedEntry(from: item, grams: 50)
        item.icon = FoodIcon.candy.rawValue
        XCTAssertEqual(entry.icon, FoodIcon.meal.rawValue)
    }

    func testChangingAPortionWeightLeavesTodaysEntryAlone() {
        let item = FoodItem(
            name: "Grapes",
            per100g: Nutrients(energyKcal: 69),
            portions: [NamedPortion(kind: .piece, grams: 2)]
        )
        let grams = item.grams(count: 10, of: .piece) ?? 0
        let entry = loggedEntry(from: item, grams: grams)

        item.portions = [NamedPortion(kind: .piece, grams: 5)]

        XCTAssertEqual(entry.portionGrams, 20, accuracy: 0.0001)
        XCTAssertEqual(entry.calories, 13.8, accuracy: 0.0001)
    }

    func testDeletingTheFoodLeavesTheEntryReadable() {
        let item = FoodItem(name: "Cereal", per100g: Nutrients(energyKcal: 380), icon: .meal)
        let entry = loggedEntry(from: item, grams: 50)

        // Nothing about the entry depends on the item still existing.
        XCTAssertEqual(entry.name, "Cereal")
        XCTAssertEqual(entry.icon, FoodIcon.meal.rawValue)
        XCTAssertEqual(entry.calories, 190, accuracy: 0.0001)
        XCTAssertEqual(entry.itemID, item.id)
    }
}
