// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension Color {
    /// The app tint, looked up by name rather than via `Color.accentColor`: inside a
    /// widget extension the latter resolves to the system tint, which turned every
    /// purple in the widget blue.
    static let brand = Color("AccentColor")

    /// Unfilled portion of the progress ring — a translucent tint of the accent that
    /// stays visible against both light and dark grounds.
    static let ringTrack = Color("RingTrack")

    /// Marks intake at or beyond the daily goal.
    static let goal = Color("GoalColor")

    /// Water-specific tint — a hue-rotated sibling of the accent purple.
    static let water = Color("WaterColor")

    /// Unfilled track of the inner water ring.
    static let waterTrack = Color("WaterTrack")

    /// Marks consumption past a budget that should not be exceeded, e.g. calories.
    static let over = Color("OverColor")
}

/// Appearance preference exposed in Settings. `system` defers to the device setting.
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System", comment: "Appearance follows the device setting")
        case .light: String(localized: "Light", comment: "Light appearance")
        case .dark: String(localized: "Dark", comment: "Dark appearance")
        }
    }

    /// `nil` lets SwiftUI follow the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
