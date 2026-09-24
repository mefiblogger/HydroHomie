// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// The on-disk backup format.
///
/// These are deliberately plain `Codable` structs rather than the `@Model` classes.
/// The models carry SwiftData machinery and names kept for migration reasons that
/// should not leak into a file someone may read years from now — `portionGrams`
/// holds millilitres for a drink logged by volume, and renaming a stored property
/// later must not silently change the file format.
///
/// Enum values travel as the raw strings already persisted ("grams", "bottle",
/// "lose"), so the file stays readable and the mapping cannot drift.
struct BackupArchive: Codable, Equatable {
    /// Bumped when the shape changes incompatibly. A file claiming a higher version
    /// than this build understands is refused outright rather than half-read.
    static let currentVersion = 1

    var version: Int = currentVersion
    var exportedAt: Date = Date()
    /// Informational only — for someone reading the file, not for import logic.
    var appVersion: String?

    var settings: SettingsBackup?
    var goalPeriods: [GoalPeriodBackup] = []
    var foodItems: [FoodItemBackup] = []
    var drinkEntries: [DrinkEntryBackup] = []
    var foodEntries: [FoodEntryBackup] = []

    var isEmpty: Bool {
        settings == nil && goalPeriods.isEmpty && foodItems.isEmpty
            && drinkEntries.isEmpty && foodEntries.isEmpty
    }
}

// MARK: - Entries

struct DrinkEntryBackup: Codable, Equatable {
    var id: UUID
    var amountML: Double
    var timestamp: Date
    var source: String

    // `healthKitSampleID` is deliberately absent: it names a row in one phone's
    // Health store and means nothing anywhere else.
}

struct FoodEntryBackup: Codable, Equatable {
    var id: UUID
    var name: String
    /// Grams or millilitres, according to `measure`.
    var portionAmount: Double
    var measure: String
    var calories: Double
    var carbs: Double
    var sugar: Double
    var fiber: Double
    var protein: Double
    var fat: Double
    var timestamp: Date
    var itemID: UUID?
    var portionCount: Double
    var portionKind: String?
    var icon: String

    // `healthKitSampleIDs` deliberately absent, as above.
}

// MARK: - Library

struct NamedPortionBackup: Codable, Equatable {
    var kind: String
    /// The size of one, in the food's own measure.
    var amount: Double
}

struct FoodItemBackup: Codable, Equatable {
    var id: UUID
    var name: String
    /// Per 100 g or 100 ml, according to `measure`.
    var energyKcal: Double
    var carbs: Double
    var sugar: Double
    var fiber: Double
    var protein: Double
    var fat: Double
    var measure: String
    var defaultPortionAmount: Double
    var createdAt: Date
    var lastUsedAt: Date
    var barcode: String?
    var portions: [NamedPortionBackup]
    var icon: String
}

// MARK: - Goal and settings

struct GoalPeriodBackup: Codable, Equatable {
    var startDate: Date
    var weightGoal: String
    var calorieGoal: Double
    var waterGoalML: Double
}

struct SettingsBackup: Codable, Equatable {
    var dailyGoalML: Double
    var unit: String
    var remindersEnabled: Bool
    var reminderIntervalHours: Int
    var reminderStartHour: Int
    var reminderEndHour: Int
    var healthKitEnabled: Bool
    var dailyCalorieGoal: Double
    var carbsPercent: Double
    var proteinPercent: Double
    var fatPercent: Double
    var waterIncrementML: Double
    var appearance: String
    var weightGoal: String
    var bodyWeightKg: Double
    var bodyHeightCm: Double
    var age: Int
    var sex: String
    var activity: String
}

// MARK: - Coding

extension BackupArchive {
    /// ISO 8601 dates and sorted keys: the file is meant to be legible, and stable
    /// ordering means two exports of the same data compare equal.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try Self.encoder().encode(self)
    }

    /// Reads an archive, refusing anything this build cannot fully understand rather
    /// than importing part of it.
    static func decoded(from data: Data) throws -> BackupArchive {
        let archive: BackupArchive
        do {
            archive = try decoder().decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
        guard archive.version <= currentVersion else {
            throw BackupError.tooNew(archive.version)
        }
        return archive
    }

    /// `HydroHomie-Backup-2026-09-24.json` — dated, sortable, and unambiguous in a
    /// folder of them.
    var suggestedFilename: String {
        let day = exportedAt.formatted(
            .iso8601.year().month().day().dateSeparator(.dash))
        return "HydroHomie-Backup-\(day).json"
    }
}

enum BackupError: Error, LocalizedError, Equatable {
    case unreadable
    case tooNew(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable:
            String(localized: "That file isn't a HydroHomie backup.",
                   comment: "Import failure")
        case .tooNew:
            String(localized: "That backup was made by a newer version of HydroHomie.",
                   comment: "Import failure")
        case .empty:
            String(localized: "That backup is empty.", comment: "Import failure")
        }
    }
}
