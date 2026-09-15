// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData


/// What the calorie goal is for. The neutral case matters: without it there is no way
/// to say "keep me where I am".
enum WeightGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case lose
    case maintain
    case gain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain"
        case .gain: "Gain weight"
        }
    }

    /// A 500 kcal daily deficit or surplus is the conventional rate — roughly half a
    /// kilo a week, since a kilo of body fat is about 7,700 kcal.
    var calorieAdjustment: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 500
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Very active"
        case .veryActive: "Extremely active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Desk job, little exercise"
        case .light: "Exercise 1–3 days a week"
        case .moderate: "Exercise 3–5 days a week"
        case .active: "Exercise 6–7 days a week"
        case .veryActive: "Physical job, or training twice a day"
        }
    }

    /// The standard Harris–Benedict activity multipliers.
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

/// Mifflin–St Jeor needs this; it is not asked for any other reason.
enum BiologicalSex: String, Codable, CaseIterable, Identifiable, Sendable {
    case female
    case male

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        }
    }
}

/// Estimates a daily calorie and water target.
///
/// These are population averages, not a prescription — individual needs vary widely
/// with body composition, medication and health conditions.
enum EnergyEstimate {

    /// Basal metabolic rate by the Mifflin–St Jeor equation, the one most widely used
    /// clinically since 1990.
    static func basalRate(
        sex: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        age: Int
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    /// Basal rate scaled for how much you move: total daily energy expenditure.
    static func maintenanceCalories(basalRate: Double, activity: ActivityLevel) -> Double {
        basalRate * activity.factor
    }

    /// Maintenance adjusted for the goal, floored so a deficit can never suggest a
    /// dangerously low intake.
    static func dailyCalories(
        sex: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        age: Int,
        activity: ActivityLevel,
        goal: WeightGoal
    ) -> Double {
        let maintenance = maintenanceCalories(
            basalRate: basalRate(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age),
            activity: activity
        )
        let floor = sex == .male ? 1500.0 : 1200.0
        return max(maintenance + goal.calorieAdjustment, floor)
    }

    /// A common rule of thumb: 35 ml per kilogram of body weight, plus a little for
    /// harder training.
    static func dailyWaterML(weightKg: Double, activity: ActivityLevel) -> Double {
        let base = weightKg * 35
        let extra: Double
        switch activity {
        case .sedentary, .light: extra = 0
        case .moderate: extra = 250
        case .active: extra = 500
        case .veryActive: extra = 750
        }
        // Rounded to a sensible glass, since nobody pours 2,387 ml.
        return ((base + extra) / 50).rounded() * 50
    }
}


/// Whether a day hit its target. `untracked` is distinct from `missed` on purpose:
/// with a weight-loss goal, "eat no more than 105% of target" is trivially satisfied
/// by eating nothing, so a day with no entries must not read as a win.
enum GoalOutcome: String, Sendable {
    case met
    case missed
    case untracked
}

extension WeightGoal {
    /// Tolerance either side of target, as the goal defines it.
    ///
    /// Losing weight cares about the ceiling and not the floor — a light day is fine.
    /// Gaining cares about the floor and not the ceiling. Maintaining cares about both.
    func calorieOutcome(consumed: Double, target: Double) -> GoalOutcome {
        guard target > 0, consumed > 0 else { return .untracked }
        let ratio = consumed / target
        let met: Bool
        switch self {
        case .lose: met = ratio <= 1.05
        case .gain: met = ratio >= 0.95
        case .maintain: met = ratio >= 0.95 && ratio <= 1.05
        }
        return met ? .met : .missed
    }
}

/// Water is judged the same way whatever the weight goal: drink at least 95% of it.
func waterOutcome(consumed: Double, target: Double) -> GoalOutcome {
    guard target > 0, consumed > 0 else { return .untracked }
    return consumed / target >= 0.95 ? .met : .missed
}

/// The goal and targets in force on a particular day.
struct ResolvedGoal: Equatable, Sendable {
    var weightGoal: WeightGoal
    var calorieGoal: Double
    var waterGoalML: Double
}

/// A record of what the goal was from a given day onwards.
///
/// Changing your goal must not rewrite how last month scored, so changes are recorded
/// rather than applied retroactively, and take effect the following day.
@Model
final class GoalPeriod {
    var startDate: Date = Date()
    var weightGoalRawValue: String = WeightGoal.maintain.rawValue
    var calorieGoal: Double = 2000
    var waterGoalML: Double = 2000

    init(startDate: Date, goal: ResolvedGoal) {
        self.startDate = startDate
        self.weightGoalRawValue = goal.weightGoal.rawValue
        self.calorieGoal = goal.calorieGoal
        self.waterGoalML = goal.waterGoalML
    }

    var resolved: ResolvedGoal {
        ResolvedGoal(
            weightGoal: WeightGoal(rawValue: weightGoalRawValue) ?? .maintain,
            calorieGoal: calorieGoal,
            waterGoalML: waterGoalML
        )
    }
}

enum GoalHistory {
    /// The goal in force on `date`: the most recent period that had started by then.
    /// Days before any record fall back to the earliest one rather than to today's
    /// settings, which would be the retroactive rewrite this exists to prevent.
    static func goal(
        on date: Date,
        periods: [GoalPeriod],
        fallback: ResolvedGoal,
        calendar: Calendar = .current
    ) -> ResolvedGoal {
        let day = calendar.startOfDay(for: date)
        let started = periods.filter { calendar.startOfDay(for: $0.startDate) <= day }
        if let latest = started.max(by: { $0.startDate < $1.startDate }) {
            return latest.resolved
        }
        return periods.min(by: { $0.startDate < $1.startDate })?.resolved ?? fallback
    }

    /// Records a change, effective tomorrow. Repeated changes on the same day replace
    /// each other rather than piling up.
    @MainActor
    static func record(
        _ goal: ResolvedGoal,
        in context: ModelContext,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        let effective = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let existing = (try? context.fetch(FetchDescriptor<GoalPeriod>())) ?? []

        if let pending = existing.first(where: {
            calendar.isDate($0.startDate, inSameDayAs: effective)
        }) {
            pending.weightGoalRawValue = goal.weightGoal.rawValue
            pending.calorieGoal = goal.calorieGoal
            pending.waterGoalML = goal.waterGoalML
        } else {
            context.insert(GoalPeriod(startDate: effective, goal: goal))
        }
        try? context.save()
    }
}


/// The three macronutrients a calorie target is divided into.
enum Macro: String, CaseIterable, Identifiable, Sendable {
    case carbs
    case protein
    case fat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .carbs: "Carbohydrates"
        case .protein: "Protein"
        case .fat: "Fat"
        }
    }

    /// Atwater factors: carbohydrate and protein yield 4 kcal a gram, fat 9.
    var kcalPerGram: Double {
        switch self {
        case .carbs, .protein: 4
        case .fat: 9
        }
    }

    /// The Acceptable Macronutrient Distribution Range — the band most dietary
    /// guidance puts each macro in. Outside it is not wrong, just worth noticing:
    /// 35% protein on 2,000 kcal is 175 g, which looks like a mistake until you
    /// know it was deliberate.
    var usualRange: ClosedRange<Double> {
        switch self {
        case .carbs: 45...65
        case .protein: 10...35
        case .fat: 20...35
        }
    }
}

/// How the calorie target is divided, as whole percentages that always total 100.
struct MacroSplit: Equatable, Sendable {
    var carbs: Double
    var protein: Double
    var fat: Double

    /// A conventional starting point — roughly the mid-range of most dietary guidance.
    static let suggested = MacroSplit(carbs: 50, protein: 20, fat: 30)

    subscript(macro: Macro) -> Double {
        get {
            switch macro {
            case .carbs: carbs
            case .protein: protein
            case .fat: fat
            }
        }
        set {
            switch macro {
            case .carbs: carbs = newValue
            case .protein: protein = newValue
            case .fat: fat = newValue
            }
        }
    }

    var total: Double { carbs + protein + fat }

    /// Macros sitting outside the usual guidance band, in a stable order.
    var unusual: [Macro] {
        Macro.allCases.filter { !$0.usualRange.contains(self[$0]) }
    }

    /// Whether a macro is below its band, above it, or within.
    func placement(of macro: Macro) -> MacroPlacement {
        let range = macro.usualRange
        if self[macro] < range.lowerBound { return .below }
        if self[macro] > range.upperBound { return .above }
        return .usual
    }

    /// Grams of `macro` implied by a calorie target.
    func grams(of macro: Macro, calories: Double) -> Double {
        calories * (self[macro] / 100) / macro.kcalPerGram
    }

    /// Sets one macro and pushes the difference onto `absorber`, so the split still
    /// totals 100.
    ///
    /// The difference goes entirely to one macro rather than being spread across both,
    /// which is what lets an exact split be dialled in: set carbs, then protein, and
    /// the first value is still where you put it.
    func setting(_ macro: Macro, to percent: Double, absorbedBy absorber: Macro) -> MacroSplit {
        guard absorber != macro else { return self }
        let value = (min(max(percent, 0), 100)).rounded()

        var result = self
        result[macro] = value
        result[absorber] = (self[absorber] + (self[macro] - value)).rounded()

        // If the absorber cannot take it all, the remaining macro covers the rest.
        if result[absorber] < 0 {
            let third = Macro.allCases.first { $0 != macro && $0 != absorber }!
            result[third] += result[absorber]
            result[absorber] = 0
            result[third] = max(result[third], 0)
        }

        // Rounding can leave the total a point out; put it back on the absorber.
        let drift = 100 - result.total
        if drift != 0 {
            result[absorber] = max(result[absorber] + drift, 0)
        }
        return result
    }
}

enum MacroPlacement: Sendable {
    case below
    case usual
    case above
}

/// Single-row settings record, shared between the app and the widget through the
/// App Group container. Fetched (or created) via `UserSettings.current(in:)`.
@Model
final class UserSettings {
    var dailyGoalML: Double = 2000
    var unitRawValue: String = VolumeUnit.millilitres.rawValue
    var remindersEnabled: Bool = false
    /// Hours between reminders during the active window.
    var reminderIntervalHours: Int = 2
    var reminderStartHour: Int = 8
    var reminderEndHour: Int = 22
    var healthKitEnabled: Bool = false
    var dailyCalorieGoal: Double = 2000
    /// How the calorie target divides, as percentages totalling 100.
    var carbsPercent: Double = MacroSplit.suggested.carbs
    var proteinPercent: Double = MacroSplit.suggested.protein
    var fatPercent: Double = MacroSplit.suggested.fat
    // Superseded by the percentages above, which derive grams from the calorie goal.
    // Left in place rather than removed: this row also anchors the goal history, and
    // dropping stored properties is not worth the migration risk.
    var dailyCarbsGoal: Double = 250
    var dailyProteinGoal: Double = 100
    var dailyFatGoal: Double = 65
    /// Amount added or removed by the quick-add buttons, in millilitres.
    var waterIncrementML: Double = 250
    var appearanceRawValue: String = AppAppearance.system.rawValue

    // MARK: - Goal

    var weightGoalRawValue: String = WeightGoal.maintain.rawValue
    /// Remembered so the calculator does not have to be filled in again. Zero means
    /// never entered.
    var bodyWeightKg: Double = 0
    var bodyHeightCm: Double = 0
    var age: Int = 0
    var sexRawValue: String = BiologicalSex.female.rawValue
    var activityRawValue: String = ActivityLevel.moderate.rawValue

    init() {}

    var unit: VolumeUnit {
        get { VolumeUnit(rawValue: unitRawValue) ?? .millilitres }
        set { unitRawValue = newValue.rawValue }
    }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRawValue) ?? .system }
        set { appearanceRawValue = newValue.rawValue }
    }

    var weightGoal: WeightGoal {
        get { WeightGoal(rawValue: weightGoalRawValue) ?? .maintain }
        set { weightGoalRawValue = newValue.rawValue }
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRawValue) ?? .female }
        set { sexRawValue = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRawValue) ?? .moderate }
        set { activityRawValue = newValue.rawValue }
    }

    var macroSplit: MacroSplit {
        get { MacroSplit(carbs: carbsPercent, protein: proteinPercent, fat: fatPercent) }
        set {
            carbsPercent = newValue.carbs
            proteinPercent = newValue.protein
            fatPercent = newValue.fat
        }
    }

    /// Grams of each macro implied by the current calorie target.
    func macroGrams(_ macro: Macro) -> Double {
        macroSplit.grams(of: macro, calories: dailyCalorieGoal)
    }

    var resolvedGoal: ResolvedGoal {
        ResolvedGoal(
            weightGoal: weightGoal,
            calorieGoal: dailyCalorieGoal,
            waterGoalML: dailyGoalML
        )
    }

    /// Returns the settings row, creating it on first launch.
    @MainActor
    static func current(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        // A starting period, so the first goal change has something to come after.
        context.insert(GoalPeriod(
            startDate: Calendar.current.startOfDay(for: Date()),
            goal: created.resolvedGoal
        ))
        try? context.save()
        return created
    }
}
