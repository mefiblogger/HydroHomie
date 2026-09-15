// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// The six nutrients tracked, as an absolute amount for some quantity of food.
/// Sugar and fibre are subsets of carbohydrate, not siblings of it — do not add
/// the three together.
struct Nutrients: Equatable, Sendable {
    var energyKcal: Double = 0
    var carbs: Double = 0
    var sugar: Double = 0
    var fiber: Double = 0
    var protein: Double = 0
    var fat: Double = 0

    /// These values describe 100 g; return the same nutrients for `grams` instead.
    func scaled(toGrams grams: Double) -> Nutrients {
        let factor = grams / 100
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

/// A named way to measure a food, defined per food: a grape's "piece" is 2 g, a
/// cola's "can" is 330 g. Logging then happens in whichever unit is natural.
enum PortionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case serving
    case piece
    case each
    case can
    case bottle

    var id: String { rawValue }

    var singular: String { rawValue }

    var plural: String {
        switch self {
        case .serving: "servings"
        case .piece: "pieces"
        case .each: "each"
        case .can: "cans"
        case .bottle: "bottles"
        }
    }

    /// "1 piece", "10 pieces", "3 each".
    func label(count: Double) -> String {
        let rounded = count.rounded()
        let quantity = abs(count - rounded) < 0.0001
            ? String(Int(rounded))
            : String(format: "%.1f", count)
        return "\(quantity) \(abs(count - 1) < 0.0001 ? singular : plural)"
    }
}

struct NamedPortion: Codable, Hashable, Sendable, Identifiable {
    var kind: PortionKind
    var grams: Double

    var id: String { kind.rawValue }
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
        case .meal: "Meal"
        case .burger: "Burger"
        case .takeaway: "Takeaway"
        case .pasta: "Pasta"
        case .noodles: "Noodles"
        case .candy: "Candy"
        case .chocolate: "Chocolate"
        case .vegetable: "Vegetable"
        case .fruit: "Fruit"
        case .chips: "Chips"
        case .softDrink: "Soft drink"
        case .milk: "Milk"
        case .coffee: "Coffee"
        case .tea: "Tea"
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

    /// Offered as the portion when logging this food again.
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
        defaultPortionGrams: Double = 100,
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
        self.defaultPortionGrams = defaultPortionGrams
        self.portions = portions
        self.icon = icon.rawValue
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.barcode = barcode
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

    func nutrients(forGrams grams: Double) -> Nutrients {
        per100g.scaled(toGrams: grams)
    }

    /// Weight of one of `kind`, or nil when this food does not define that measure.
    func grams(for kind: PortionKind) -> Double? {
        portions.first { $0.kind == kind }?.grams
    }

    /// Total weight of `count` of `kind`, e.g. 10 grapes at 2 g each.
    func grams(count: Double, of kind: PortionKind) -> Double? {
        grams(for: kind).map { $0 * count }
    }
}
