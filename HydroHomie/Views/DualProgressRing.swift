// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Two concentric progress rings: calories on the outside, water within. Both fill
/// clockwise from the top as you consume, and both keep going past 100% with a
/// thinner overflow arc — though the two overflows mean opposite things, so they are
/// tinted separately by the caller.
struct DualProgressRing: View {
    var calorieProgress: Double
    var waterProgress: Double

    var outerLineWidth: CGFloat = 22
    var innerLineWidth: CGFloat = 16
    var ringSpacing: CGFloat = 10

    var body: some View {
        ZStack {
            Ring(
                progress: calorieProgress,
                tint: .accentColor,
                track: .ringTrack,
                overflowTint: .over,
                lineWidth: outerLineWidth
            )
            Ring(
                progress: waterProgress,
                tint: .water,
                track: .waterTrack,
                overflowTint: .goal,
                lineWidth: innerLineWidth
            )
            .padding(outerLineWidth + ringSpacing)
        }
    }
}

/// One ring: a track, the filled arc, and an overflow arc once past the goal.
private struct Ring: View {
    var progress: Double
    var tint: Color
    var track: Color
    var overflowTint: Color
    var lineWidth: CGFloat

    private var clamped: Double { min(max(progress, 0), 1) }
    private var overflow: Double { min(max(progress - 1, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.7), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if overflow > 0 {
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(
                        overflowTint,
                        style: StrokeStyle(lineWidth: lineWidth / 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
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
