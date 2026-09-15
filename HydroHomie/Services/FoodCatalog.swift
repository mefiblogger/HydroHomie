// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One food from the bundled generic catalogue. Read-only: nothing here is stored,
/// it is copied into the user's own library the moment they log it.
struct CatalogFood: Decodable, Identifiable, Hashable {
    let name: String
    let nutrients: Nutrients

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name = "n", kcal, carb, sugar, fiber, prot, fat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        nutrients = Nutrients(
            energyKcal: try c.decodeIfPresent(Double.self, forKey: .kcal) ?? 0,
            carbs: try c.decodeIfPresent(Double.self, forKey: .carb) ?? 0,
            sugar: try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0,
            fiber: try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0,
            protein: try c.decodeIfPresent(Double.self, forKey: .prot) ?? 0,
            fat: try c.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        )
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
            let name = food.name.lowercased()
            guard let range = name.range(of: needle) else { continue }
            let rank: Int
            if range.lowerBound == name.startIndex {
                rank = 0
            } else if name[name.index(before: range.lowerBound)] == " " {
                rank = 1
            } else {
                rank = 2
            }
            ranked.append((rank, food.name.count, food))
        }

        return ranked
            .sorted { ($0.rank, $0.length, $0.food.name) < ($1.rank, $1.length, $1.food.name) }
            .prefix(limit)
            .map(\.food)
    }
}
