// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.hydrohomie.app"

    /// Directory shared with the widget extension. Falls back to the target's own
    /// Application Support directory when the App Group entitlement isn't granted
    /// (e.g. an unsigned simulator build), so the app still runs rather than crashing.
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.applicationSupportDirectory
    }
}

/// The one `ModelContainer` used by both the app and the widget.
enum SharedModelContainer {
    static let shared: ModelContainer = {
        let storeURL = AppGroup.containerURL.appending(path: "HydroHomie.store")
        let configuration = ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(
                for: DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self,
                configurations: configuration
            )
        } catch {
            // A corrupt or unreadable store shouldn't brick the app; start clean in memory.
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self,
                configurations: fallback
            )
        }
    }()
}

extension AppGroup {
    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}

/// A request from the widget for the app to open a particular screen. The widget
/// cannot present UI itself, so anything needing a form hands over like this.
enum PendingAction: String {
    case trackFood

    private static let key = "pendingAction"

    static func request(_ action: PendingAction) {
        AppGroup.defaults?.set(action.rawValue, forKey: key)
    }

    /// Reads and clears in one go — a request is acted on once, not on every
    /// subsequent foregrounding.
    static func consume() -> PendingAction? {
        guard let raw = AppGroup.defaults?.string(forKey: key) else { return nil }
        AppGroup.defaults?.removeObject(forKey: key)
        return PendingAction(rawValue: raw)
    }
}
