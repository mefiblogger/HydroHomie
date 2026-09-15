// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Compact macro readout above the rings: three columns side by side, each a name,
/// a horizontal bar and a consumed/goal figure. Shares the buttons' corner radius so
/// the two blocks read as a set.
struct MacroPanel: View {
    var totals: MacroTotals
    var carbsGoal: Double
    var proteinGoal: Double
    var fatGoal: Double

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            column("Carbs", value: totals.carbs, goal: carbsGoal)
            column("Protein", value: totals.protein, goal: proteinGoal)
            column("Fat", value: totals.fat, goal: fatGoal)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }

    private func column(_ name: String, value: Double, goal: Double) -> some View {
        VStack(spacing: 5) {
            Text(name.uppercased())
                .font(.caption2.weight(.semibold))
                // Tracking keeps the caps from looking cramped, matching the
                // REMAINING caption inside the rings.
                .tracking(0.8)
                .foregroundStyle(.tertiary)

            bar(progress: HydrationStore.progress(consumed: value, goal: goal))

            Text("\(Int(value.rounded()))/\(Int(goal.rounded())) g")
                .font(.caption2.bold())
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
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 5)
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
