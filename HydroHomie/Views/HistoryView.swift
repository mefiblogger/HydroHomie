// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFood: [FoodEntry]
    @Query private var settingsRows: [UserSettings]
    @Query private var periods: [GoalPeriod]

    /// Any date inside the month on show.
    @State private var month = Date()

    private let calendar = Calendar.current

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }
    private var unit: VolumeUnit { settings.unit }

    private var bounds: (start: Date, end: Date) {
        HydrationStore.monthBounds(of: month, calendar: calendar)
    }

    private var monthDrinks: [DrinkEntry] {
        allDrinks.filter { $0.timestamp >= bounds.start && $0.timestamp < bounds.end }
    }

    private var monthFood: [FoodEntry] {
        allFood.filter { $0.timestamp >= bounds.start && $0.timestamp < bounds.end }
    }

    private var days: [DayProgress] {
        HydrationStore.month(
            of: month,
            drinks: monthDrinks,
            food: monthFood,
            periods: periods,
            fallback: settings.resolvedGoal,
            calendar: calendar
        )
    }

    private var trackedDays: [DayProgress] { days.filter(\.isPast) }

    private var monthName: String {
        month.formatted(calendar.isDate(month, equalTo: Date(), toGranularity: .year)
                        ? .dateTime.month(.wide)
                        : .dateTime.month(.wide).year())
    }

    /// There is nothing to show beyond the current month.
    private var canGoForward: Bool {
        !calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Goal tracking") {
                    monthPager
                    GoalCalendarView(days: days, month: month)
                        .padding(.vertical, 4)
                    legend
                }

                Section("Water") {
                    chart
                        .frame(height: 200)
                        .padding(.vertical, 8)
                }

                Section("Summary") {
                    LabeledContent("Water average",
                                   value: unit.format(millilitres: averageWater))
                    LabeledContent("Calorie average",
                                   value: "\(Int(averageCalories.rounded())) kcal")
                    LabeledContent("Food goals met",
                                   value: "\(count(\.food)) of \(trackedDays.count) days")
                    LabeledContent("Water goals met",
                                   value: "\(count(\.water)) of \(trackedDays.count) days")
                }

                Section("Entries") {
                    if log.isEmpty {
                        Text("Nothing logged in \(monthName).")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(log) { item in
                            entryRow(item)
                        }
                    }
                }
            }
            .navigationTitle("History for \(monthName)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Pieces

    private var monthPager: some View {
        HStack {
            Button {
                step(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.identity)
            Spacer()

            Button {
                step(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Color.brand)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            key(colour: .brand, label: "Food")
            key(colour: .water, label: "Water")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func key(colour: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().stroke(colour, lineWidth: 2.5).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var chart: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Intake", unit.fromMillilitres(day.waterML))
            )
            .foregroundStyle(day.water == .met ? Color.goal.gradient : Color.water.gradient)
            .cornerRadius(3)
        }
        .chartYAxisLabel(unit.shortName)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
    }

    private func entryRow(_ item: LogItem) -> some View {
        HStack {
            switch item {
            case .water(let entry):
                Text(LogIcon.water)
                Text("\(unit.format(millilitres: entry.amountML)) water")
            case .food(let entry):
                Text(entry.icon)
                Text(entry.name).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.timestamp, format: .dateTime.day().month().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Numbers

    private var log: [LogItem] {
        HydrationStore.mergedLog(water: monthDrinks, food: monthFood)
    }

    private var averageWater: Double {
        guard !trackedDays.isEmpty else { return 0 }
        return trackedDays.reduce(0) { $0 + $1.waterML } / Double(trackedDays.count)
    }

    private var averageCalories: Double {
        guard !trackedDays.isEmpty else { return 0 }
        return trackedDays.reduce(0) { $0 + $1.calories } / Double(trackedDays.count)
    }

    private func count(_ outcome: KeyPath<DayProgress, GoalOutcome>) -> Int {
        trackedDays.filter { $0[keyPath: outcome] == .met }.count
    }

    private func step(_ months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { month = moved }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
