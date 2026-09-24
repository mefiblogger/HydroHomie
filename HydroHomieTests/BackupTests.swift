// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import XCTest
@testable import HydroHomie

/// The backup file is the only thing standing between a user and a lost phone, and
/// import is the one path in the app that can destroy data. These tests are mostly
/// about the second half.
@MainActor
final class BackupTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DrinkEntry.self, FoodEntry.self, FoodItem.self,
                 GoalPeriod.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// A store with one of everything, including the awkward cases: a food measured
    /// in millilitres, named portions, a barcode, and a non-ASCII name.
    @discardableResult
    private func populate(_ context: ModelContext) throws -> FoodItem {
        let juice = FoodItem(
            name: "Alma lé",
            per100g: Nutrients(energyKcal: 46, carbs: 11.2, sugar: 10.9,
                               fiber: 0.1, protein: 0.1, fat: 0.1),
            measure: .millilitres,
            defaultPortionAmount: 250,
            portions: [NamedPortion(kind: .glass, amount: 250),
                       NamedPortion(kind: .bottle, amount: 500)],
            icon: .softDrink,
            barcode: "5901234123457"
        )
        context.insert(juice)

        context.insert(DrinkEntry(amountML: 250, timestamp: .now.addingTimeInterval(-3600)))
        context.insert(FoodEntry(
            name: juice.name,
            nutrients: juice.nutrients(forAmount: 500),
            portionAmount: 500,
            measure: .millilitres,
            portionCount: 1,
            portionKind: .bottle,
            icon: juice.icon,
            timestamp: .now.addingTimeInterval(-1800),
            itemID: juice.id
        ))

        let settings = UserSettings.current(in: context)
        settings.dailyGoalML = 3000
        settings.dailyCalorieGoal = 2400
        settings.age = 35
        settings.remindersEnabled = true
        try context.save()
        return juice
    }

    // MARK: - Round trip

    /// The test that matters: everything out, everything back, field for field.
    func testRoundTripPreservesEverything() throws {
        let source = try makeContext()
        let juice = try populate(source)
        let archive = try BackupService.export(from: source)

        let restored = try makeContext()
        try BackupService.restore(archive, into: restored)

        let items = try restored.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(items.count, 1)
        let copy = try XCTUnwrap(items.first)
        XCTAssertEqual(copy.id, juice.id)
        XCTAssertEqual(copy.name, "Alma lé")
        XCTAssertEqual(copy.measure, .millilitres)
        XCTAssertEqual(copy.barcode, "5901234123457")
        XCTAssertEqual(copy.defaultPortionAmount, 250)
        XCTAssertEqual(copy.icon, FoodIcon.softDrink.rawValue)
        XCTAssertEqual(copy.portions.count, 2)
        XCTAssertEqual(copy.portions.first { $0.kind == .bottle }?.amount, 500)
        XCTAssertEqual(copy.per100g.energyKcal, 46, accuracy: 0.0001)

        let food = try restored.fetch(FetchDescriptor<FoodEntry>())
        XCTAssertEqual(food.count, 1)
        XCTAssertEqual(food.first?.portionKind, .bottle)
        XCTAssertEqual(food.first?.portionCount, 1)
        XCTAssertEqual(food.first?.itemID, juice.id)

        let water = try restored.fetch(FetchDescriptor<DrinkEntry>())
        XCTAssertEqual(water.count, 1)
        XCTAssertEqual(water.first?.amountML, 250)

        let settings = try XCTUnwrap(restored.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.dailyGoalML, 3000)
        XCTAssertEqual(settings.dailyCalorieGoal, 2400)
        XCTAssertEqual(settings.age, 35)
        XCTAssertTrue(settings.remindersEnabled)
    }

    /// A drink logged by volume keeps its measure: `portionGrams` holds millilitres
    /// for those rows, and the file must not quietly turn them into grams.
    func testMillilitreEntriesKeepTheirMeasure() throws {
        let source = try makeContext()
        try populate(source)
        let archive = try BackupService.export(from: source)

        let restored = try makeContext()
        try BackupService.restore(archive, into: restored)

        let entry = try XCTUnwrap(restored.fetch(FetchDescriptor<FoodEntry>()).first)
        XCTAssertEqual(entry.measure, .millilitres)
        XCTAssertEqual(entry.portionAmount, 500)
    }

    func testUnicodeNamesAndEmojiSurviveTheFile() throws {
        let source = try makeContext()
        try populate(source)

        let data = try BackupService.export(from: source).encoded()
        let archive = try BackupArchive.decoded(from: data)

        XCTAssertEqual(archive.foodItems.first?.name, "Alma lé")
        XCTAssertEqual(archive.foodItems.first?.icon, FoodIcon.softDrink.rawValue)
    }

    // MARK: - Import safety

    func testImportingTwiceAddsNothingTheSecondTime() throws {
        let source = try makeContext()
        try populate(source)
        let archive = try BackupService.export(from: source)

        let restored = try makeContext()
        let first = try BackupService.restore(archive, into: restored)
        let second = try BackupService.restore(archive, into: restored)

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(second.drinkEntries, 0)
        XCTAssertEqual(second.foodEntries, 0)
        XCTAssertEqual(second.foodItems, 0)
        XCTAssertEqual(second.goalPeriods, 0)
        XCTAssertEqual(try restored.fetch(FetchDescriptor<FoodEntry>()).count, 1)
        XCTAssertEqual(try restored.fetch(FetchDescriptor<FoodItem>()).count, 1)
    }

    /// Restoring an old backup must not remove anything logged since.
    func testImportingAnOlderBackupKeepsNewerEntries() throws {
        let source = try makeContext()
        try populate(source)
        let archive = try BackupService.export(from: source)

        let restored = try makeContext()
        restored.insert(DrinkEntry(amountML: 999, timestamp: .now))
        try restored.save()

        try BackupService.restore(archive, into: restored)

        let amounts = try restored.fetch(FetchDescriptor<DrinkEntry>()).map(\.amountML)
        XCTAssertEqual(amounts.count, 2)
        XCTAssertTrue(amounts.contains(999))
    }

    /// Goal history exists so that changing a goal never rewrites how a past day
    /// scored. An import is not allowed to do it either.
    func testImportCannotRewriteAnExistingGoalDay() throws {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now.addingTimeInterval(-7 * 86_400))

        let source = try makeContext()
        source.insert(GoalPeriod(startDate: day, goal: ResolvedGoal(
            weightGoal: .lose, calorieGoal: 1500, waterGoalML: 1500)))
        source.insert(DrinkEntry(amountML: 100))
        try source.save()
        let archive = try BackupService.export(from: source)

        let restored = try makeContext()
        restored.insert(GoalPeriod(startDate: day, goal: ResolvedGoal(
            weightGoal: .gain, calorieGoal: 3000, waterGoalML: 3000)))
        try restored.save()

        try BackupService.restore(archive, into: restored)

        let periods = try restored.fetch(FetchDescriptor<GoalPeriod>())
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
        XCTAssertEqual(periods.count, 1, "the day must not gain a second period")
        XCTAssertEqual(periods.first?.calorieGoal, 3000, "the existing goal must win")
    }

    // MARK: - Bad input

    func testAFutureVersionIsRefusedRatherThanPartlyRead() throws {
        var archive = BackupArchive()
        archive.version = BackupArchive.currentVersion + 1
        archive.drinkEntries = [
            DrinkEntryBackup(id: UUID(), amountML: 250, timestamp: .now, source: "app")
        ]
        let data = try BackupArchive.encoder().encode(archive)

        XCTAssertThrowsError(try BackupArchive.decoded(from: data)) { error in
            XCTAssertEqual(error as? BackupError, .tooNew(BackupArchive.currentVersion + 1))
        }
    }

    func testTruncatedFileIsRejected() throws {
        let source = try makeContext()
        try populate(source)
        let data = try BackupService.export(from: source).encoded()
        let truncated = data.prefix(data.count / 2)

        XCTAssertThrowsError(try BackupArchive.decoded(from: Data(truncated))) { error in
            XCTAssertEqual(error as? BackupError, .unreadable)
        }
    }

    func testUnrelatedJSONIsRejected() {
        let data = Data(#"{"hello":"world"}"#.utf8)
        XCTAssertThrowsError(try BackupArchive.decoded(from: data)) { error in
            XCTAssertEqual(error as? BackupError, .unreadable)
        }
    }

    /// A rejected file must leave the store exactly as it was.
    func testAnEmptyArchiveChangesNothing() throws {
        let context = try makeContext()
        try populate(context)
        let before = try context.fetch(FetchDescriptor<FoodEntry>()).count

        XCTAssertThrowsError(try BackupService.restore(BackupArchive(), into: context)) { error in
            XCTAssertEqual(error as? BackupError, .empty)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodEntry>()).count, before)
    }

    // MARK: - Summary

    func testSummaryDescribesTheFileWithoutTouchingTheStore() throws {
        let source = try makeContext()
        try populate(source)
        let archive = try BackupService.export(from: source)

        let summary = BackupService.summarize(archive)
        XCTAssertEqual(summary.drinkEntries, 1)
        XCTAssertEqual(summary.foodEntries, 1)
        XCTAssertEqual(summary.foodItems, 1)
        XCTAssertTrue(summary.hasSettings)
        XCTAssertEqual(summary.totalEntries, 2)
        XCTAssertNotNil(summary.earliest)
        XCTAssertNotNil(summary.latest)
    }

    func testFilenameCarriesTheExportDate() {
        var archive = BackupArchive()
        archive.exportedAt = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertTrue(archive.suggestedFilename.hasPrefix("HydroHomie-Backup-"))
        XCTAssertTrue(archive.suggestedFilename.hasSuffix(".json"))
    }
}
