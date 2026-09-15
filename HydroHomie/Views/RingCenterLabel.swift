// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The readout inside the gauge: one caption over two columns — calories on the
/// left, water on the right — split by a dotted rule. Each column is tinted to
/// match its ring, which is what tells you which number belongs to which.
struct RingCenterLabel: View {
    var caption: String
    var calorieValue: Double
    var calorieTint: Color
    var waterMillilitres: Double
    var waterTint: Color
    var waterUnit: VolumeUnit

    var body: some View {
        VStack(spacing: 8) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                column(
                    value: "\(Int(calorieValue.rounded()))",
                    unit: "kcal",
                    tint: calorieTint
                )

                VerticalRule()
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .frame(width: 1, height: 42)

                column(
                    value: waterUnit.formatValue(millilitres: waterMillilitres),
                    unit: waterUnit.shortName,
                    tint: waterTint
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
        RingCenterLabel(
            caption: "REMAINING",
            calorieValue: 1360, calorieTint: .accentColor,
            waterMillilitres: 250, waterTint: .water,
            waterUnit: .millilitres
        )
        RingCenterLabel(
            caption: "SO FAR",
            calorieValue: 640, calorieTint: .accentColor,
            waterMillilitres: 1750, waterTint: .water,
            waterUnit: .millilitres
        )
    }
    .padding()
}
