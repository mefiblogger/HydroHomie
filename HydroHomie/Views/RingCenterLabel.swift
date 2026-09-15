// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The readout inside the rings: one "REMAINING" caption over two columns —
/// calories on the left, water on the right — split by a dotted rule. Each column
/// is tinted to match its ring, which is what tells you which number belongs to which.
struct RingCenterLabel: View {
    var calorieRemaining: Double
    var waterRemaining: Double
    var waterUnit: VolumeUnit

    var body: some View {
        VStack(spacing: 8) {
            Text("REMAINING")
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                column(
                    value: "\(Int(calorieRemaining.rounded()))",
                    unit: "kcal",
                    tint: calorieRemaining < 0 ? .over : .accentColor
                )

                VerticalRule()
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .frame(width: 1, height: 42)

                column(
                    // Past the goal there is nothing left to drink, so this floors at
                    // zero rather than showing a negative.
                    value: waterUnit.formatValue(millilitres: max(waterRemaining, 0)),
                    unit: waterUnit.shortName,
                    tint: waterRemaining > 0 ? .water : .goal
                )
            }
        }
    }

    private func column(value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 54)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// A plain vertical line, so it can be stroked with a dash pattern — `Divider`
/// cannot be dotted.
private struct VerticalRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        RingCenterLabel(calorieRemaining: 2000, waterRemaining: 250, waterUnit: .millilitres)
        RingCenterLabel(calorieRemaining: -320, waterRemaining: 0, waterUnit: .millilitres)
        RingCenterLabel(calorieRemaining: 1450, waterRemaining: 740, waterUnit: .fluidOunces)
    }
    .padding()
}
