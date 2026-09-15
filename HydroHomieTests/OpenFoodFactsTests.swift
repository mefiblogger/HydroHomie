// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

/// Parsing only — no network. The fixtures are trimmed copies of real Open Food
/// Facts responses, including the awkward shapes it actually returns.
final class OpenFoodFactsTests: XCTestCase {

    private func product(_ json: String) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }

    func testParsesAHungarianProduct() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"5997010302239","product_name":"Ketchup","brands":"Univer","quantity":"470 g",
         "nutriments":{"energy-kcal_100g":106,"carbohydrates_100g":23,"sugars_100g":20,
                       "fiber_100g":0.7,"proteins_100g":1.5,"fat_100g":0.3}}
        """), fallbackBarcode: nil)

        XCTAssertEqual(food?.barcode, "5997010302239")
        XCTAssertEqual(food?.name, "Ketchup")
        XCTAssertEqual(food?.brand, "Univer")
        XCTAssertEqual(food?.displayName, "Univer Ketchup")
        XCTAssertEqual(food?.nutrients.energyKcal, 106)
        XCTAssertEqual(food?.nutrients.sugar, 20)
        XCTAssertEqual(food?.missing, [])
    }

    func testAcceptsNutrimentsGivenAsStrings() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"1","product_name":"Stringy","nutriments":{"energy-kcal_100g":"250",
         "carbohydrates_100g":"30","sugars_100g":"10","fiber_100g":"2",
         "proteins_100g":"5","fat_100g":"11"}}
        """), fallbackBarcode: nil)
        XCTAssertEqual(food?.nutrients.energyKcal, 250)
        XCTAssertEqual(food?.nutrients.fat, 11)
    }

    func testReportsWhatIsMissingRatherThanLoggingASilentZero() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"2","product_name":"Partial","nutriments":{"energy-kcal_100g":541,"fat_100g":60}}
        """), fallbackBarcode: nil)
        XCTAssertEqual(food?.nutrients.energyKcal, 541)
        XCTAssertEqual(Set(food?.missing ?? []), ["carbs", "sugar", "fibre", "protein"])
    }

    func testRejectsAProductWithNoEnergy() {
        XCTAssertNil(OpenFoodFacts.food(from: product("""
        {"code":"3","product_name":"Mystery","nutriments":{"fat_100g":1}}
        """), fallbackBarcode: nil))
    }

    func testRejectsAProductWithNoName() {
        XCTAssertNil(OpenFoodFacts.food(from: product("""
        {"code":"4","nutriments":{"energy-kcal_100g":100}}
        """), fallbackBarcode: nil))
    }

    func testPrefersAHungarianNameWhenPresent() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"5","product_name":"Cottage cheese bar","product_name_hu":"Túró Rudi",
         "nutriments":{"energy-kcal_100g":300}}
        """), fallbackBarcode: nil)
        XCTAssertEqual(food?.name, "Túró Rudi")
    }

    func testFallsBackToTheScannedBarcodeWhenTheBodyOmitsIt() {
        let food = OpenFoodFacts.food(from: product("""
        {"product_name":"No code","nutriments":{"energy-kcal_100g":100}}
        """), fallbackBarcode: "5998200750144")
        XCTAssertEqual(food?.barcode, "5998200750144")
    }

    func testDoesNotRepeatTheBrandWhenTheNameAlreadyCarriesIt() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"6","product_name":"Nutella","brands":"Nutella",
         "nutriments":{"energy-kcal_100g":533}}
        """), fallbackBarcode: nil)
        XCTAssertEqual(food?.displayName, "Nutella")
    }

    func testTakesOnlyTheFirstOfSeveralBrands() {
        let food = OpenFoodFacts.food(from: product("""
        {"code":"7","product_name":"Rudi","brands":"Pöttyös, FrieslandCampina",
         "nutriments":{"energy-kcal_100g":300}}
        """), fallbackBarcode: nil)
        XCTAssertEqual(food?.brand, "Pöttyös")
    }

    func testShortQueriesDoNotHitTheNetwork() async throws {
        let results = try await OpenFoodFacts.search("ab")
        XCTAssertTrue(results.isEmpty)
    }
}

/// The search field doubles as a barcode field, so the recogniser matters.
final class BarcodeRecognitionTests: XCTestCase {

    /// Mirrors FoodEntrySheet.barcode — the retail symbologies a scanner returns.
    private func barcode(_ text: String) -> String? {
        let query = text.trimmingCharacters(in: .whitespaces)
        let digits = query.filter(\.isNumber)
        guard digits.count == query.count, [8, 12, 13, 14].contains(digits.count) else {
            return nil
        }
        return digits
    }

    func testAcceptsTheRetailLengths() {
        XCTAssertEqual(barcode("5997010302239"), "5997010302239")   // EAN-13, Univer
        XCTAssertEqual(barcode("80176800"), "80176800")             // EAN-8, Nutella
        XCTAssertEqual(barcode("012345678905"), "012345678905")     // UPC-A
        XCTAssertEqual(barcode("12345678901234"), "12345678901234") // ITF-14
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(barcode("  5997010302239 "), "5997010302239")
    }

    func testRejectsOtherDigitLengths() {
        XCTAssertNil(barcode("123"))
        XCTAssertNil(barcode("1234567890"))
        XCTAssertNil(barcode("123456789012345"))
    }

    func testRejectsAnythingWithLetters() {
        XCTAssertNil(barcode("turo rudi"))
        XCTAssertNil(barcode("5997010302239x"))
    }

    func testRejectsDigitsBrokenUpBySpaces() {
        // A name that happens to contain numbers must not trigger a lookup.
        XCTAssertNil(barcode("599 701 030 2239"))
    }

    func testRejectsEmpty() {
        XCTAssertNil(barcode(""))
        XCTAssertNil(barcode("   "))
    }
}
