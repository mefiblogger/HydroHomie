// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Compact macro readout above the rings: one row per macro, each a label, a
/// horizontal bar and a consumed/goal figure. Shares the buttons' corner radius so
/// the two blocks read as a set.
struct MacroPanel: View {
    var totals: MacroTotals
    var carbsGoal: Double
    var proteinGoal: Double
    var fatGoal: Double

    var body: some View {
        VStack(spacing: 7) {
            row("Carbs", value: totals.carbs, goal: carbsGoal)
            row("Protein", value: totals.protein, goal: proteinGoal)
            row("Fat", value: totals.fat, goal: fatGoal)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }

    private func row(_ name: String, value: Double, goal: Double) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            bar(progress: HydrationStore.progress(consumed: value, goal: goal))

            Text("\(Int(value.rounded()))/\(Int(goal.rounded())) g")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .trailing)
        }
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
            totals: MacroTotals(carbs: 180, protein: 74, fat: 52),
            carbsGoal: 250, proteinGoal: 100, fatGoal: 65
        )
    }
    .padding()
}
