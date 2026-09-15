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
