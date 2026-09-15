// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// Date-range and aggregation helpers shared by the app and the widget.
enum HydrationStore {

    /// Fetch descriptor for every entry logged on the calendar day containing `date`.
    static func entriesDescriptor(
        on date: Date,
        calendar: Calendar = .current
    ) -> FetchDescriptor<DrinkEntry> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return FetchDescriptor<DrinkEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    /// Fetch descriptor covering the last `days` calendar days, including today.
    static func entriesDescriptor(
        lastDays days: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> FetchDescriptor<DrinkEntry> {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: date)) ?? date
        return FetchDescriptor<DrinkEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func total(of entries: [DrinkEntry]) -> Double {
        entries.reduce(0) { $0 + $1.amountML }
    }

    /// Per-day totals for the last `days` days, oldest first. Days with no entries
    /// are included with a zero total so charts keep an even x-axis.
    static func dailyTotals(
        from entries: [DrinkEntry],
        lastDays days: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        let today = calendar.startOfDay(for: date)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(date: day, totalML: total(of: grouped[day] ?? []))
        }
    }
}

struct DailyTotal: Identifiable, Hashable, Sendable {
    var date: Date
    var totalML: Double
    var id: Date { date }
}

// MARK: - Food

extension HydrationStore {

    /// Fetch descriptor for every food entry logged on the calendar day containing `date`.
    static func foodDescriptor(
        on date: Date,
        calendar: Calendar = .current
    ) -> FetchDescriptor<FoodEntry> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func calories(of entries: [FoodEntry]) -> Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// Fraction of `goal` that `consumed` represents. Values above 1 mean the goal was
    /// passed; a goal of zero or less yields 0 rather than a division by zero.
    static func progress(consumed: Double, goal: Double) -> Double {
        goal > 0 ? consumed / goal : 0
    }

    /// What is left of `goal`. Negative once the goal has been passed.
    static func remaining(goal: Double, consumed: Double) -> Double {
        goal - consumed
    }
}

// MARK: - Combined log

/// One row of Today's log. Water and food are separate models, so they are merged
/// into this for display and sorted by time.
enum LogItem: Identifiable {
    case water(DrinkEntry)
    case food(FoodEntry)

    var id: UUID {
        switch self {
        case .water(let entry): entry.id
        case .food(let entry): entry.id
        }
    }

    var timestamp: Date {
        switch self {
        case .water(let entry): entry.timestamp
        case .food(let entry): entry.timestamp
        }
    }
}

extension HydrationStore {
    /// Merges both streams into a single newest-first log.
    static func mergedLog(water: [DrinkEntry], food: [FoodEntry]) -> [LogItem] {
        (water.map(LogItem.water) + food.map(LogItem.food))
            .sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Macros

struct MacroTotals: Equatable, Sendable {
    var carbs: Double = 0
    /// A subset of `carbs`, not an addition to it.
    var sugar: Double = 0
    /// Likewise a subset of `carbs`.
    var fiber: Double = 0
    var protein: Double = 0
    var fat: Double = 0
}

extension HydrationStore {
    static func macros(of entries: [FoodEntry]) -> MacroTotals {
        entries.reduce(into: MacroTotals()) { totals, entry in
            totals.carbs += entry.carbsGrams
            totals.sugar += entry.sugarGrams
            totals.fiber += entry.fiberGrams
            totals.protein += entry.proteinGrams
            totals.fat += entry.fatGrams
        }
    }
}

// MARK: - Months

/// One day's intake and how it scored against the goal in force that day.
struct DayProgress: Identifiable, Sendable {
    var date: Date
    var waterML: Double
    var calories: Double
    var food: GoalOutcome
    var water: GoalOutcome
    /// False for days after today: nothing can have been logged yet, so they are
    /// blank rather than missed.
    var isPast: Bool

    var id: Date { date }
}

extension HydrationStore {

    /// Fetch descriptor covering the calendar month containing `date`.
    static func drinksDescriptor(
        inMonthOf date: Date,
        calendar: Calendar = .current
    ) -> FetchDescriptor<DrinkEntry> {
        let (start, end) = monthBounds(of: date, calendar: calendar)
        return FetchDescriptor<DrinkEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func monthBounds(
        of date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Every day of the month with its totals and outcomes. Days with no entries come
    /// back as `untracked`, which is not the same as missed.
    static func month(
        of date: Date,
        drinks: [DrinkEntry],
        food: [FoodEntry],
        periods: [GoalPeriod],
        fallback: ResolvedGoal,
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> [DayProgress] {
        let (start, end) = monthBounds(of: date, calendar: calendar)
        let drinksByDay = Dictionary(grouping: drinks) { calendar.startOfDay(for: $0.timestamp) }
        let foodByDay = Dictionary(grouping: food) { calendar.startOfDay(for: $0.timestamp) }
        let endOfToday = calendar.startOfDay(for: today)

        var days: [DayProgress] = []
        var cursor = start
        while cursor < end {
            let goal = GoalHistory.goal(on: cursor, periods: periods,
                                        fallback: fallback, calendar: calendar)
            let water = total(of: drinksByDay[cursor] ?? [])
            let energy = calories(of: foodByDay[cursor] ?? [])

            days.append(DayProgress(
                date: cursor,
                waterML: water,
                calories: energy,
                food: goal.weightGoal.calorieOutcome(consumed: energy, target: goal.calorieGoal),
                water: waterOutcome(consumed: water, target: goal.waterGoalML),
                isPast: cursor <= endOfToday
            ))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? end
        }
        return days
    }
}
