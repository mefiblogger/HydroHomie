// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Two concentric gauges: calories on the outside, water within. Each is an arc with
/// a gap at the bottom rather than a closed circle, sweeping clockwise as you consume,
/// and each keeps going past 100% with a thinner overflow arc — though the two
/// overflows mean opposite things, so they are tinted separately by the caller.
struct DualProgressRing: View {
    var calorieProgress: Double
    var waterProgress: Double

    var outerLineWidth: CGFloat = 22
    var innerLineWidth: CGFloat = 16
    var ringSpacing: CGFloat = 10
    /// How much of the circle the gauge covers, in degrees. The remainder is the gap
    /// at the bottom.
    var sweepDegrees: Double = 240

    var body: some View {
        ZStack {
            Ring(
                progress: calorieProgress,
                tint: .brand,
                track: .ringTrack,
                overflowTint: .over,
                lineWidth: outerLineWidth,
                sweepDegrees: sweepDegrees
            )
            Ring(
                progress: waterProgress,
                tint: .water,
                track: .waterTrack,
                overflowTint: .goal,
                lineWidth: innerLineWidth,
                sweepDegrees: sweepDegrees
            )
            .padding(outerLineWidth + ringSpacing)
        }
    }
}

/// One gauge: a track arc, the filled arc, and an overflow arc once past the goal.
private struct Ring: View {
    var progress: Double
    var tint: Color
    var track: Color
    var overflowTint: Color
    var lineWidth: CGFloat
    var sweepDegrees: Double

    private var clamped: Double { min(max(progress, 0), 1) }
    private var overflow: Double { min(max(progress - 1, 0), 1) }

    /// Fraction of the full circle the gauge occupies, so progress can be scaled
    /// into it: a half-full gauge fills half of the sweep, not half of the circle.
    private var sweep: Double { sweepDegrees / 360 }

    /// `trim` starts at 3 o'clock and runs clockwise. Rotating by the gap's half
    /// width past 6 o'clock puts the opening centred on the bottom.
    private var startAngle: Angle { .degrees(90 + 180 * (1 - sweep)) }

    var body: some View {
        ZStack {
            arc(to: sweep)
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            arc(to: clamped * sweep)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.7), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            if overflow > 0 {
                arc(to: overflow * sweep)
                    .stroke(
                        overflowTint,
                        style: StrokeStyle(lineWidth: lineWidth / 2.5, lineCap: .round)
                    )
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }

    private func arc(to end: Double) -> some Shape {
        Circle()
            .trim(from: 0, to: end)
            .rotation(startAngle)
    }
}

#Preview {
    VStack(spacing: 40) {
        DualProgressRing(calorieProgress: 0.4, waterProgress: 0.75)
            .frame(width: 260, height: 260)
        DualProgressRing(calorieProgress: 1.2, waterProgress: 1.1)
            .frame(width: 260, height: 260)
    }
    .padding()
}
