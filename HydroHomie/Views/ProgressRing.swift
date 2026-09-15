// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Circular progress indicator for the day's intake. Fills clockwise from the top and
/// keeps filling past 100% with a lighter overflow arc.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 22

    private var clamped: Double { min(progress, 1) }
    private var overflow: Double { min(max(progress - 1, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.7), Color.accentColor],
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
                        Color.goal,
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
        ProgressRing(progress: 0.45).frame(width: 160, height: 160)
        ProgressRing(progress: 1.3).frame(width: 160, height: 160)
    }
    .padding()
}
