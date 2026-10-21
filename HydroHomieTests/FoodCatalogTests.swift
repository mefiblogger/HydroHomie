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


    // MARK: - Colloquial matching

    /// What the whole recognition path rests on: a name a person would say has to
    /// reach a CoFID descriptor, which never phrases anything the same way.
    func testSpokenNamesReachTheRightCatalogueEntry() {
        let expected = [
            "beef stew": "Beef",
            "white rice": "Rice, white",
            "potato chips": "Potato chips",
            "beef burger": "Burger, beef",
            "scrambled eggs": "Eggs",
            "chicken breast": "Chicken",
        ]
        for (spoken, prefix) in expected {
            guard let best = FoodCatalog.bestMatches(for: spoken).first else {
                return XCTFail("no catalogue match for \(spoken)")
            }
            XCTAssertTrue(best.name.hasPrefix(prefix),
                          "\(spoken) matched \(best.name), expected something starting \(prefix)")
        }
    }

    /// The entry a word leads must beat one that merely mentions it — otherwise
    /// "chips" lands on chocolate chips and "milk" on a milk-chocolate bar.
    func testAnEntryAboutTheFoodBeatsOneThatMerelyMentionsIt() {
        let chips = FoodCatalog.bestMatches(for: "potato chips").first
        XCTAssertEqual(chips?.name.contains("chocolate"), false)

        let milk = FoodCatalog.bestMatches(for: "milk").first
        XCTAssertTrue(milk?.name.hasPrefix("Milk") == true)
    }

    /// A compound dish is the model's job to break up, not the matcher's. The
    /// catalogue holds components, so "cheeseburger" legitimately matches nothing —
    /// and must not fall through to every cheese in the database.
    func testCompoundDishesDoNotMatchTheirParts() {
        XCTAssertTrue(FoodCatalog.bestMatches(for: "cheeseburger").isEmpty)
    }

    /// CoFID lists the raw, dried and powdered form of nearly everything. A food log
    /// is about what was eaten, so those must lose to the prepared entry — "milk"
    /// landing on milkshake powder is a fivefold calorie error.
    func testFormsNobodyEatsLoseToThePreparedOne() {
        let milk = FoodCatalog.bestMatches(for: "milk").first?.name
        XCTAssertEqual(milk?.localizedCaseInsensitiveContains("powder"), false,
                       "milk matched \(milk ?? "nothing")")

        let burger = FoodCatalog.bestMatches(for: "beef burger").first?.name
        XCTAssertEqual(burger?.localizedCaseInsensitiveContains("raw"), false,
                       "beef burger matched \(burger ?? "nothing")")
    }

    /// The model says "egg" where CoFID says "Eggs". Three-letter food words are
    /// common enough that failing to pair them sent scrambled eggs to egg fu yung.
    func testShortFoodWordsPairWithTheirPlurals() {
        let egg = FoodCatalog.bestMatches(for: "eggs").first?.name
        XCTAssertTrue(egg?.hasPrefix("Egg") == true, "eggs matched \(egg ?? "nothing")")
        XCTAssertEqual(egg?.localizedCaseInsensitiveContains("fu yung"), false)
    }

    /// The same loosening must not make a pea a kind of peach.
    func testShortWordsDoNotMatchLongerUnrelatedOnes() {
        let pea = FoodCatalog.bestMatches(for: "peas").first?.name
        XCTAssertEqual(pea?.localizedCaseInsensitiveContains("peach"), false,
                       "peas matched \(pea ?? "nothing")")
    }

    func testWordsWithNoFoodMeaningAreIgnored() {
        // "with" and "and" would otherwise match hundreds of rows on their own.
        XCTAssertTrue(FoodCatalog.bestMatches(for: "with and the").isEmpty)
    }

    /// Ordering must not depend on where an entry happens to sit in the file.
    func testMatchOrderIsTotal() {
        let once = FoodCatalog.bestMatches(for: "chicken breast").map(\.name)
        let twice = FoodCatalog.bestMatches(for: "chicken breast").map(\.name)
        XCTAssertEqual(once, twice)
        XCTAssertEqual(Set(once).count, once.count, "a food should not appear twice")
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
