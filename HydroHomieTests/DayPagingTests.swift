// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

/// Logging while a past day is on screen has to land on that day.
final class DayLoggingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testLoggingOnTodayUsesTheCurrentMoment() {
        let now = date(2026, 9, 16, 14, 30)
        let stamp = HydrationStore.timestamp(loggingOn: now, now: now, calendar: calendar)
        XCTAssertEqual(stamp, now)
    }

    func testLoggingOnAPastDayLandsOnThatDay() {
        let now = date(2026, 9, 16, 14, 30)
        let viewing = date(2026, 9, 12)
        let stamp = HydrationStore.timestamp(loggingOn: viewing, now: now, calendar: calendar)
        XCTAssertTrue(calendar.isDate(stamp, inSameDayAs: viewing))
    }

    /// Keeping the clock time means a correction sorts sensibly among that day's
    /// existing entries rather than all piling up at midnight.
    func testItKeepsTheCurrentClockTime() {
        let now = date(2026, 9, 16, 14, 30)
        let stamp = HydrationStore.timestamp(loggingOn: date(2026, 9, 12), now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: stamp), 14)
        XCTAssertEqual(calendar.component(.minute, from: stamp), 30)
    }

    func testItNeverStampsTheFuture() {
        let now = date(2026, 9, 16, 14, 30)
        let stamp = HydrationStore.timestamp(loggingOn: date(2026, 9, 20), now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(stamp, now)
    }

    // MARK: Day filtering

    func testDrinksAreScopedToTheDay() {
        let drinks = [
            DrinkEntry(amountML: 250, timestamp: date(2026, 9, 12, 9)),
            DrinkEntry(amountML: 250, timestamp: date(2026, 9, 12, 23, 59)),
            DrinkEntry(amountML: 250, timestamp: date(2026, 9, 13, 0, 1)),
        ]
        let scoped = HydrationStore.drinks(drinks, on: date(2026, 9, 12), calendar: calendar)
        XCTAssertEqual(scoped.count, 2)
        XCTAssertEqual(HydrationStore.total(of: scoped), 500)
    }

    func testFoodIsScopedToTheDay() {
        let food = [
            FoodEntry(name: "A", calories: 300, timestamp: date(2026, 9, 12, 8)),
            FoodEntry(name: "B", calories: 400, timestamp: date(2026, 9, 13, 8)),
        ]
        let scoped = HydrationStore.food(food, on: date(2026, 9, 12), calendar: calendar)
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(HydrationStore.calories(of: scoped), 300)
    }

    func testAnEmptyDayIsEmptyRatherThanEverything() {
        let drinks = [DrinkEntry(amountML: 250, timestamp: date(2026, 9, 12))]
        XCTAssertTrue(HydrationStore.drinks(drinks, on: date(2026, 9, 1), calendar: calendar).isEmpty)
    }

    /// A past day is scored against the goal that applied then, the same as the
    /// calendar does — the Today screen must not show it against today's target.
    func testAPastDayUsesThatDaysGoal() {
        let periods = [
            GoalPeriod(startDate: date(2026, 9, 1),
                       goal: ResolvedGoal(weightGoal: .maintain, calorieGoal: 1800, waterGoalML: 2000)),
            GoalPeriod(startDate: date(2026, 9, 15),
                       goal: ResolvedGoal(weightGoal: .gain, calorieGoal: 2600, waterGoalML: 2500)),
        ]
        let fallback = ResolvedGoal(weightGoal: .lose, calorieGoal: 1500, waterGoalML: 1500)

        let early = GoalHistory.goal(on: date(2026, 9, 5), periods: periods,
                                     fallback: fallback, calendar: calendar)
        XCTAssertEqual(early.calorieGoal, 1800)
        XCTAssertEqual(early.waterGoalML, 2000)

        let late = GoalHistory.goal(on: date(2026, 9, 20), periods: periods,
                                    fallback: fallback, calendar: calendar)
        XCTAssertEqual(late.calorieGoal, 2600)
    }
}
