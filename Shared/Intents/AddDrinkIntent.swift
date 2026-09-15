// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Backs the quick-add buttons on the widget. Runs in the widget extension's process,
/// writes to the shared store, then asks WidgetKit to refresh.
struct AddDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Adds a drink to today's total.")
    /// Keeps the tap inline on the widget instead of launching the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount (ml)")
    var amountML: Double

    init() {
        self.amountML = 250
    }

    init(amountML: Double) {
        self.amountML = amountML
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedModelContainer.shared.mainContext
        context.insert(DrinkEntry(amountML: amountML, source: .widget))
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Opens the app on the food sheet. Logging food needs a form — a name, a portion —
/// so unlike adding water it cannot be completed inline on the widget.
struct TrackFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Track Food"
    static var description = IntentDescription("Opens HydroHomie to log some food.")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingAction.request(.trackFood)
        return .result()
    }
}
