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
    @State private var showingFoodEntry = false

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

    // No NavigationStack: the screen carries no title or bar buttons, so a nav bar
    // would only cost vertical space.
    var body: some View {
        // Only the log scrolls — the gauge, macros and buttons are pinned, so the
        // controls stay reachable however long the day's log gets.
        VStack(spacing: 24) {
            rings
            MacroPanel(
                totals: HydrationStore.macros(of: todaysFood),
                carbsGoal: settings.dailyCarbsGoal,
                proteinGoal: settings.dailyProteinGoal,
                fatGoal: settings.dailyFatGoal
            )
            TodayActionRow(
                unit: unit,
                incrementML: settings.waterIncrementML,
                canRemove: !todaysDrinks.isEmpty,
                onRemove: removeLastWater,
                onTrackFood: { showingFoodEntry = true },
                onAdd: { add(settings.waterIncrementML) },
                onCustomAmount: { showingCustomAmount = true }
            )
            VStack(spacing: 14) {
                logHeader
                logList
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showingCustomAmount) {
            CustomAmountSheet(unit: unit) { amount in
                add(amount)
            }
        }
        .sheet(isPresented: $showingFoodEntry) {
            FoodEntrySheet()
        }
    }

    // MARK: - Rings

    private var rings: some View {
        ZStack {
            DualProgressRing(
                calorieProgress: HydrationStore.progress(consumed: calorieTotal, goal: calorieGoal),
                waterProgress: HydrationStore.progress(consumed: waterTotal, goal: waterGoal)
            )
            RingCenterLabel(
                calorieRemaining: calorieRemaining,
                waterRemaining: waterRemaining,
                waterUnit: unit
            )
            .padding(.horizontal, 54)
        }
        .frame(width: 260, height: 260)
        // The gauge's bottom gap leaves the lower ~46pt of that square empty,
        // so the layout reports a shorter height and the buttons move up.
        .frame(height: 214, alignment: .top)
    }

    // MARK: - Log

    /// A rule with the caption set into the middle of it.
    private var logHeader: some View {
        HStack(spacing: 10) {
            rule
            Text("TODAY SO FAR")
                .font(.caption2.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
                // Without this the text would be compressed before the rules are.
                .fixedSize()
            rule
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 2)
    }

    @ViewBuilder
    private var logList: some View {
        if log.isEmpty {
            ContentUnavailableView(
                "Nothing logged yet",
                systemImage: "drop",
                description: Text("Tap an amount above to start tracking today.")
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 12) {
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
                                detail: foodDetail(entry),
                                timestamp: entry.timestamp
                            ) {
                                HydrationLogger.delete(entry, context: context)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
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

    /// "540 kcal" on its own, or "120 g · 540 kcal" when a portion was recorded.
    private func foodDetail(_ entry: FoodEntry) -> String {
        let energy = "\(Int(entry.calories.rounded())) kcal"
        guard entry.portionGrams > 0 else { return energy }
        return "\(Int(entry.portionGrams.rounded())) g · \(energy)"
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
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
