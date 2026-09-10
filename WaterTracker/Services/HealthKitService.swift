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

    func save(amountML: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard store.authorizationStatus(for: waterType) == .sharingAuthorized else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountML)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date
        )
        try? await store.save(sample)
    }
}
