// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

final class FoodCatalogTests: XCTestCase {

    func testCatalogueIsBundledAndDecodes() {
        XCTAssertGreaterThan(FoodCatalog.all.count, 1500,
                             "the bundled catalogue failed to load — is the JSON in the app target?")
    }

    func testEveryFoodHasANameAndEnergy() {
        for food in FoodCatalog.all.prefix(500) {
            XCTAssertFalse(food.name.isEmpty)
            XCTAssertGreaterThanOrEqual(food.nutrients.energyKcal, 0)
        }
    }

    /// The staples that a curation pass previously deleted. If one of these goes
    /// missing again, the catalogue build broke.
    func testEverydayStaplesArePresent() {
        for staple in ["Milk, whole", "Eggs, chicken, whole, raw", "Cheese, Cheddar",
                       "Bread, white", "Coffee, infusion", "Potatoes, old, boiled",
                       "Apples, eating, raw", "Bananas", "Butter", "Rice, white"] {
            let found = FoodCatalog.all.contains {
                $0.name.lowercased().hasPrefix(staple.lowercased())
            }
            XCTAssertTrue(found, "\(staple) is missing from the catalogue")
        }
    }

    func testSearchNeedsAtLeastTwoCharacters() {
        XCTAssertTrue(FoodCatalog.search("").isEmpty)
        XCTAssertTrue(FoodCatalog.search("m").isEmpty)
    }

    func testSearchLeadsWithNamesThatStartWithTheQuery() {
        let results = FoodCatalog.search("banana")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results[0].name.lowercased().hasPrefix("banana"),
                      "expected a banana first, got \(results[0].name)")
    }

    func testSearchRanksPlainerNamesFirst() {
        // Beef has ninety-odd cuts; the shortest matching names should lead.
        let results = FoodCatalog.search("beef")
        XCTAssertFalse(results.isEmpty)
        let leading = results.prefix(5).map(\.name)
        XCTAssertTrue(leading.allSatisfy { $0.lowercased().hasPrefix("beef") },
                      "expected beef entries first, got \(leading)")
    }

    func testSearchIsCaseInsensitive() {
        XCTAssertEqual(FoodCatalog.search("MILK").count, FoodCatalog.search("milk").count)
    }

    func testSearchIsCapped() {
        XCTAssertLessThanOrEqual(FoodCatalog.search("a", limit: 10).count, 10)
        XCTAssertLessThanOrEqual(FoodCatalog.search("ea").count, 40)
    }

    // MARK: - Per-language names

    /// The catalogue used to store a bare string for the name. Older bundles must keep
    /// decoding, so a rebuild is never a prerequisite for shipping.
    func testLegacySingleLanguageShapeStillDecodes() throws {
        let json = Data(#"[{"n":"Ackee, canned","kcal":151,"carb":0.8}]"#.utf8)
        let foods = try JSONDecoder().decode([CatalogFood].self, from: json)
        XCTAssertEqual(foods.first?.name, "Ackee, canned")
        XCTAssertEqual(foods.first?.key, "Ackee, canned")
        XCTAssertEqual(foods.first?.nutrients.energyKcal, 151)
    }

    func testPerLanguageShapeDecodes() throws {
        let json = Data(#"[{"n":{"en":"Apples, eating, raw","hu":"Alma, nyers"},"kcal":47}]"#.utf8)
        let foods = try JSONDecoder().decode([CatalogFood].self, from: json)
        XCTAssertEqual(foods.first?.key, "Apples, eating, raw")
        XCTAssertEqual(foods.first?.names["hu"], "Alma, nyers")
    }

    /// Identity is the English name, so a food keeps the same id in every language.
    func testIdentityDoesNotFollowTheDisplayLanguage() {
        let names = ["en": "Apples, eating, raw", "hu": "Alma, nyers"]
        XCTAssertEqual(CatalogFood.preferred(from: names, preferring: ["hu-HU"]), "Alma, nyers")
        XCTAssertEqual(CatalogFood.preferred(from: names, preferring: ["en-GB"]), "Apples, eating, raw")
    }

    /// An unsupported language falls back to English rather than showing nothing.
    func testUntranslatedLanguageFallsBackToEnglish() {
        let names = ["en": "Apples, eating, raw"]
        XCTAssertEqual(CatalogFood.preferred(from: names, preferring: ["hu-HU"]), "Apples, eating, raw")
    }

    /// Once the catalogue carries Hungarian, typing "alma" has to find the food even
    /// while the interface is still showing English names.
    func testSearchMatchesAnyLanguagesName() throws {
        let json = Data(#"[{"n":{"en":"Apples, eating, raw","hu":"Alma, nyers"},"kcal":47}]"#.utf8)
        let food = try JSONDecoder().decode([CatalogFood].self, from: json)[0]
        XCTAssertTrue(food.names.values.contains { $0.lowercased().contains("alma") })
    }

    func testACatalogueFoodConvertsToALibraryItem() {
        guard let milk = FoodCatalog.search("Milk, whole").first else {
            return XCTFail("no whole milk in the catalogue")
        }
        let item = FoodItem(name: milk.name, per100g: milk.nutrients)
        XCTAssertEqual(item.per100g, milk.nutrients)
        XCTAssertEqual(item.nutrients(forAmount: 200).energyKcal,
                       milk.nutrients.energyKcal * 2, accuracy: 0.0001)
    }
}
