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

    /// Finds catalogue entries for a colloquial name like "beef stew" or "white rice".
    ///
    /// `search` is a substring scan, which is right for someone typing and watching
    /// the list narrow, but useless here: CoFID names are formal descriptors
    /// ("Beef, stewing steak, stewed, lean"), so "beef stew" appears in none of them
    /// as a substring. This scores on how many words of the term the entry accounts
    /// for instead, which is what turns a spoken name into a row.
    ///
    /// Returns several candidates rather than one. The best guess is frequently not
    /// the right one, so the caller is expected to show the alternatives.
    static func bestMatches(for term: String, limit: Int = 6) -> [CatalogFood] {
        let wanted = tokens(term)
        guard !wanted.isEmpty else { return [] }

        var scored: [Score] = []
        for food in all {
            var best: Score?
            for candidate in food.names.values {
                let have = tokens(candidate)
                guard !have.isEmpty else { continue }
                let matched = wanted.filter { want in have.contains { related($0, want) } }.count
                guard matched > 0 else { continue }
                // CoFID leads with the food and qualifies afterwards, so the earlier
                // the asked-for word appears, the more the entry is *about* it:
                // "Potato chips, microwave" over "Peanuts, raisins and chocolate chips".
                let position = have.firstIndex { have in wanted.contains { related(have, $0) } } ?? have.count
                let score = Score(
                    coverage: Double(matched) / Double(wanted.count),
                    unprepared: have.contains { unprepared.contains($0) },
                    position: position,
                    length: have.count,
                    name: candidate,
                    food: food
                )
                if best == nil || score.beats(best!) { best = score }
            }
            if let best { scored.append(best) }
        }

        return scored
            .sorted { $0.beats($1) }
            .prefix(limit)
            .map(\.food)
    }

    private struct Score {
        var coverage: Double
        var unprepared: Bool
        var position: Int
        var length: Int
        var name: String
        var food: CatalogFood

        /// Most of the term accounted for, then the entry most *about* it, then the
        /// plainest descriptor — a longer one is a variant of a shorter one. Name last,
        /// so the order is total and a shuffle of the catalogue cannot change it.
        func beats(_ other: Score) -> Bool {
            if coverage != other.coverage { return coverage > other.coverage }
            if unprepared != other.unprepared { return !unprepared }
            if position != other.position { return position < other.position }
            if length != other.length { return length < other.length }
            return name < other.name
        }
    }

    /// Whether two words are close enough to count as the same one. A prefix match
    /// both ways covers the plurals and participles that separate how people speak
    /// from how CoFID writes — "potatoes"/"potato", "fried"/"fry".
    private static func related(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = a.count <= b.count ? a : b
        let longer = a.count <= b.count ? b : a
        // A prefix alone is too loose: it makes "cheeseburger" a kind of "cheese" and
        // matches every cheese in the catalogue. Allowing only a short tail keeps the
        // inflections and rejects the compounds.
        guard shorter.count >= 4, longer.count - shorter.count <= 3 else { return false }
        return longer.hasPrefix(shorter)
    }

    /// Lowercased, diacritic-folded words of two letters or more. Folding matters for
    /// a catalogue that will carry "fôlded" names in other languages later.
    private static func tokens(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "en_US"))
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    /// Words that carry no food meaning and would otherwise match hundreds of rows.
    private static let stopWords: Set<String> = [
        "with", "and", "the", "of", "in", "on", "a", "an", "some", "plus",
    ]

    /// Forms nobody eats as such. CoFID carries the raw, dried and concentrated
    /// version of almost everything alongside the cooked one, and an alphabetical
    /// tie-break was picking them: "glass of milk" landed on milkshake powder at 388
    /// kcal per 100 g, and a burger on raw mince. This is a food log — what gets
    /// eaten is the prepared form.
    private static let unprepared: Set<String> = [
        "raw", "powder", "powdered", "dried", "dehydrated", "concentrate",
        "concentrated", "uncooked", "frozen",
    ]

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
