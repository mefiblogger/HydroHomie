// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A month at a glance: two rings per day, calories outside and water inside,
/// coloured when that day's goal was met.
///
/// Deliberately not gauges — these say met or missed, not how close you got, so a
/// partial arc would invite reading a precision that isn't there.
struct GoalCalendarView: View {
    var days: [DayProgress]
    var month: Date
    /// Tapping a day opens it on the Today screen.
    var onSelect: (Date) -> Void = { _ in }

    private let calendar = Calendar.current

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    /// Blank cells so the first of the month lands under the right weekday.
    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first.date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayInitials: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + offset) % 7] }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(days) { day in
                    Button {
                        onSelect(day.date)
                    } label: {
                        DayCell(day: day, isToday: calendar.isDateInToday(day.date))
                    }
                    .buttonStyle(.plain)
                    // A day that has not happened yet has nothing to open.
                    .disabled(!day.isPast)
                }
            }
        }
    }
}

private struct DayCell: View {
    var day: DayProgress
    var isToday: Bool

    var body: some View {
        ZStack {
            // Calories on the outside, water within — the same order as the gauge.
            Circle()
                .stroke(colour(day.calorie, active: .brand), lineWidth: 2.5)
                .frame(width: 34, height: 34)
            Circle()
                .stroke(colour(day.water, active: .water), lineWidth: 2.5)
                .frame(width: 25, height: 25)

            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(day.isPast ? .primary : .tertiary)
        }
        .frame(height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(day.isPast ? .isButton : [])
    }

    private func colour(_ outcome: GoalOutcome, active: Color) -> Color {
        // A day that has not happened yet is neither met nor missed.
        guard day.isPast else { return .clear }
        switch outcome {
        case .met: return active
        case .missed, .untracked: return active.opacity(0.18)
        }
    }

    private var label: String {
        let date = day.date.formatted(.dateTime.day().month(.wide))
        guard day.isPast else { return date }
        return String(localized: "\(date). Calories \(describe(day.calorie)), water \(describe(day.water)).",
                      comment: "VoiceOver summary of one day in the goal calendar")
    }

    private func describe(_ outcome: GoalOutcome) -> String {
        switch outcome {
        case .met: String(localized: "goal met", comment: "VoiceOver, day outcome")
        case .missed: String(localized: "goal missed", comment: "VoiceOver, day outcome")
        case .untracked: String(localized: "nothing logged", comment: "VoiceOver, day outcome")
        }
    }
}
