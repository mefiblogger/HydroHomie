// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// The six nutrients tracked, as an absolute amount for some quantity of food.
/// Sugar and fibre are subsets of carbohydrate, not siblings of it — do not add
/// the three together.
struct Nutrients: Hashable, Sendable {
    var energyKcal: Double = 0
    var carbs: Double = 0
    var sugar: Double = 0
    var fiber: Double = 0
    var protein: Double = 0
    var fat: Double = 0

    /// These values describe 100 g or 100 ml of a food; return them for `amount` of
    /// it instead. Which unit it is lives on the food, not here.
    func scaled(to amount: Double) -> Nutrients {
        let factor = amount / 100
        return Nutrients(
            energyKcal: energyKcal * factor,
            carbs: carbs * factor,
            sugar: sugar * factor,
            fiber: fiber * factor,
            protein: protein * factor,
            fat: fat * factor
        )
    }
}

/// Whether a food is measured by weight or by volume. Labels give nutrition per
/// 100 g for solids and per 100 ml for liquids; the arithmetic is identical, so this
/// only decides what the figures are called and which portions make sense.
enum FoodMeasure: String, Codable, CaseIterable, Identifiable, Sendable {
    case grams
    case millilitres

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .grams: String(localized: "g", comment: "Grams, abbreviated")
        case .millilitres: String(localized: "ml", comment: "Millilitres, abbreviated")
        }
    }

    var displayName: String {
        switch self {
        case .grams: String(localized: "Grams", comment: "Food is measured by weight")
        case .millilitres: String(localized: "Millilitres", comment: "Food is measured by volume")
        }
    }

    /// You do not eat a piece of juice, and you do not drink a bowl of rice.
    var portionKinds: [PortionKind] {
        switch self {
        case .grams: [.serving, .piece, .each, .can, .bottle]
        case .millilitres: [.serving, .can, .bottle, .glass, .bowl]
        }
    }
}

/// A named way to measure a food, defined per food: a grape's "piece" is 2 g, a
/// cola's "can" is 330 ml. Logging then happens in whichever unit is natural.
enum PortionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case serving
    case piece
    case each
    case can
    case bottle
    case glass
    case bowl

    var id: String { rawValue }

    /// Display text for one of these. `rawValue` stays the persistence key and must
    /// never be localised — it is stored in `FoodEntry.portionKindRaw` and inside
    /// `NamedPortion`, so it has to mean the same thing in every language.
    var singular: String {
        switch self {
        case .serving: String(localized: "serving", comment: "One portion measure")
        case .piece: String(localized: "piece", comment: "One portion measure")
        case .each: String(localized: "each", comment: "One portion measure")
        case .can: String(localized: "can", comment: "One portion measure, a drinks can")
        case .bottle: String(localized: "bottle", comment: "One portion measure")
        case .glass: String(localized: "glass", comment: "One portion measure")
        case .bowl: String(localized: "bowl", comment: "One portion measure")
        }
    }

    /// The form used after any count other than one. Languages that keep the noun
    /// singular after a numeral — Hungarian says "10 darab", not "darabok" — simply
    /// translate this to the same word as `singular`.
    var plural: String {
        switch self {
        case .serving: String(localized: "servings", comment: "Portion measure, more than one")
        case .piece: String(localized: "pieces", comment: "Portion measure, more than one")
        case .each: String(localized: "each (plural)", defaultValue: "each",
                           comment: "Portion measure, more than one")
        case .can: String(localized: "cans", comment: "Portion measure, more than one")
        case .bottle: String(localized: "bottles", comment: "Portion measure, more than one")
        case .glass: String(localized: "glasses", comment: "Portion measure, more than one")
        case .bowl: String(localized: "bowls", comment: "Portion measure, more than one")
        }
    }

    /// "1 piece", "10 pieces", "3 each".
    func label(count: Double) -> String {
        let noun = abs(count - 1) < 0.0001 ? singular : plural
        return String(localized: "portion.count-and-measure",
                      defaultValue: "\(Quantity.text(count)) \(noun)",
                      comment: "A count followed by its portion measure, e.g. 10 pieces")
    }
}

struct NamedPortion: Codable, Hashable, Sendable, Identifiable {
    var kind: PortionKind
    /// The size of one, in the food's own measure — grams or millilitres.
    var amount: Double

    var id: String { kind.rawValue }

    /// Stored as "grams" historically; the key is kept so existing rows still decode.
    private enum CodingKeys: String, CodingKey {
        case kind
        case amount = "grams"
    }
}

/// The icon shown against a food in the log and the library.
///
/// Emoji rather than SF Symbols: the symbol library carries only fourteen food and
/// drink glyphs, mostly vessels, and exactly one of the categories worth offering
/// here has an honest match (carrot). Emoji cannot be tinted — they render from a
/// bitmap colour font — which is the trade for the coverage.
enum FoodIcon: String, CaseIterable, Identifiable, Sendable {
    case meal = "\u{1F37D}\u{FE0F}"
    case burger = "\u{1F354}"
    case takeaway = "\u{1F961}"
    case pasta = "\u{1F35D}"
    case noodles = "\u{1F35C}"
    case candy = "\u{1F36C}"
    case chocolate = "\u{1F36B}"
    case vegetable = "\u{1F955}"
    case fruit = "\u{1F34E}"
    case chips = "\u{1F35F}"
    case softDrink = "\u{1F964}"
    case milk = "\u{1F95B}"
    case coffee = "\u{2615}"
    case tea = "\u{1F375}"

    var id: String { rawValue }

    static let `default` = FoodIcon.meal

    /// Spoken by VoiceOver in the picker, where a bare glyph is a poor target.
    var name: String {
        switch self {
        case .meal: String(localized: "Meal", comment: "Food icon")
        case .burger: String(localized: "Burger", comment: "Food icon")
        case .takeaway: String(localized: "Takeaway", comment: "Food icon")
        case .pasta: String(localized: "Pasta", comment: "Food icon")
        case .noodles: String(localized: "Noodles", comment: "Food icon")
        case .candy: String(localized: "Candy", comment: "Food icon")
        case .chocolate: String(localized: "Chocolate", comment: "Food icon")
        case .vegetable: String(localized: "Vegetable", comment: "Food icon")
        case .fruit: String(localized: "Fruit", comment: "Food icon")
        case .chips: String(localized: "Chips", comment: "Food icon, fries or crisps")
        case .softDrink: String(localized: "Soft drink", comment: "Food icon")
        case .milk: String(localized: "Milk", comment: "Food icon")
        case .coffee: String(localized: "Coffee", comment: "Food icon")
        case .tea: String(localized: "Tea", comment: "Food icon")
        }
    }
}

/// Icons for log entries that are not user-chosen.
enum LogIcon {
    static let water = "\u{1F4A7}"
}

/// A reusable food definition in the user's own library.
///
/// Everything is held per 100 g, which is how both USDA FoodData Central and Open
/// Food Facts report nutrition — so a lookup against either can populate one of
/// these without any conversion.
@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""

    var energyKcal: Double = 0
    var carbsGrams: Double = 0
    var sugarGrams: Double = 0
    var fiberGrams: Double = 0
    var proteinGrams: Double = 0
    var fatGrams: Double = 0

    var measureRawValue: String = FoodMeasure.grams.rawValue
    /// Offered as the portion when logging this food again, in the food's measure.
    /// Named for grams historically; the column is left alone deliberately.
    var defaultPortionGrams: Double = 100
    var createdAt: Date = Date()
    /// Drives the ordering of the library, so what you eat often stays at the top.
    var lastUsedAt: Date = Date()
    /// Set when an item came from a barcode. Unused until a lookup source lands.
    var barcode: String?
    /// Named measures for this food, each giving the weight of one of them.
    var portions: [NamedPortion] = []
    var icon: String = FoodIcon.default.rawValue

    init(
        name: String,
        per100g: Nutrients,
        measure: FoodMeasure = .grams,
        defaultPortionAmount: Double = 100,
        portions: [NamedPortion] = [],
        icon: FoodIcon = .default,
        barcode: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.energyKcal = per100g.energyKcal
        self.carbsGrams = per100g.carbs
        self.sugarGrams = per100g.sugar
        self.fiberGrams = per100g.fiber
        self.proteinGrams = per100g.protein
        self.fatGrams = per100g.fat
        self.measureRawValue = measure.rawValue
        self.defaultPortionGrams = defaultPortionAmount
        self.portions = portions
        self.icon = icon.rawValue
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.barcode = barcode
    }

    var measure: FoodMeasure {
        get { FoodMeasure(rawValue: measureRawValue) ?? .grams }
        set { measureRawValue = newValue.rawValue }
    }

    /// Reads honestly at the call site: grams or millilitres, per `measure`.
    var defaultPortionAmount: Double {
        get { defaultPortionGrams }
        set { defaultPortionGrams = newValue }
    }

    /// Named measures this food defines, in the order the picker offers them.
    var availablePortions: [NamedPortion] {
        measure.portionKinds.compactMap { kind in
            portions.first { $0.kind == kind }
        }
    }

    var per100g: Nutrients {
        Nutrients(
            energyKcal: energyKcal,
            carbs: carbsGrams,
            sugar: sugarGrams,
            fiber: fiberGrams,
            protein: proteinGrams,
            fat: fatGrams
        )
    }

    func nutrients(forAmount amount: Double) -> Nutrients {
        per100g.scaled(to: amount)
    }

    /// Size of one of `kind`, or nil when this food does not define that measure.
    func amount(for kind: PortionKind) -> Double? {
        portions.first { $0.kind == kind }?.amount
    }

    /// Total size of `count` of `kind`, e.g. 10 grapes at 2 g each.
    func amount(count: Double, of kind: PortionKind) -> Double? {
        amount(for: kind).map { $0 * count }
    }
}
