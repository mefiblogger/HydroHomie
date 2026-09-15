// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import HealthKit

/// Thin wrapper over HealthKit for writing dietary water. Read access is requested too,
/// so a future version can reconcile intake logged by other apps.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Prompts for permission. Returns `false` when HealthKit is unavailable or the
    /// request fails; HealthKit deliberately never reveals a denial, so a `true` here
    /// means "the sheet was shown", not "access was granted".
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [waterType], read: [waterType])
            return true
        } catch {
            return false
        }
    }

    /// Writes a water sample and returns its identifier, so the caller can retract
    /// exactly this sample later. Returns nil when nothing was written.
    func save(amountML: Double, date: Date) async -> UUID? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard store.authorizationStatus(for: waterType) == .sharingAuthorized else { return nil }

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
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard store.authorizationStatus(for: waterType) == .sharingAuthorized else { return }
        let predicate = HKQuery.predicateForObject(with: sampleID)
        _ = try? await store.deleteObjects(of: waterType, predicate: predicate)
    }
}
