// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFood: [FoodEntry]
    @Query private var settingsRows: [UserSettings]

    @State private var showingCustomAmount = false

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }
    private var unit: VolumeUnit { settings.unit }

    // Filtering in the view rather than in the query keeps "today" correct across
    // midnight without having to rebuild the predicate.
    private var todaysDrinks: [DrinkEntry] {
        allDrinks.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var todaysFood: [FoodEntry] {
        allFood.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var waterTotal: Double { HydrationStore.total(of: todaysDrinks) }
    private var calorieTotal: Double { HydrationStore.calories(of: todaysFood) }

    private var waterGoal: Double { max(settings.dailyGoalML, 1) }
    private var calorieGoal: Double { max(settings.dailyCalorieGoal, 1) }

    private var waterRemaining: Double {
        HydrationStore.remaining(goal: waterGoal, consumed: waterTotal)
    }
    private var calorieRemaining: Double {
        HydrationStore.remaining(goal: calorieGoal, consumed: calorieTotal)
    }

    private var log: [LogItem] {
        HydrationStore.mergedLog(water: todaysDrinks, food: todaysFood)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    rings
                    TodayActionRow(
                        unit: unit,
                        incrementML: settings.waterIncrementML,
                        canRemove: !todaysDrinks.isEmpty,
                        onRemove: removeLastWater,
                        onTrackFood: {},          // Food entry is not designed yet.
                        onAdd: { add(settings.waterIncrementML) },
                        onCustomAmount: { showingCustomAmount = true }
                    )
                    todaysLog
                }
                .padding()
            }
            .navigationTitle("Today")
            .sheet(isPresented: $showingCustomAmount) {
                CustomAmountSheet(unit: unit) { amount in
                    add(amount)
                }
            }
        }
    }

    // MARK: - Rings

    private var rings: some View {
        ZStack {
            DualProgressRing(
                calorieProgress: HydrationStore.progress(consumed: calorieTotal, goal: calorieGoal),
                waterProgress: HydrationStore.progress(consumed: waterTotal, goal: waterGoal)
            )
            VStack(spacing: 6) {
                Text(calorieLabel)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(calorieRemaining < 0 ? Color.over : Color.accentColor)
                    .contentTransition(.numericText())
                Text(waterLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(waterRemaining > 0 ? Color.water : Color.goal)
                    .contentTransition(.numericText())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 64)
        }
        .frame(width: 260, height: 260)
        .padding(.top, 12)
    }

    private var calorieLabel: String {
        calorieRemaining >= 0
            ? "\(Int(calorieRemaining.rounded())) kcal left"
            : "\(Int((-calorieRemaining).rounded())) kcal over"
    }

    private var waterLabel: String {
        waterRemaining > 0
            ? "\(unit.format(millilitres: waterRemaining)) left"
            : "Goal reached"
    }

    // MARK: - Log

    @ViewBuilder
    private var todaysLog: some View {
        if log.isEmpty {
            ContentUnavailableView(
                "Nothing logged yet",
                systemImage: "drop",
                description: Text("Tap an amount above to start tracking today.")
            )
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's log")
                    .font(.headline)
                ForEach(log) { item in
                    switch item {
                    case .water(let entry):
                        row(
                            icon: "drop.fill",
                            tint: .water,
                            title: "\(unit.format(millilitres: entry.amountML)) water",
                            detail: nil,
                            timestamp: entry.timestamp
                        ) {
                            HydrationLogger.delete(entry, context: context)
                        }
                    case .food(let entry):
                        row(
                            icon: "fork.knife",
                            tint: .accentColor,
                            title: entry.name,
                            detail: "\(Int(entry.calories.rounded())) kcal",
                            timestamp: entry.timestamp
                        ) {
                            HydrationLogger.delete(entry, context: context)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(
        icon: String,
        tint: Color,
        title: String,
        detail: String?,
        timestamp: Date,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(timestamp, style: .time)
                .foregroundStyle(.secondary)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete entry")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: - Actions

    private func add(_ amountML: Double) {
        HydrationLogger.add(amountML: amountML, settings: settings, context: context)
    }

    private func removeLastWater() {
        HydrationLogger.undoLastWater(from: todaysDrinks, context: context)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, UserSettings.self], inMemory: true)
}
