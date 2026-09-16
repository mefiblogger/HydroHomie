// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One food from the bundled generic catalogue. Read-only: nothing here is stored,
/// it is copied into the user's own library the moment they log it.
struct CatalogFood: Decodable, Identifiable, Hashable {
    /// Every name this food is known by, keyed by language code; always has "en".
    ///
    /// Only English is populated today. Translating the catalogue later means adding
    /// keys to the JSON — no Swift changes, which is the point of storing it this way.
    let names: [String: String]
    let nutrients: Nutrients

    /// The English name. Stable across languages, so it works as identity and as the
    /// fallback when a translation is missing.
    var key: String { names["en"] ?? "" }

    /// The name in the user's language, falling back to English.
    var name: String { CatalogFood.preferred(from: names) }

    var id: String { key }

    private enum CodingKeys: String, CodingKey {
        case name = "n", kcal, carb, sugar, fiber, prot, fat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A bare string is the original single-language shape, still accepted so a
        // catalogue rebuild is never required to read an older bundle.
        if let plain = try? c.decode(String.self, forKey: .name) {
            names = ["en": plain]
        } else {
            names = try c.decode([String: String].self, forKey: .name)
        }
        nutrients = Nutrients(
            energyKcal: try c.decodeIfPresent(Double.self, forKey: .kcal) ?? 0,
            carbs: try c.decodeIfPresent(Double.self, forKey: .carb) ?? 0,
            sugar: try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0,
            fiber: try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0,
            protein: try c.decodeIfPresent(Double.self, forKey: .prot) ?? 0,
            fat: try c.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        )
    }

    /// Picks the best available name for the given language preferences, matching on
    /// the language code alone so "hu-HU" still finds a "hu" translation. Falls back to
    /// English, so a partly translated catalogue shows names rather than blanks.
    ///
    /// `preferring` is a parameter only so tests need not depend on the host's settings.
    static func preferred(from names: [String: String],
                          preferring languages: [String] = Locale.preferredLanguages) -> String {
        for tag in languages {
            let code = Locale(identifier: tag).language.languageCode?.identifier
            if let code, let match = names[code] { return match }
        }
        return names["en"] ?? names.values.sorted().first ?? ""
    }
}

/// The bundled generic food catalogue: ~1,900 everyday foods with nutrition per
/// 100 g, available offline with no account, key or network.
///
/// Data is CoFID, published by the UK Department of Health and Social Care under
/// the Open Government Licence v3.0. See `Tools/README.md` for how it is generated.
enum FoodCatalog {
    static let attribution = """
        Nutrition data from McCance and Widdowson's The Composition of Foods \
        Integrated Dataset (CoFID), UK Department of Health and Social Care, \
        under the Open Government Licence v3.0.
        """

    /// Loaded once, on first search rather than at launch.
    static let all: [CatalogFood] = {
        guard let url = Bundle.main.url(forResource: "GenericFoods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([CatalogFood].self, from: data)
        else { return [] }
        return foods
    }()

    /// Ranked so that a plain staple beats a variant of it: "beef" should lead with
    /// the entries whose name *starts* with beef, not the ninety cuts that mention it.
    static func search(_ query: String, limit: Int = 40) -> [CatalogFood] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 2 else { return [] }

        var ranked: [(rank: Int, length: Int, food: CatalogFood)] = []
        for food in all {
            var best: Int?
            for candidate in food.names.values {
                let name = candidate.lowercased()
                guard let range = name.range(of: needle) else { continue }
                let rank: Int
                if range.lowerBound == name.startIndex {
                    rank = 0
                } else if name[name.index(before: range.lowerBound)] == " " {
                    rank = 1
                } else {
                    rank = 2
                }
                best = min(best ?? rank, rank)
            }
            guard let rank = best else { continue }
            ranked.append((rank, food.name.count, food))
        }

        return ranked
            .sorted { ($0.rank, $0.length, $0.food.name) < ($1.rank, $1.length, $1.food.name) }
            .prefix(limit)
            .map(\.food)
    }
}
