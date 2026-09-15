// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The three actions under the rings: remove water, track food, add water.
/// Long-pressing the add button opens the custom amount sheet — the only way in,
/// now that the standalone custom button is gone.
struct TodayActionRow: View {
    var unit: VolumeUnit
    var incrementML: Double
    var canRemove: Bool
    var onRemove: () -> Void
    var onTrackFood: () -> Void
    var onAdd: () -> Void
    var onCustomAmount: () -> Void

    /// A long press fires while the finger is still down, and the button's own action
    /// then fires on release — so the press is recorded and used to swallow that tap.
    @State private var didLongPress = false

    private var incrementLabel: String { unit.format(millilitres: incrementML) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRemove) {
                label("💧", "−\(incrementLabel)")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color.water)
            .disabled(!canRemove)
            .accessibilityLabel("Remove \(incrementLabel) of water")

            Button(action: onTrackFood) {
                label("🍔", "Track food")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color.accentColor)
            .accessibilityLabel("Track food")

            Button {
                // Swallow the tap that follows a long press, so holding opens the
                // sheet without also logging the increment.
                if didLongPress {
                    didLongPress = false
                } else {
                    onAdd()
                }
            } label: {
                label("💦", "+\(incrementLabel)")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color.water)
            // Tap adds the increment; press and hold to enter an exact amount.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    didLongPress = true
                    onCustomAmount()
                }
            )
            .accessibilityLabel("Add \(incrementLabel) of water")
            .accessibilityHint("Press and hold for a custom amount")
        }
    }

    private func label(_ emoji: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.title3)
            Text(text)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

#Preview {
    TodayActionRow(
        unit: .millilitres,
        incrementML: 250,
        canRemove: true,
        onRemove: {},
        onTrackFood: {},
        onAdd: {},
        onCustomAmount: {}
    )
    .padding()
}
