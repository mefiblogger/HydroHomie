// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The readout inside the gauge: one caption over two columns — calories on the
/// left, water on the right — split by a dotted rule. Each column is tinted to
/// match its ring, which is what tells you which number belongs to which.
struct RingCenterLabel: View {
    /// Type and spacing, so the same readout can serve a 260pt gauge in the app and
    /// a thumbnail-sized one in the widget without a second implementation.
    struct Metrics {
        var numberSize: CGFloat = 24
        var captionFont: Font = .caption2.weight(.semibold)
        var captionTracking: CGFloat = 1.4
        var unitFont: Font = .caption
        var ruleHeight: CGFloat = 42
        var stackSpacing: CGFloat = 8
        var columnSpacing: CGFloat = 14
        var minColumnWidth: CGFloat = 54

        static let standard = Metrics()
        /// Sized for a widget gauge, where the readable area inside the rings is
        /// only about 55pt across.
        static let compact = Metrics(
            numberSize: 14,
            captionFont: .system(size: 8, weight: .semibold),
            captionTracking: 0.6,
            unitFont: .system(size: 9),
            ruleHeight: 0,
            stackSpacing: 1,
            columnSpacing: 0,
            minColumnWidth: 0
        )
    }

    /// Side-by-side columns need roughly 120pt of clear space inside the rings. A
    /// widget-sized gauge has about half that, so it stacks the two readings instead.
    enum Layout {
        case columns
        case stacked
    }

    var caption: String
    var calorieValue: Double
    var calorieTint: Color
    var waterMillilitres: Double
    var waterTint: Color
    var waterUnit: VolumeUnit
    var metrics: Metrics = .standard
    var layout: Layout = .columns

    private var calorieText: String { "\(Int(calorieValue.rounded()))" }
    private var waterText: String { waterUnit.formatValue(millilitres: waterMillilitres) }

    var body: some View {
        VStack(spacing: metrics.stackSpacing) {
            Text(caption)
                .font(metrics.captionFont)
                .tracking(metrics.captionTracking)
                .foregroundStyle(.secondary)

            switch layout {
            case .columns:
                HStack(spacing: metrics.columnSpacing) {
                    column(value: calorieText, unit: "kcal", tint: calorieTint)

                    VerticalRule()
                        .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: 1, height: metrics.ruleHeight)

                    column(value: waterText, unit: waterUnit.shortName, tint: waterTint)
                }
            case .stacked:
                line(value: calorieText, unit: "kcal", tint: calorieTint)
                line(value: waterText, unit: waterUnit.shortName, tint: waterTint)
            }
        }
    }

    /// One reading on a single line, for the stacked layout.
    private func line(value: String, unit: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: metrics.numberSize, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(unit)
                .font(metrics.unitFont)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private func column(value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: metrics.numberSize, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(unit)
                .font(metrics.unitFont)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: metrics.minColumnWidth)
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
            calorieValue: 1360, calorieTint: .brand,
            waterMillilitres: 250, waterTint: .water,
            waterUnit: .millilitres
        )
        RingCenterLabel(
            caption: "SO FAR",
            calorieValue: 640, calorieTint: .brand,
            waterMillilitres: 1750, waterTint: .water,
            waterUnit: .millilitres
        )
    }
    .padding()
}
