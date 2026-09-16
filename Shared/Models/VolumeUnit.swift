// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Locale-aware rendering for the small quantities the app shows.
///
/// Grouping separators are suppressed throughout: a 2000 ml goal should read
/// "2000", not "2,000". Only the decimal separator is locale-dependent, which is
/// the part that is currently wrong under `String(format:)` — Hungarian writes
/// 25,4 where English writes 25.4.
enum Quantity {
    /// The locale every rendered number uses. Overridable only so tests do not depend
    /// on the region the host machine or simulator happens to be set to.
    static var locale: Locale = .autoupdatingCurrent

    /// Whole values lose the decimal part; everything else keeps one digit.
    static func text(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 0.0001 ? whole(value) : oneDecimal(value)
    }

    /// Always one decimal place — nutrient grams, fluid ounces.
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(locale))
    }

    /// Rounded to a whole number.
    static func whole(_ value: Double) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)).grouping(.never).locale(locale))
    }
}

/// Display unit for volumes. Everything is stored in millilitres internally and
/// converted only at the presentation layer, so switching units never mutates data.
enum VolumeUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case millilitres
    case fluidOunces

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .millilitres: String(localized: "ml", comment: "Millilitres, abbreviated")
        case .fluidOunces: String(localized: "fl oz", comment: "Fluid ounces, abbreviated")
        }
    }

    var displayName: String {
        switch self {
        case .millilitres: String(localized: "Millilitres (ml)", comment: "Volume unit choice")
        case .fluidOunces: String(localized: "Fluid ounces (fl oz)", comment: "Volume unit choice")
        }
    }

    /// US customary fluid ounce.
    static let millilitresPerFluidOunce = 29.5735295625

    func fromMillilitres(_ ml: Double) -> Double {
        switch self {
        case .millilitres: ml
        case .fluidOunces: ml / Self.millilitresPerFluidOunce
        }
    }

    func toMillilitres(_ value: Double) -> Double {
        switch self {
        case .millilitres: value
        case .fluidOunces: value * Self.millilitresPerFluidOunce
        }
    }

    /// Just the number in this unit, e.g. `750` or `25.4` — for layouts that place
    /// the unit separately.
    func formatValue(millilitres ml: Double) -> String {
        let value = fromMillilitres(ml)
        switch self {
        case .millilitres:
            return Quantity.whole(value)
        case .fluidOunces:
            return Quantity.oneDecimal(value)
        }
    }

    /// Formats a millilitre amount in this unit, e.g. `750 ml` or `25.4 fl oz`.
    func format(millilitres ml: Double) -> String {
        String(localized: "amount.with-unit",
               defaultValue: "\(formatValue(millilitres: ml)) \(shortName)",
               comment: "An amount followed by its unit symbol, e.g. 750 ml or 150 g")
    }

    /// The quick-add amounts offered on the Today screen, in millilitres.
    var presetAmountsML: [Double] {
        switch self {
        case .millilitres: [250, 500, 750]
        case .fluidOunces: [236.588, 473.176, 709.765]  // 8, 16, 24 fl oz
        }
    }
}
