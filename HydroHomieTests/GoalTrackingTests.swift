// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

/// The tolerance rules, which differ by goal.
final class GoalOutcomeTests: XCTestCase {

    // MARK: Losing — a ceiling, no floor

    func testLosingAllowsUpToFivePercentOver() {
        XCTAssertEqual(WeightGoal.lose.calorieOutcome(consumed: 2100, target: 2000), .met)
        XCTAssertEqual(WeightGoal.lose.calorieOutcome(consumed: 2101, target: 2000), .missed)
    }

    func testLosingIsHappyWellUnderTarget() {
        XCTAssertEqual(WeightGoal.lose.calorieOutcome(consumed: 1200, target: 2000), .met)
    }

    // MARK: Gaining — a floor, no ceiling

    func testGainingAllowsUpToFivePercentUnder() {
        XCTAssertEqual(WeightGoal.gain.calorieOutcome(consumed: 1900, target: 2000), .met)
        XCTAssertEqual(WeightGoal.gain.calorieOutcome(consumed: 1899, target: 2000), .missed)
    }

    func testGainingIsHappyWellOverTarget() {
        XCTAssertEqual(WeightGoal.gain.calorieOutcome(consumed: 2800, target: 2000), .met)
    }

    // MARK: Maintaining — both

    func testMaintainingWantsTheBand() {
        XCTAssertEqual(WeightGoal.maintain.calorieOutcome(consumed: 1900, target: 2000), .met)
        XCTAssertEqual(WeightGoal.maintain.calorieOutcome(consumed: 2100, target: 2000), .met)
        XCTAssertEqual(WeightGoal.maintain.calorieOutcome(consumed: 1899, target: 2000), .missed)
        XCTAssertEqual(WeightGoal.maintain.calorieOutcome(consumed: 2101, target: 2000), .missed)
    }

    // MARK: The trap

    /// "No more than 5% over" is trivially satisfied by eating nothing, so a day with
    /// no entries must not read as a win.
    func testALoggedNothingDayIsNotAWin() {
        XCTAssertEqual(WeightGoal.lose.calorieOutcome(consumed: 0, target: 2000), .untracked)
        XCTAssertEqual(WeightGoal.gain.calorieOutcome(consumed: 0, target: 2000), .untracked)
        XCTAssertEqual(WeightGoal.maintain.calorieOutcome(consumed: 0, target: 2000), .untracked)
    }

    func testNoTargetMeansNothingToMeasureAgainst() {
        XCTAssertEqual(WeightGoal.lose.calorieOutcome(consumed: 500, target: 0), .untracked)
    }

    // MARK: Water

    func testWaterWantsNinetyFivePercentWhateverTheWeightGoal() {
        XCTAssertEqual(waterOutcome(consumed: 1900, target: 2000), .met)
        XCTAssertEqual(waterOutcome(consumed: 1899, target: 2000), .missed)
        XCTAssertEqual(waterOutcome(consumed: 4000, target: 2000), .met)
        XCTAssertEqual(waterOutcome(consumed: 0, target: 2000), .untracked)
    }
}

/// Changing the goal must not rewrite how earlier days scored.
final class GoalHistoryTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset,
                      to: calendar.startOfDay(for: Date()))!
    }

    private func goal(_ weight: WeightGoal, _ calories: Double = 2000) -> ResolvedGoal {
        ResolvedGoal(weightGoal: weight, calorieGoal: calories, waterGoalML: 2000)
    }

    func testAChangeAppliesFromItsStartDateOnward() {
        let periods = [
            GoalPeriod(startDate: day(-30), goal: goal(.maintain)),
            GoalPeriod(startDate: day(1), goal: goal(.gain)),
        ]
        XCTAssertEqual(
            GoalHistory.goal(on: day(-5), periods: periods,
                             fallback: goal(.lose), calendar: calendar).weightGoal,
            .maintain)
        XCTAssertEqual(
            GoalHistory.goal(on: day(2), periods: periods,
                             fallback: goal(.lose), calendar: calendar).weightGoal,
            .gain)
    }

    func testTodayStillUsesTheOldGoalWhenTheChangeStartsTomorrow() {
        let periods = [
            GoalPeriod(startDate: day(-30), goal: goal(.maintain)),
            GoalPeriod(startDate: day(1), goal: goal(.gain)),
        ]
        XCTAssertEqual(
            GoalHistory.goal(on: day(0), periods: periods,
                             fallback: goal(.lose), calendar: calendar).weightGoal,
            .maintain)
    }

    /// Days before any record use the earliest one, not today's settings — using
    /// today's would be exactly the retroactive rewrite this prevents.
    func testDaysBeforeAnyRecordUseTheEarliestPeriod() {
        let periods = [GoalPeriod(startDate: day(-10), goal: goal(.maintain, 1800))]
        let resolved = GoalHistory.goal(on: day(-40), periods: periods,
                                        fallback: goal(.gain, 3000), calendar: calendar)
        XCTAssertEqual(resolved.weightGoal, .maintain)
        XCTAssertEqual(resolved.calorieGoal, 1800)
    }

    func testWithNoRecordsAtAllItFallsBackToCurrentSettings() {
        let resolved = GoalHistory.goal(on: day(-3), periods: [],
                                        fallback: goal(.gain, 3000), calendar: calendar)
        XCTAssertEqual(resolved.weightGoal, .gain)
    }

    func testTargetsAreRememberedPerPeriodToo() {
        let periods = [
            GoalPeriod(startDate: day(-30), goal: goal(.maintain, 1800)),
            GoalPeriod(startDate: day(-5), goal: goal(.maintain, 2500)),
        ]
        XCTAssertEqual(
            GoalHistory.goal(on: day(-10), periods: periods,
                             fallback: goal(.lose), calendar: calendar).calorieGoal,
            1800)
        XCTAssertEqual(
            GoalHistory.goal(on: day(-1), periods: periods,
                             fallback: goal(.lose), calendar: calendar).calorieGoal,
            2500)
    }

    func testTheLatestApplicablePeriodWinsWhateverTheOrder() {
        let periods = [
            GoalPeriod(startDate: day(-5), goal: goal(.gain)),
            GoalPeriod(startDate: day(-30), goal: goal(.maintain)),
            GoalPeriod(startDate: day(-15), goal: goal(.lose)),
        ]
        XCTAssertEqual(
            GoalHistory.goal(on: day(-2), periods: periods,
                             fallback: goal(.maintain), calendar: calendar).weightGoal,
            .gain)
    }
}

/// A month's worth of days, scored against whatever goal applied.
final class MonthProgressTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var maintain: ResolvedGoal {
        ResolvedGoal(weightGoal: .maintain, calorieGoal: 2000, waterGoalML: 2000)
    }

    func testAMonthCoversEveryDay() {
        let days = HydrationStore.month(
            of: date(2026, 9, 15), drinks: [], food: [], periods: [],
            fallback: maintain, calendar: calendar, today: date(2026, 9, 30))
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(calendar.component(.day, from: days[0].date), 1)
    }

    func testFebruaryIsShorter() {
        let days = HydrationStore.month(
            of: date(2026, 2, 10), drinks: [], food: [], periods: [],
            fallback: maintain, calendar: calendar, today: date(2026, 3, 1))
        XCTAssertEqual(days.count, 28)
    }

    func testDaysAreScoredAgainstTheirOwnTotals() {
        let drinks = [DrinkEntry(amountML: 2000, timestamp: date(2026, 9, 3))]
        let food = [FoodEntry(name: "Day", calories: 1980, timestamp: date(2026, 9, 3))]
        let days = HydrationStore.month(
            of: date(2026, 9, 1), drinks: drinks, food: food, periods: [],
            fallback: maintain, calendar: calendar, today: date(2026, 9, 30))

        let third = days.first { calendar.component(.day, from: $0.date) == 3 }
        XCTAssertEqual(third?.food, .met)
        XCTAssertEqual(third?.water, .met)

        let fourth = days.first { calendar.component(.day, from: $0.date) == 4 }
        XCTAssertEqual(fourth?.food, .untracked)
        XCTAssertEqual(fourth?.water, .untracked)
    }

    func testFutureDaysAreNotTreatedAsPast() {
        let days = HydrationStore.month(
            of: date(2026, 9, 1), drinks: [], food: [], periods: [],
            fallback: maintain, calendar: calendar, today: date(2026, 9, 10))
        XCTAssertTrue(days[0].isPast)
        XCTAssertTrue(days[9].isPast)
        XCTAssertFalse(days[10].isPast)
    }

    /// The whole point of goal history: a change partway through scores each half
    /// against the goal that was in force.
    func testAMidMonthChangeSplitsTheMonth() {
        let periods = [
            GoalPeriod(startDate: date(2026, 9, 1, hour: 0),
                       goal: ResolvedGoal(weightGoal: .maintain, calorieGoal: 2000, waterGoalML: 2000)),
            GoalPeriod(startDate: date(2026, 9, 16, hour: 0),
                       goal: ResolvedGoal(weightGoal: .gain, calorieGoal: 2000, waterGoalML: 2000)),
        ]
        // 1,700 kcal: short of maintain's band, and short of gain's floor as well.
        // 2,400 kcal: over maintain's band, but fine once gaining.
        let food = [
            FoodEntry(name: "Early", calories: 2400, timestamp: date(2026, 9, 5)),
            FoodEntry(name: "Late", calories: 2400, timestamp: date(2026, 9, 20)),
        ]
        let days = HydrationStore.month(
            of: date(2026, 9, 1), drinks: [], food: food, periods: periods,
            fallback: maintain, calendar: calendar, today: date(2026, 9, 30))

        XCTAssertEqual(days.first { calendar.component(.day, from: $0.date) == 5 }?.food, .missed)
        XCTAssertEqual(days.first { calendar.component(.day, from: $0.date) == 20 }?.food, .met)
    }

    /// Logging later re-scores the day, because outcomes are derived from entries
    /// rather than frozen at midnight.
    func testAddingAnEntryLaterChangesTheOutcome() {
        func score(_ food: [FoodEntry]) -> GoalOutcome? {
            HydrationStore.month(
                of: date(2026, 9, 1), drinks: [], food: food, periods: [],
                fallback: maintain, calendar: calendar, today: date(2026, 9, 30))
                .first { calendar.component(.day, from: $0.date) == 7 }?.food
        }
        let partial = [FoodEntry(name: "Lunch", calories: 1200, timestamp: date(2026, 9, 7))]
        XCTAssertEqual(score(partial), .missed)

        let complete = partial + [FoodEntry(name: "Dinner", calories: 800, timestamp: date(2026, 9, 7, hour: 22))]
        XCTAssertEqual(score(complete), .met)
    }
}
