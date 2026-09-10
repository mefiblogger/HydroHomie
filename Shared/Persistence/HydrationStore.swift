import Foundation
import SwiftData

/// Date-range and aggregation helpers shared by the app and the widget.
enum HydrationStore {

    /// Fetch descriptor for every entry logged on the calendar day containing `date`.
    static func entriesDescriptor(
        on date: Date,
        calendar: Calendar = .current
    ) -> FetchDescriptor<DrinkEntry> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return FetchDescriptor<DrinkEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    /// Fetch descriptor covering the last `days` calendar days, including today.
    static func entriesDescriptor(
        lastDays days: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> FetchDescriptor<DrinkEntry> {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: date)) ?? date
        return FetchDescriptor<DrinkEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func total(of entries: [DrinkEntry]) -> Double {
        entries.reduce(0) { $0 + $1.amountML }
    }

    /// Per-day totals for the last `days` days, oldest first. Days with no entries
    /// are included with a zero total so charts keep an even x-axis.
    static func dailyTotals(
        from entries: [DrinkEntry],
        lastDays days: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        let today = calendar.startOfDay(for: date)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(date: day, totalML: total(of: grouped[day] ?? []))
        }
    }
}

struct DailyTotal: Identifiable, Hashable, Sendable {
    var date: Date
    var totalML: Double
    var id: Date { date }
}
