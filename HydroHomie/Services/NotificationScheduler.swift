import Foundation
import UserNotifications

/// Schedules a repeating set of hydration reminders across the user's active window.
/// One calendar-triggered notification per slot, all rebuilt whenever settings change.
enum NotificationScheduler {
    private static let categoryIdentifier = "hydration-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(from settings: UserSettings) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(categoryIdentifier) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard settings.remindersEnabled else { return }

        let interval = max(settings.reminderIntervalHours, 1)
        let start = settings.reminderStartHour
        let end = settings.reminderEndHour
        guard end > start else { return }

        for hour in stride(from: start, through: end, by: interval) {
            let content = UNMutableNotificationContent()
            content.title = "Time for water"
            content.body = "A quick glass keeps you on track for today's goal."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let request = UNNotificationRequest(
                identifier: "\(categoryIdentifier)-\(hour)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }
}
