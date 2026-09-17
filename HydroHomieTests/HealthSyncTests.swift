// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import XCTest
@testable import HydroHomie

/// HealthKit itself cannot be exercised in a unit test — it needs a real store and a
/// user tapping a permission sheet. What is testable is the bookkeeping around it:
/// that entries carry the sample ids needed to retract exactly what was written, and
/// that a partial read from Health is represented honestly.
final class HealthSyncTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DrinkEntry.self, FoodEntry.self, FoodItem.self,
                 GoalPeriod.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Sample bookkeeping

    /// An entry logged with Health off must not claim to own any samples, or a later
    /// delete would try to retract rows belonging to something else.
    func testAnEntryStartsWithNoHealthSamples() {
        let entry = FoodEntry(name: "Apple", nutrients: Nutrients(energyKcal: 52))
        XCTAssertTrue(entry.healthKitSampleIDs.isEmpty)
    }

    func testSampleIDsSurviveAStoreRoundTrip() throws {
        let context = try makeContext()
        let ids = [UUID(), UUID(), UUID()]
        let entry = FoodEntry(name: "Porridge", nutrients: Nutrients(energyKcal: 170))
        entry.healthKitSampleIDs = ids
        context.insert(entry)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<FoodEntry>())
        XCTAssertEqual(stored.first?.healthKitSampleIDs, ids)
    }

    /// Deleting the entry has to happen whether or not Health is reachable; the
    /// retraction is fire-and-forget, the local delete is not.
    @MainActor
    func testDeletingAnEntryWithSamplesStillRemovesIt() throws {
        let context = try makeContext()
        let entry = FoodEntry(name: "Toast", nutrients: Nutrients(energyKcal: 90))
        entry.healthKitSampleIDs = [UUID()]
        context.insert(entry)
        try context.save()

        HydrationLogger.delete(entry, context: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodEntry>()).isEmpty)
    }

    // MARK: - Body metrics

    func testBodyMetricsIsEmptyOnlyWhenNothingWasRead() {
        XCTAssertTrue(BodyMetrics().isEmpty)
        XCTAssertFalse(BodyMetrics(weightKg: 70).isEmpty)
        XCTAssertFalse(BodyMetrics(heightCm: 180).isEmpty)
        XCTAssertFalse(BodyMetrics(age: 34).isEmpty)
        XCTAssertFalse(BodyMetrics(sex: .female).isEmpty)
    }

    /// A partial read is the normal case: Health may hold a height and nothing else.
    /// Fields it cannot answer stay nil so the caller keeps what the user typed.
    func testBodyMetricsKeepsMissingFieldsDistinctFromZero() {
        let metrics = BodyMetrics(weightKg: nil, heightCm: 180, age: nil, sex: .male)
        XCTAssertNil(metrics.weightKg)
        XCTAssertNil(metrics.age)
        XCTAssertEqual(metrics.heightCm, 180)
        XCTAssertEqual(metrics.sex, .male)
        XCTAssertFalse(metrics.isEmpty)
    }

    /// The estimate must work from imported figures exactly as from typed ones.
    func testImportedMetricsProduceTheSameEstimateAsTypedOnes() {
        let metrics = BodyMetrics(weightKg: 82, heightCm: 178, age: 41, sex: .male)
        let fromImport = EnergyEstimate.dailyCalories(
            sex: metrics.sex!, weightKg: metrics.weightKg!, heightCm: metrics.heightCm!,
            age: metrics.age!, activity: .moderate, goal: .maintain
        )
        let typed = EnergyEstimate.dailyCalories(
            sex: .male, weightKg: 82, heightCm: 178,
            age: 41, activity: .moderate, goal: .maintain
        )
        XCTAssertEqual(fromImport, typed, accuracy: 0.0001)
    }
}
