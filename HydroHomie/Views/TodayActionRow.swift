// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The three actions under the gauge: remove water, track food, add water.
/// Icon-only, so each button carries an accessibility label — there is no visible
/// text to fall back on. Long-pressing the add button opens the custom amount
/// sheet — the only way in, now that the standalone custom button is gone.
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
                icon("minus")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color.water)
            .disabled(!canRemove)
            .accessibilityLabel("Remove \(incrementLabel) of water")

            Button(action: onTrackFood) {
                icon("fork.knife")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color.brand)
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
                icon("plus", size: 17)
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

    /// Inherits the button style's foreground colour, so the glyph matches the
    /// weight the text labels had.
    ///
    /// `size` exists because a plus and a minus do not read as equal at the same
    /// point size: SF Symbols draws both on one grid, so the minus bar and the
    /// plus's horizontal arm are the same length, but the plus's vertical arm gives
    /// it extra mass. Taking a couple of points off the plus evens the pair up.
    private func icon(_ systemName: String, size: CGFloat = 20) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
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
