// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct HydrationEntry: TimelineEntry {
    var date: Date = Date()
    var waterML: Double = 0
    var waterGoalML: Double = 2000
    var calories: Double = 0
    var calorieGoal: Double = 2000
    var macros = MacroTotals()
    var carbsGoal: Double = 250
    var proteinGoal: Double = 100
    var fatGoal: Double = 65
    var unit: VolumeUnit = .millilitres
    var incrementML: Double = 250

    /// Floors at zero: past the goal there is nothing left to drink.
    var waterRemaining: Double { max(waterGoalML - waterML, 0) }
    var calorieRemaining: Double { calorieGoal - calories }

    static let placeholder = HydrationEntry(
        waterML: 1250,
        calories: 890,
        macros: MacroTotals(carbs: 121, sugar: 40, fiber: 8, protein: 62, fat: 27)
    )
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        Task { @MainActor in completion(currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        Task { @MainActor in
            let entry = currentEntry()
            // Refresh at the next midnight so both gauges reset with the new day.
            let midnight = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    @MainActor
    private func currentEntry() -> HydrationEntry {
        let context = SharedModelContainer.shared.mainContext
        let drinks = (try? context.fetch(HydrationStore.entriesDescriptor(on: Date()))) ?? []
        let food = (try? context.fetch(HydrationStore.foodDescriptor(on: Date()))) ?? []
        let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first

        return HydrationEntry(
            waterML: HydrationStore.total(of: drinks),
            waterGoalML: settings?.dailyGoalML ?? 2000,
            calories: HydrationStore.calories(of: food),
            calorieGoal: settings?.dailyCalorieGoal ?? 2000,
            macros: HydrationStore.macros(of: food),
            carbsGoal: settings?.macroGrams(.carbs) ?? 250,
            proteinGoal: settings?.macroGrams(.protein) ?? 100,
            fatGoal: settings?.macroGrams(.fat) ?? 65,
            unit: settings?.unit ?? .millilitres,
            incrementML: settings?.waterIncrementML ?? 250
        )
    }
}

struct HydroHomieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydroHomieWidget", provider: HydrationProvider()) { entry in
            HydroHomieWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hydration")
        .description("Today's water and calories, with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HydroHomieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HydrationEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 14) {
                gauge(diameter: 108, reclaim: 88, outer: 10, inner: 7)
                VStack(spacing: 10) {
                    MacroPanel(
                        totals: entry.macros,
                        carbsGoal: entry.carbsGoal,
                        proteinGoal: entry.proteinGoal,
                        fatGoal: entry.fatGoal,
                        metrics: .compact
                    )
                    actions
                }
            }
        default:
            VStack(spacing: 6) {
                gauge(diameter: 96, reclaim: 78, outer: 9, inner: 6)
                actions
            }
        }
    }

    /// The gauge's bottom gap leaves the lower part of its square empty, so the
    /// layout reports `reclaim` rather than the full `diameter`.
    private func gauge(
        diameter: CGFloat,
        reclaim: CGFloat,
        outer: CGFloat,
        inner: CGFloat
    ) -> some View {
        ZStack {
            DualProgressRing(
                calorieProgress: HydrationStore.progress(consumed: entry.calories, goal: entry.calorieGoal),
                waterProgress: HydrationStore.progress(consumed: entry.waterML, goal: entry.waterGoalML),
                outerLineWidth: outer,
                innerLineWidth: inner,
                ringSpacing: 4
            )
            RingCenterLabel(
                caption: "LEFT",
                calorieValue: entry.calorieRemaining,
                calorieTint: entry.calorieRemaining < 0 ? Color.over : Color.brand,
                waterMillilitres: entry.waterRemaining,
                waterTint: entry.waterRemaining > 0 ? Color.water : Color.goal,
                waterUnit: entry.unit,
                metrics: .compact,
                layout: .stacked
            )
            // Must clear both rings, not just the outer one.
            .padding(.horizontal, outer + inner + 6)
        }
        .frame(width: diameter, height: diameter)
        .frame(height: reclaim, alignment: .top)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(intent: AddDrinkIntent(amountML: entry.incrementML)) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            .tint(Color.water)

            Button(intent: TrackFoodIntent()) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            .tint(Color.brand)
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview(as: .systemSmall) {
    HydroHomieWidget()
} timeline: {
    HydrationEntry.placeholder
}

#Preview(as: .systemMedium) {
    HydroHomieWidget()
} timeline: {
    HydrationEntry.placeholder
}
