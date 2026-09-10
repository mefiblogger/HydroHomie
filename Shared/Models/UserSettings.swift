import Foundation
import SwiftData

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
    var appearanceRawValue: String = AppAppearance.system.rawValue

    init() {}

    var unit: VolumeUnit {
        get { VolumeUnit(rawValue: unitRawValue) ?? .millilitres }
        set { unitRawValue = newValue.rawValue }
    }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRawValue) ?? .system }
        set { appearanceRawValue = newValue.rawValue }
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
