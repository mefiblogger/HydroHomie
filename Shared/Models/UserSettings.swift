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
    // A conventional split of a 2000 kcal day: 50% carbs, 20% protein, 30% fat.
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

    /// Returns the settings row, creating it on first launch.
    @MainActor
    static func current(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        try? context.save()
        return created
    }
}
