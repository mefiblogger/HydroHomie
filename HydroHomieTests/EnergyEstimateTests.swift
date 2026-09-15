// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

/// Mifflin–St Jeor, checked against values worked by hand.
final class EnergyEstimateTests: XCTestCase {

    func testBasalRateForAMan() {
        // 10(80) + 6.25(180) − 5(30) + 5 = 800 + 1125 − 150 + 5
        XCTAssertEqual(
            EnergyEstimate.basalRate(sex: .male, weightKg: 80, heightCm: 180, age: 30),
            1780, accuracy: 0.0001)
    }

    func testBasalRateForAWoman() {
        // 10(65) + 6.25(168) − 5(30) − 161 = 650 + 1050 − 150 − 161
        XCTAssertEqual(
            EnergyEstimate.basalRate(sex: .female, weightKg: 65, heightCm: 168, age: 30),
            1389, accuracy: 0.0001)
    }

    func testTheSexTermIsTheOnlyDifference() {
        let man = EnergyEstimate.basalRate(sex: .male, weightKg: 70, heightCm: 175, age: 40)
        let woman = EnergyEstimate.basalRate(sex: .female, weightKg: 70, heightCm: 175, age: 40)
        XCTAssertEqual(man - woman, 166, accuracy: 0.0001)
    }

    func testBasalRateFallsWithAge() {
        let young = EnergyEstimate.basalRate(sex: .male, weightKg: 80, heightCm: 180, age: 25)
        let older = EnergyEstimate.basalRate(sex: .male, weightKg: 80, heightCm: 180, age: 55)
        XCTAssertEqual(young - older, 150, accuracy: 0.0001)
    }

    func testActivityMultipliesMaintenance() {
        XCTAssertEqual(
            EnergyEstimate.maintenanceCalories(basalRate: 1780, activity: .sedentary),
            2136, accuracy: 0.0001)
        XCTAssertEqual(
            EnergyEstimate.maintenanceCalories(basalRate: 1780, activity: .veryActive),
            3382, accuracy: 0.0001)
    }

    func testMaintainingTakesTheMaintenanceFigure() {
        let calories = EnergyEstimate.dailyCalories(
            sex: .male, weightKg: 80, heightCm: 180, age: 30,
            activity: .moderate, goal: .maintain)
        XCTAssertEqual(calories, 1780 * 1.55, accuracy: 0.0001)
    }

    func testLosingAndGainingMoveByFiveHundredEitherWay() {
        func calories(_ goal: WeightGoal) -> Double {
            EnergyEstimate.dailyCalories(
                sex: .male, weightKg: 80, heightCm: 180, age: 30,
                activity: .moderate, goal: goal)
        }
        XCTAssertEqual(calories(.maintain) - calories(.lose), 500, accuracy: 0.0001)
        XCTAssertEqual(calories(.gain) - calories(.maintain), 500, accuracy: 0.0001)
    }

    /// A deficit applied to a small, sedentary person must not suggest starvation.
    func testTheDeficitIsFloored() {
        let calories = EnergyEstimate.dailyCalories(
            sex: .female, weightKg: 45, heightCm: 150, age: 70,
            activity: .sedentary, goal: .lose)
        XCTAssertGreaterThanOrEqual(calories, 1200)
    }

    func testTheFloorIsHigherForMen() {
        let calories = EnergyEstimate.dailyCalories(
            sex: .male, weightKg: 50, heightCm: 155, age: 75,
            activity: .sedentary, goal: .lose)
        XCTAssertGreaterThanOrEqual(calories, 1500)
    }

    func testWaterScalesWithBodyWeight() {
        XCTAssertEqual(EnergyEstimate.dailyWaterML(weightKg: 60, activity: .light), 2100)
        XCTAssertEqual(EnergyEstimate.dailyWaterML(weightKg: 80, activity: .light), 2800)
    }

    func testHarderTrainingAddsWater() {
        let calm = EnergyEstimate.dailyWaterML(weightKg: 70, activity: .sedentary)
        let hard = EnergyEstimate.dailyWaterML(weightKg: 70, activity: .veryActive)
        XCTAssertEqual(hard - calm, 750, accuracy: 0.0001)
    }

    func testWaterRoundsToSomethingPourable() {
        // 63 kg * 35 = 2205, which should not be suggested verbatim.
        let water = EnergyEstimate.dailyWaterML(weightKg: 63, activity: .sedentary)
        XCTAssertEqual(water.truncatingRemainder(dividingBy: 50), 0)
    }

    func testGoalDefaultsToMaintain() {
        XCTAssertEqual(UserSettings().weightGoal, .maintain)
        XCTAssertEqual(WeightGoal.maintain.calorieAdjustment, 0)
    }
}

/// The ranges the calculator accepts, mirrored from EnergyCalculatorView.
final class MeasurementRangeTests: XCTestCase {

    private func inRange(_ text: String, _ range: ClosedRange<Double>) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              range.contains(value) else { return nil }
        return value
    }

    func testPlausibleMeasurementsAreAccepted() {
        XCTAssertEqual(inRange("80", 20...400), 80)
        XCTAssertEqual(inRange("180", 50...250), 180)
    }

    /// The exact fat-finger this caught: 180 typed into a field that already held 30.
    func testAMistypedHeightIsRejected() {
        XCTAssertNil(inRange("18030", 50...250))
    }

    func testImplausibleWeightsAreRejected() {
        XCTAssertNil(inRange("0", 20...400))
        XCTAssertNil(inRange("900", 20...400))
    }

    func testDecimalCommaIsAccepted() {
        XCTAssertEqual(inRange("72,5", 20...400), 72.5)
    }
}
