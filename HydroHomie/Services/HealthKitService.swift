// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import HealthKit

/// What Health knows about the body, for seeding the goal calculator.
///
/// Every field is optional and independently so: Health may hold a height and no
/// weight, or a date of birth the user has chosen not to share. A missing value
/// means "not available", never zero.
struct BodyMetrics: Equatable, Sendable {
    var weightKg: Double?
    var heightCm: Double?
    var age: Int?
    var sex: BiologicalSex?

    var isEmpty: Bool {
        weightKg == nil && heightCm == nil && age == nil && sex == nil
    }
}

/// Thin wrapper over HealthKit: mirrors what the app logs into Health, and reads
/// back the body measurements the calorie estimate needs.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private let waterType = HKQuantityType(.dietaryWater)
    private let energyType = HKQuantityType(.dietaryEnergyConsumed)

    /// The nutrients the app tracks, paired with the unit Health expects. Energy is
    /// kilocalories; everything else is grams.
    private var nutrientTypes: [(HKQuantityType, HKUnit, (Nutrients) -> Double)] {
        [
            (energyType, .kilocalorie(), \.energyKcal),
            (HKQuantityType(.dietaryCarbohydrates), .gram(), \.carbs),
            (HKQuantityType(.dietarySugar), .gram(), \.sugar),
            (HKQuantityType(.dietaryFiber), .gram(), \.fiber),
            (HKQuantityType(.dietaryProtein), .gram(), \.protein),
            (HKQuantityType(.dietaryFatTotal), .gram(), \.fat),
        ]
    }

    private var shareTypes: Set<HKSampleType> {
        Set(nutrientTypes.map(\.0) as [HKSampleType] + [waterType])
    }

    /// Body measurements are read-only: the app seeds its calculator from them and
    /// never writes back, because it has no better idea of your weight than you do.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = Set(shareTypes)
        types.formUnion([
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex),
        ] as [HKObjectType])
        return types
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether nutrition writing has been granted. Someone who turned the toggle on
    /// before this app wrote anything but water has only ever been asked about water,
    /// so the switch reads "on" while food would silently not sync.
    var isAuthorizedForNutrition: Bool {
        HKHealthStore.isHealthDataAvailable()
            && store.authorizationStatus(for: energyType) != .notDetermined
    }

    /// Prompts for permission. Returns `false` when HealthKit is unavailable or the
    /// request fails; HealthKit deliberately never reveals a denial, so a `true` here
    /// means "the sheet was shown", not "access was granted".
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Water

    /// Writes a water sample and returns its identifier, so the caller can retract
    /// exactly this sample later. Returns nil when nothing was written.
    func save(amountML: Double, date: Date) async -> UUID? {
        guard canShare(waterType) else { return nil }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountML)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date
        )
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Retracts a previously written sample. Without this, deleting an entry in the
    /// app would leave Health permanently out of step.
    func delete(sampleID: UUID) async {
        guard canShare(waterType) else { return }
        let predicate = HKQuery.predicateForObject(with: sampleID)
        _ = try? await store.deleteObjects(of: waterType, predicate: predicate)
    }

    // MARK: - Food

    /// Mirrors one logged serving into Health as energy plus its macronutrients, and
    /// returns the ids written so the entry can retract exactly these samples.
    ///
    /// Nutrients that are zero are skipped rather than written as an explicit zero:
    /// most foods genuinely lack some of them, and Health treats a zero sample as a
    /// measurement rather than as an absence.
    func saveFood(name: String, nutrients: Nutrients, date: Date) async -> [UUID] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        // The food's name rides along so Health shows something more useful than a
        // bare number in its own log.
        let metadata = [HKMetadataKeyFoodType: name]

        let samples: [HKQuantitySample] = nutrientTypes.compactMap { type, unit, value in
            let amount = value(nutrients)
            guard amount > 0, canShare(type) else { return nil }
            return HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: amount),
                start: date,
                end: date,
                metadata: metadata
            )
        }
        guard !samples.isEmpty else { return [] }

        do {
            try await store.save(samples)
            return samples.map(\.uuid)
        } catch {
            return []
        }
    }

    /// Retracts the samples written for one logged serving. Each is deleted against
    /// its own type, since `deleteObjects` is type-scoped.
    func deleteFood(sampleIDs: [UUID]) async {
        guard !sampleIDs.isEmpty, HKHealthStore.isHealthDataAvailable() else { return }
        let predicate = HKQuery.predicateForObjects(with: Set(sampleIDs))
        for (type, _, _) in nutrientTypes where canShare(type) {
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    // MARK: - Body measurements

    /// Reads what Health knows about the body, for seeding the goal calculator.
    ///
    /// Anything unreadable comes back nil rather than throwing: HealthKit never
    /// discloses whether a read was denied or simply has no data, so from here the
    /// two are the same thing and the caller keeps whatever the user already typed.
    func readBodyMetrics() async -> BodyMetrics {
        guard HKHealthStore.isHealthDataAvailable() else { return BodyMetrics() }

        return BodyMetrics(
            weightKg: await mostRecent(HKQuantityType(.bodyMass), as: .gramUnit(with: .kilo)),
            heightCm: await mostRecent(HKQuantityType(.height), as: .meterUnit(with: .centi)),
            age: currentAge(),
            sex: recordedSex()
        )
    }

    /// Health stores a date of birth, not an age, so this is only as current as the
    /// calendar — which is the point.
    private func currentAge() -> Int? {
        guard let components = try? store.dateOfBirthComponents(),
              let birthday = Calendar.current.date(from: components)
        else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
        guard let years, (0...130).contains(years) else { return nil }
        return years
    }

    /// Health offers four values here; the Mifflin–St Jeor equation only has
    /// coefficients for two, so "other" and "not set" are left for the user to answer.
    private func recordedSex() -> BiologicalSex? {
        guard let recorded = try? store.biologicalSex().biologicalSex else { return nil }
        switch recorded {
        case .female: return .female
        case .male: return .male
        case .other, .notSet: return nil
        @unknown default: return nil
        }
    }

    private func mostRecent(_ type: HKQuantityType, as unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func canShare(_ type: HKSampleType) -> Bool {
        HKHealthStore.isHealthDataAvailable()
            && store.authorizationStatus(for: type) == .sharingAuthorized
    }
}
