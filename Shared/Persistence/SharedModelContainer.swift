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
                for: DrinkEntry.self, UserSettings.self,
                configurations: configuration
            )
        } catch {
            // A corrupt or unreadable store shouldn't brick the app; start clean in memory.
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: DrinkEntry.self, UserSettings.self,
                configurations: fallback
            )
        }
    }()
}
