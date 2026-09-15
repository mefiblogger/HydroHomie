// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Compact macro readout between the gauge and the buttons: three columns side by
/// side, each a name,
/// a horizontal bar and a consumed/goal figure. Shares the buttons' corner radius so
/// the two blocks read as a set.
struct MacroPanel: View {
    /// Type, spacing and chrome, so the widget can render the same panel small and
    /// without its own background.
    struct Metrics {
        var nameFont: Font = .caption2.weight(.semibold)
        var nameTracking: CGFloat = 0.8
        var valueFont: Font = .caption2.bold()
        var barHeight: CGFloat = 5
        var columnSpacing: CGFloat = 14
        var rowSpacing: CGFloat = 5
        var verticalPadding: CGFloat = 12
        var horizontalPadding: CGFloat = 14
        var hasBackground: Bool = true

        static let standard = Metrics()
        static let compact = Metrics(
            nameFont: .system(size: 8, weight: .semibold),
            nameTracking: 0.4,
            valueFont: .system(size: 9, weight: .bold),
            barHeight: 4,
            columnSpacing: 10,
            rowSpacing: 3,
            verticalPadding: 0,
            horizontalPadding: 0,
            hasBackground: false
        )
    }

    var totals: MacroTotals
    var carbsGoal: Double
    var proteinGoal: Double
    var fatGoal: Double
    var metrics: Metrics = .standard

    var body: some View {
        HStack(alignment: .top, spacing: metrics.columnSpacing) {
            column("Carbs", value: totals.carbs, goal: carbsGoal)
            column("Protein", value: totals.protein, goal: proteinGoal)
            column("Fat", value: totals.fat, goal: fatGoal)
        }
        .padding(.vertical, metrics.verticalPadding)
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(maxWidth: .infinity)
        .background {
            if metrics.hasBackground {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            }
        }
    }

    private func column(_ name: String, value: Double, goal: Double) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            Text(name.uppercased())
                .font(metrics.nameFont)
                // Tracking keeps the caps from looking cramped, matching the
                // REMAINING caption inside the rings.
                .tracking(metrics.nameTracking)
                .foregroundStyle(.tertiary)

            bar(progress: HydrationStore.progress(consumed: value, goal: goal))

            Text("\(Int(value.rounded()))/\(Int(goal.rounded())) g")
                .font(metrics.valueFont)
                .monospacedDigit()
                // The figure outranks its label, so it takes the stronger tone.
                .foregroundStyle(.secondary)
        }
        // Equal widths regardless of how long the name or the figures are.
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func bar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.ringTrack)
                Capsule()
                    .fill(Color.brand)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: metrics.barHeight)
    }
}

#Preview {
    VStack(spacing: 20) {
        MacroPanel(
            totals: MacroTotals(),
            carbsGoal: 250, proteinGoal: 100, fatGoal: 65
        )
        MacroPanel(
            totals: MacroTotals(carbs: 180, protein: 74, fat: 65),
            carbsGoal: 250, proteinGoal: 100, fatGoal: 65
        )
    }
    .padding()
}
