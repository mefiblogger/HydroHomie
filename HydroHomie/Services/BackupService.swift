// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// What an archive contains, so the user can be shown it before anything is written.
struct BackupSummary: Equatable {
    var drinkEntries: Int
    var foodEntries: Int
    var foodItems: Int
    var goalPeriods: Int
    var hasSettings: Bool
    /// Range of the log, for "1,240 entries from 3 March to today".
    var earliest: Date?
    var latest: Date?

    var totalEntries: Int { drinkEntries + foodEntries }
}

/// What an import actually changed. Reported back so "nothing new" is visibly
/// different from "restored 1,240 entries".
struct ImportResult: Equatable {
    var drinkEntries = 0
    var foodEntries = 0
    var foodItems = 0
    var goalPeriods = 0
    var settingsRestored = false

    var isEmpty: Bool {
        drinkEntries == 0 && foodEntries == 0 && foodItems == 0
            && goalPeriods == 0 && !settingsRestored
    }
}

/// Reads and writes the whole database as one JSON file.
///
/// Export is a plain snapshot. Import **merges** rather than replaces: an id already
/// present is skipped, so importing the same file twice changes nothing and
/// importing an older backup can never delete newer entries.
enum BackupService {

    // MARK: - Export

    @MainActor
    static func export(from context: ModelContext, appVersion: String? = nil) throws -> BackupArchive {
        let drinks = try context.fetch(FetchDescriptor<DrinkEntry>())
        let food = try context.fetch(FetchDescriptor<FoodEntry>())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        let periods = try context.fetch(FetchDescriptor<GoalPeriod>())
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first

        return BackupArchive(
            version: BackupArchive.currentVersion,
            exportedAt: Date(),
            appVersion: appVersion,
            settings: settings.map(SettingsBackup.init(from:)),
            goalPeriods: periods.map(GoalPeriodBackup.init(from:)),
            foodItems: items.map(FoodItemBackup.init(from:)),
            drinkEntries: drinks.map(DrinkEntryBackup.init(from:)),
            foodEntries: food.map(FoodEntryBackup.init(from:))
        )
    }

    // MARK: - Inspect

    /// Describes an archive without touching the store, so the user confirms against
    /// what is actually in the file.
    static func summarize(_ archive: BackupArchive) -> BackupSummary {
        let dates = archive.drinkEntries.map(\.timestamp) + archive.foodEntries.map(\.timestamp)
        return BackupSummary(
            drinkEntries: archive.drinkEntries.count,
            foodEntries: archive.foodEntries.count,
            foodItems: archive.foodItems.count,
            goalPeriods: archive.goalPeriods.count,
            hasSettings: archive.settings != nil,
            earliest: dates.min(),
            latest: dates.max()
        )
    }

    // MARK: - Import

    /// Merges an archive into the store.
    ///
    /// Everything is read and matched before anything is inserted, and the whole
    /// merge is saved once — a file that fails partway leaves the store untouched.
    @MainActor
    @discardableResult
    static func restore(
        _ archive: BackupArchive,
        into context: ModelContext,
        calendar: Calendar = .current
    ) throws -> ImportResult {
        guard !archive.isEmpty else { throw BackupError.empty }

        var result = ImportResult()

        // Ids already present win: the entry on this phone is the one with the
        // Health sample links attached to it.
        let existingDrinkIDs = Set(try context.fetch(FetchDescriptor<DrinkEntry>()).map(\.id))
        let existingFoodIDs = Set(try context.fetch(FetchDescriptor<FoodEntry>()).map(\.id))
        let existingItemIDs = Set(try context.fetch(FetchDescriptor<FoodItem>()).map(\.id))

        for item in archive.foodItems where !existingItemIDs.contains(item.id) {
            context.insert(item.model())
            result.foodItems += 1
        }
        for drink in archive.drinkEntries where !existingDrinkIDs.contains(drink.id) {
            context.insert(drink.model())
            result.drinkEntries += 1
        }
        for entry in archive.foodEntries where !existingFoodIDs.contains(entry.id) {
            context.insert(entry.model())
            result.foodEntries += 1
        }

        result.goalPeriods = try restoreGoalPeriods(archive.goalPeriods,
                                                    into: context, calendar: calendar)

        if let settings = archive.settings {
            settings.apply(to: UserSettings.current(in: context))
            result.settingsRestored = true
        }

        try context.save()
        return result
    }

    /// `GoalPeriod` has no id, so periods match on the day they start.
    ///
    /// An existing period always wins. Overwriting one would change what a past day
    /// was scored against, and goal history exists precisely so that never happens —
    /// that rule outranks the import.
    @MainActor
    private static func restoreGoalPeriods(
        _ periods: [GoalPeriodBackup],
        into context: ModelContext,
        calendar: Calendar
    ) throws -> Int {
        var days = Set(
            try context.fetch(FetchDescriptor<GoalPeriod>())
                .map { calendar.startOfDay(for: $0.startDate) }
        )
        var added = 0
        for period in periods {
            let day = calendar.startOfDay(for: period.startDate)
            guard !days.contains(day) else { continue }
            context.insert(period.model())
            days.insert(day)
            added += 1
        }
        return added
    }
}

// MARK: - Model ↔ DTO

extension DrinkEntryBackup {
    init(from entry: DrinkEntry) {
        self.init(id: entry.id, amountML: entry.amountML,
                  timestamp: entry.timestamp, source: entry.source)
    }

    func model() -> DrinkEntry {
        let entry = DrinkEntry(
            amountML: amountML,
            timestamp: timestamp,
            source: DrinkSource(rawValue: source) ?? .app
        )
        // Keep the original id so a second import recognises this row.
        entry.id = id
        return entry
    }
}

extension FoodEntryBackup {
    init(from entry: FoodEntry) {
        self.init(
            id: entry.id, name: entry.name, portionAmount: entry.portionAmount,
            measure: entry.measureRawValue, calories: entry.calories,
            carbs: entry.carbsGrams, sugar: entry.sugarGrams, fiber: entry.fiberGrams,
            protein: entry.proteinGrams, fat: entry.fatGrams, timestamp: entry.timestamp,
            itemID: entry.itemID, portionCount: entry.portionCount,
            portionKind: entry.portionKindRaw, icon: entry.icon
        )
    }

    func model() -> FoodEntry {
        let entry = FoodEntry(
            name: name,
            nutrients: Nutrients(energyKcal: calories, carbs: carbs, sugar: sugar,
                                 fiber: fiber, protein: protein, fat: fat),
            portionAmount: portionAmount,
            measure: FoodMeasure(rawValue: measure) ?? .grams,
            portionCount: portionCount,
            portionKind: portionKind.flatMap(PortionKind.init(rawValue:)),
            icon: icon,
            timestamp: timestamp,
            itemID: itemID
        )
        entry.id = id
        return entry
    }
}

extension FoodItemBackup {
    init(from item: FoodItem) {
        self.init(
            id: item.id, name: item.name, energyKcal: item.energyKcal,
            carbs: item.carbsGrams, sugar: item.sugarGrams, fiber: item.fiberGrams,
            protein: item.proteinGrams, fat: item.fatGrams,
            measure: item.measureRawValue,
            defaultPortionAmount: item.defaultPortionAmount,
            createdAt: item.createdAt, lastUsedAt: item.lastUsedAt,
            barcode: item.barcode,
            portions: item.portions.map {
                NamedPortionBackup(kind: $0.kind.rawValue, amount: $0.amount)
            },
            icon: item.icon
        )
    }

    func model() -> FoodItem {
        let item = FoodItem(
            name: name,
            per100g: Nutrients(energyKcal: energyKcal, carbs: carbs, sugar: sugar,
                               fiber: fiber, protein: protein, fat: fat),
            measure: FoodMeasure(rawValue: measure) ?? .grams,
            icon: FoodIcon(rawValue: icon) ?? .default
        )
        item.id = id
        item.defaultPortionAmount = defaultPortionAmount
        item.createdAt = createdAt
        item.lastUsedAt = lastUsedAt
        item.barcode = barcode
        item.portions = portions.compactMap { portion in
            PortionKind(rawValue: portion.kind).map {
                NamedPortion(kind: $0, amount: portion.amount)
            }
        }
        return item
    }
}

extension GoalPeriodBackup {
    init(from period: GoalPeriod) {
        self.init(startDate: period.startDate,
                  weightGoal: period.weightGoalRawValue,
                  calorieGoal: period.calorieGoal,
                  waterGoalML: period.waterGoalML)
    }

    func model() -> GoalPeriod {
        GoalPeriod(
            startDate: startDate,
            goal: ResolvedGoal(
                weightGoal: WeightGoal(rawValue: weightGoal) ?? .maintain,
                calorieGoal: calorieGoal,
                waterGoalML: waterGoalML
            )
        )
    }
}

extension SettingsBackup {
    init(from settings: UserSettings) {
        self.init(
            dailyGoalML: settings.dailyGoalML,
            unit: settings.unitRawValue,
            remindersEnabled: settings.remindersEnabled,
            reminderIntervalHours: settings.reminderIntervalHours,
            reminderStartHour: settings.reminderStartHour,
            reminderEndHour: settings.reminderEndHour,
            healthKitEnabled: settings.healthKitEnabled,
            dailyCalorieGoal: settings.dailyCalorieGoal,
            carbsPercent: settings.carbsPercent,
            proteinPercent: settings.proteinPercent,
            fatPercent: settings.fatPercent,
            waterIncrementML: settings.waterIncrementML,
            appearance: settings.appearanceRawValue,
            weightGoal: settings.weightGoalRawValue,
            bodyWeightKg: settings.bodyWeightKg,
            bodyHeightCm: settings.bodyHeightCm,
            age: settings.age,
            sex: settings.sexRawValue,
            activity: settings.activityRawValue
        )
    }

    /// Settings restore wholesale. Merging 22 scalars field by field has no rule
    /// anyone could predict, so the file's settings replace the current ones.
    func apply(to settings: UserSettings) {
        settings.dailyGoalML = dailyGoalML
        settings.unitRawValue = unit
        settings.remindersEnabled = remindersEnabled
        settings.reminderIntervalHours = reminderIntervalHours
        settings.reminderStartHour = reminderStartHour
        settings.reminderEndHour = reminderEndHour
        settings.healthKitEnabled = healthKitEnabled
        settings.dailyCalorieGoal = dailyCalorieGoal
        settings.carbsPercent = carbsPercent
        settings.proteinPercent = proteinPercent
        settings.fatPercent = fatPercent
        settings.waterIncrementML = waterIncrementML
        settings.appearanceRawValue = appearance
        settings.weightGoalRawValue = weightGoal
        settings.bodyWeightKg = bodyWeightKg
        settings.bodyHeightCm = bodyHeightCm
        settings.age = age
        settings.sexRawValue = sex
        settings.activityRawValue = activity
    }
}
