// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

final class MacroSplitTests: XCTestCase {

    func testTheSuggestedSplitTotalsOneHundred() {
        XCTAssertEqual(MacroSplit.suggested.total, 100)
    }

    // MARK: Grams from percentages

    func testGramsUseTheAtwaterFactors() {
        let split = MacroSplit(carbs: 50, protein: 20, fat: 30)
        // 50% of 2000 = 1000 kcal at 4 kcal/g
        XCTAssertEqual(split.grams(of: .carbs, calories: 2000), 250, accuracy: 0.0001)
        XCTAssertEqual(split.grams(of: .protein, calories: 2000), 100, accuracy: 0.0001)
        // 30% of 2000 = 600 kcal at 9 kcal/g
        XCTAssertEqual(split.grams(of: .fat, calories: 2000), 66.6667, accuracy: 0.001)
    }

    func testGramsFollowTheCalorieTarget() {
        let split = MacroSplit.suggested
        XCTAssertEqual(split.grams(of: .carbs, calories: 2500), 312.5, accuracy: 0.0001)
    }

    func testTheGramsAddBackUpToTheCalorieTarget() {
        let split = MacroSplit(carbs: 30, protein: 45, fat: 25)
        let total = Macro.allCases.reduce(0.0) {
            $0 + split.grams(of: $1, calories: 2000) * $1.kcalPerGram
        }
        XCTAssertEqual(total, 2000, accuracy: 0.0001)
    }

    // MARK: Staying at 100

    func testChangingOneMacroKeepsTheTotalAtOneHundred() {
        for target in stride(from: 0.0, through: 100.0, by: 5) {
            let split = MacroSplit.suggested.setting(.carbs, to: target, absorbedBy: .fat)
            XCTAssertEqual(split.total, 100, "carbs \(target) left total at \(split.total)")
        }
    }

    func testTheDifferenceGoesEntirelyToTheAbsorber() {
        let split = MacroSplit(carbs: 50, protein: 20, fat: 30)
            .setting(.carbs, to: 30, absorbedBy: .fat)
        XCTAssertEqual(split.carbs, 30)
        XCTAssertEqual(split.protein, 20, "protein should not have moved")
        XCTAssertEqual(split.fat, 50)
    }

    /// The reason the absorber is a single macro: an exact split has to be reachable.
    func testAnExactSplitCanBeDialledIn() {
        let split = MacroSplit.suggested
            .setting(.carbs, to: 30, absorbedBy: .fat)
            .setting(.protein, to: 45, absorbedBy: .fat)
        XCTAssertEqual(split, MacroSplit(carbs: 30, protein: 45, fat: 25))
    }

    func testTheThirdMacroCoversWhatTheAbsorberCannot() {
        // Fat only has 30 to give, but carbs wants 60 more.
        let split = MacroSplit(carbs: 20, protein: 50, fat: 30)
            .setting(.carbs, to: 80, absorbedBy: .fat)
        XCTAssertEqual(split.total, 100)
        XCTAssertEqual(split.carbs, 80)
        XCTAssertGreaterThanOrEqual(split.fat, 0)
        XCTAssertGreaterThanOrEqual(split.protein, 0)
    }

    func testNothingGoesNegative() {
        let split = MacroSplit(carbs: 10, protein: 10, fat: 80)
            .setting(.fat, to: 100, absorbedBy: .carbs)
        XCTAssertEqual(split.total, 100)
        for macro in Macro.allCases {
            XCTAssertGreaterThanOrEqual(split[macro], 0)
        }
    }

    func testValuesAreClampedToTheRange() {
        XCTAssertEqual(MacroSplit.suggested.setting(.carbs, to: 250, absorbedBy: .fat).carbs, 100)
        XCTAssertEqual(MacroSplit.suggested.setting(.carbs, to: -40, absorbedBy: .fat).carbs, 0)
    }

    func testAbsorbingIntoItselfIsANoOp() {
        let split = MacroSplit.suggested
        XCTAssertEqual(split.setting(.carbs, to: 10, absorbedBy: .carbs), split)
    }

    // MARK: Settings

    func testSettingsStartFromTheSuggestedSplit() {
        XCTAssertEqual(UserSettings().macroSplit, MacroSplit.suggested)
    }

    func testSettingsDeriveGramsFromTheCalorieGoal() {
        let settings = UserSettings()
        settings.dailyCalorieGoal = 2400
        settings.macroSplit = MacroSplit(carbs: 50, protein: 25, fat: 25)
        XCTAssertEqual(settings.macroGrams(.carbs), 300, accuracy: 0.0001)
        XCTAssertEqual(settings.macroGrams(.protein), 150, accuracy: 0.0001)
    }

    /// Macros are a Today-screen concern; goal tracking scores calories and water only.
    func testMacrosDoNotAffectGoalOutcomes() {
        let settings = UserSettings()
        settings.macroSplit = MacroSplit(carbs: 10, protein: 80, fat: 10)
        let before = settings.resolvedGoal
        settings.macroSplit = MacroSplit(carbs: 60, protein: 20, fat: 20)
        XCTAssertEqual(before, settings.resolvedGoal)
    }
}

/// Flagging splits that sit outside the usual guidance bands.
final class MacroRangeTests: XCTestCase {

    func testTheSuggestedSplitRaisesNothing() {
        XCTAssertTrue(MacroSplit.suggested.unusual.isEmpty)
    }

    /// The split that prompted this. 35% protein is 175 g on a 2,000 kcal day, which
    /// looks extreme — but it is exactly the ceiling of the band, so only the carbs
    /// being under 45% is out of the ordinary.
    func testTheSplitThatPromptedThisFlagsCarbsOnly() {
        let split = MacroSplit(carbs: 35, protein: 35, fat: 30)
        XCTAssertEqual(split.unusual, [.carbs])
        XCTAssertEqual(split.placement(of: .carbs), .below)
        XCTAssertEqual(split.placement(of: .protein), .usual)
        XCTAssertEqual(split.placement(of: .fat), .usual)
    }

    /// Past the ceiling, protein is flagged.
    func testProteinAboveTheBandIsFlagged() {
        let split = MacroSplit(carbs: 30, protein: 45, fat: 25)
        XCTAssertEqual(split.unusual, [.carbs, .protein])
        XCTAssertEqual(split.placement(of: .protein), .above)
    }

    func testBoundariesCountAsUsual() {
        XCTAssertEqual(MacroSplit(carbs: 45, protein: 20, fat: 35).placement(of: .carbs), .usual)
        XCTAssertEqual(MacroSplit(carbs: 65, protein: 10, fat: 25).placement(of: .carbs), .usual)
        XCTAssertEqual(MacroSplit(carbs: 55, protein: 35, fat: 10).placement(of: .protein), .usual)
    }

    func testBelowAndAboveAreDistinguished() {
        XCTAssertEqual(MacroSplit(carbs: 20, protein: 40, fat: 40).placement(of: .carbs), .below)
        XCTAssertEqual(MacroSplit(carbs: 20, protein: 40, fat: 40).placement(of: .protein), .above)
    }

    func testTheRangesAreTheStandardOnes() {
        XCTAssertEqual(Macro.carbs.usualRange, 45...65)
        XCTAssertEqual(Macro.protein.usualRange, 10...35)
        XCTAssertEqual(Macro.fat.usualRange, 20...35)
    }

    func testFlaggingIsAdvisoryAndDoesNotAlterTheSplit() {
        var split = MacroSplit(carbs: 10, protein: 80, fat: 10)
        let before = split
        _ = split.unusual
        XCTAssertEqual(split, before)
        XCTAssertEqual(split.total, 100)
    }
}
