// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

final class ConsumptionTests: XCTestCase {

    // MARK: - Calories

    func testCaloriesSumsEntries() {
        let food = [
            FoodEntry(name: "Porridge", calories: 320),
            FoodEntry(name: "Burger", calories: 540)
        ]
        XCTAssertEqual(HydrationStore.calories(of: food), 860, accuracy: 0.0001)
    }

    func testCaloriesOfEmptyIsZero() {
        XCTAssertEqual(HydrationStore.calories(of: []), 0)
    }

    // MARK: - Progress

    func testProgressIsConsumedOverGoal() {
        XCTAssertEqual(HydrationStore.progress(consumed: 500, goal: 2000), 0.25, accuracy: 0.0001)
    }

    func testProgressExceedsOneWhenPastGoal() {
        XCTAssertEqual(HydrationStore.progress(consumed: 2500, goal: 2000), 1.25, accuracy: 0.0001)
    }

    func testProgressOfZeroGoalIsZeroRatherThanInfinite() {
        XCTAssertEqual(HydrationStore.progress(consumed: 500, goal: 0), 0)
        XCTAssertEqual(HydrationStore.progress(consumed: 500, goal: -100), 0)
    }

    // MARK: - Remaining

    func testRemainingCountsDown() {
        XCTAssertEqual(HydrationStore.remaining(goal: 2000, consumed: 1450), 550, accuracy: 0.0001)
    }

    func testRemainingGoesNegativeWhenOverGoal() {
        XCTAssertEqual(HydrationStore.remaining(goal: 2000, consumed: 2320), -320, accuracy: 0.0001)
    }

    func testRemainingIsWholeGoalWhenNothingConsumed() {
        XCTAssertEqual(HydrationStore.remaining(goal: 2000, consumed: 0), 2000, accuracy: 0.0001)
    }

    // MARK: - Macros

    func testMacrosSumEachNutrientIndependently() {
        let food = [
            FoodEntry(
                name: "Porridge",
                nutrients: Nutrients(energyKcal: 320, carbs: 54, sugar: 2, fiber: 7, protein: 11, fat: 6)
            ),
            FoodEntry(
                name: "Eggs",
                nutrients: Nutrients(energyKcal: 180, carbs: 1, sugar: 1, fiber: 0, protein: 13, fat: 13)
            )
        ]
        let totals = HydrationStore.macros(of: food)
        XCTAssertEqual(totals.carbs, 55, accuracy: 0.0001)
        XCTAssertEqual(totals.sugar, 3, accuracy: 0.0001)
        XCTAssertEqual(totals.fiber, 7, accuracy: 0.0001)
        XCTAssertEqual(totals.protein, 24, accuracy: 0.0001)
        XCTAssertEqual(totals.fat, 19, accuracy: 0.0001)
    }

    func testMacrosOfEmptyAreAllZero() {
        XCTAssertEqual(HydrationStore.macros(of: []), MacroTotals())
    }

    func testMacrosDefaultToZeroWhenOnlyCaloriesAreKnown() {
        let food = [FoodEntry(name: "Mystery snack", calories: 250)]
        XCTAssertEqual(HydrationStore.macros(of: food), MacroTotals())
    }

    // MARK: - Merged log

    func testMergedLogIsNewestFirstAcrossBothStreams() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let water = [
            DrinkEntry(amountML: 250, timestamp: base),
            DrinkEntry(amountML: 250, timestamp: base.addingTimeInterval(120))
        ]
        let food = [FoodEntry(name: "Apple", calories: 95, timestamp: base.addingTimeInterval(60))]

        let log = HydrationStore.mergedLog(water: water, food: food)

        XCTAssertEqual(log.count, 3)
        let timestamps = log.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >))

        // Newest is the second drink, the food item sits between the two drinks.
        guard case .water = log[0] else { return XCTFail("expected water newest") }
        guard case .food = log[1] else { return XCTFail("expected food in the middle") }
        guard case .water = log[2] else { return XCTFail("expected water oldest") }
    }

    func testMergedLogOfEmptyStreamsIsEmpty() {
        XCTAssertTrue(HydrationStore.mergedLog(water: [], food: []).isEmpty)
    }

    func testMergedLogHandlesOneStreamBeingEmpty() {
        let food = [FoodEntry(name: "Toast", calories: 120)]
        let log = HydrationStore.mergedLog(water: [], food: food)
        XCTAssertEqual(log.count, 1)
        guard case .food = log[0] else { return XCTFail("expected the food entry") }
    }

    func testLogItemIdsAreDistinctPerEntry() {
        let water = [DrinkEntry(amountML: 250), DrinkEntry(amountML: 250)]
        let log = HydrationStore.mergedLog(water: water, food: [])
        XCTAssertNotEqual(log[0].id, log[1].id)
    }
}
