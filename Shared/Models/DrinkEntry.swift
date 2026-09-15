// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// A single logged drink. Amounts are always millilitres.
@Model
final class DrinkEntry {
    var id: UUID = UUID()
    var amountML: Double = 0
    var timestamp: Date = Date()
    /// Where the entry came from — `app`, `widget`, or `health`.
    var source: String = DrinkSource.app.rawValue
    /// Identifier of the matching Apple Health sample, when one was written, so
    /// deleting this entry can retract it from Health too.
    var healthKitSampleID: UUID?

    init(amountML: Double, timestamp: Date = Date(), source: DrinkSource = .app) {
        self.id = UUID()
        self.amountML = amountML
        self.timestamp = timestamp
        self.source = source.rawValue
    }
}

enum DrinkSource: String, Codable, Sendable {
    case app
    case widget
    case health
}
