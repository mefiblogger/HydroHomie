// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The four ways to start logging a food, across the top of the track-food sheet.
///
/// Bordered rather than prominent: four solid accent blocks would outweigh the
/// search results they sit above, and these are entry points rather than the
/// primary action.
struct FoodSourceRow: View {
    var onScan: () -> Void
    var onPhoto: () -> Void
    var onDescribe: () -> Void
    var onManual: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            tile("barcode.viewfinder",
                 title: String(localized: "Scan barcode", comment: "Food source button"),
                 action: onScan)
            tile("camera.fill",
                 title: String(localized: "Take photo", comment: "Food source button"),
                 action: onPhoto)
            tile("text.bubble.fill",
                 title: String(localized: "Describe", comment: "Food source button"),
                 action: onDescribe)
            tile("square.and.pencil",
                 title: String(localized: "Add manually", comment: "Food source button"),
                 action: onManual)
        }
    }

    private func tile(_ systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 19, weight: .semibold))
                    // A fixed box: SwiftUI sizes a symbol to its own bounding box, and
                    // a barcode frame is far taller than a speech bubble, so without
                    // this the four tiles come out four different heights.
                    .frame(height: 22)
                Text(title)
                    .font(.caption2)
                    // Two lines for every tile whether it needs them or not, so the
                    // icons stay on one line across the row.
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(Color.brand)
    }
}

#Preview {
    VStack(spacing: 24) {
        FoodSourceRow(onScan: {}, onPhoto: {}, onDescribe: {}, onManual: {})
        FoodSourceRow(onScan: {}, onPhoto: {}, onDescribe: {}, onManual: {})
            .environment(\.locale, Locale(identifier: "hu"))
    }
    .padding()
}
