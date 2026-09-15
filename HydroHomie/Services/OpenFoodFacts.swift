// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A product looked up from Open Food Facts. Held as a value, never stored: it
/// becomes a `FoodItem` only if the user goes through with logging it.
struct RemoteFood: Identifiable, Hashable, Sendable {
    var barcode: String
    var name: String
    var brand: String?
    var quantity: String?
    var nutrients: Nutrients
    /// Open Food Facts is crowd-sourced and frequently incomplete; the editor
    /// highlights what is missing rather than logging a silent zero.
    var missing: [String]

    var id: String { barcode }

    var displayName: String {
        guard let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) else {
            return name
        }
        return "\(brand) \(name)"
    }
}

/// Open Food Facts lookups: barcode and free text.
///
/// Queried live and cached only as the user's own foods — nothing is bundled or
/// redistributed, so the database's ODbL share-alike never attaches to this project.
enum OpenFoodFacts {
    /// Open Food Facts blocks anonymous clients; this identifies the app as they ask.
    private static let userAgent = "HydroHomie/1.0 (https://github.com/mefiblogger/HydroHomie)"
    private static let fields = "code,product_name,product_name_hu,brands,quantity,nutriments"

    enum LookupError: Error, LocalizedError {
        case notFound
        case noNutrition
        case offline
        case busy

        var errorDescription: String? {
            switch self {
            case .notFound: "That barcode isn't in Open Food Facts yet."
            case .noNutrition: "That product is listed, but has no nutrition information."
            case .offline: "Couldn't reach Open Food Facts. Check your connection."
            case .busy: "Open Food Facts is rate limiting us. Wait a moment and try again."
            }
        }
    }

    // MARK: - Barcode

    static func lookup(barcode: String) async throws -> RemoteFood {
        var components = URLComponents(
            string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")!
        components.queryItems = [URLQueryItem(name: "fields", value: fields)]

        let json = try await get(components.url!)
        guard (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any] else {
            throw LookupError.notFound
        }
        guard let food = food(from: product, fallbackBarcode: barcode) else {
            throw LookupError.noNutrition
        }
        return food
    }

    // MARK: - Text search

    /// Uses the legacy search endpoint on purpose: the v2 `search_terms` parameter is
    /// ignored, and returns millions of unrelated products for any query.
    ///
    /// Open Food Facts rate limits search far harder than barcode lookup — roughly
    /// ten a minute — so this is called on submit, never per keystroke.
    static func search(_ text: String, limit: Int = 15) async throws -> [RemoteFood] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(limit)),
            URLQueryItem(name: "fields", value: fields),
        ]

        let json = try await get(components.url!)
        let products = json["products"] as? [[String: Any]] ?? []
        return products.compactMap { food(from: $0, fallbackBarcode: nil) }
    }

    // MARK: - Plumbing

    private static func get(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LookupError.offline
        }

        // Without this a 503 body parses as no JSON, and a throttled request looks
        // identical to a product that does not exist.
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 429, 500...599: throw LookupError.busy
            default: throw LookupError.notFound
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LookupError.busy
        }
        return json
    }

    /// Open Food Facts returns nutriment values as numbers or as strings depending on
    /// how they were entered, so both are accepted.
    static func amount(_ nutriments: [String: Any], _ key: String) -> Double? {
        if let value = nutriments[key] as? Double { return value }
        if let value = nutriments[key] as? Int { return Double(value) }
        if let text = nutriments[key] as? String { return Double(text) }
        return nil
    }

    static func food(from product: [String: Any], fallbackBarcode: String?) -> RemoteFood? {
        let barcode = (product["code"] as? String) ?? fallbackBarcode ?? ""
        guard !barcode.isEmpty else { return nil }

        // Prefer a Hungarian name when the product carries one.
        let name = [(product["product_name_hu"] as? String), (product["product_name"] as? String)]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let name else { return nil }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        guard let energy = amount(nutriments, "energy-kcal_100g") else { return nil }

        var missing: [String] = []
        func value(_ key: String, _ label: String) -> Double {
            guard let found = amount(nutriments, key) else {
                missing.append(label)
                return 0
            }
            return found
        }

        return RemoteFood(
            barcode: barcode,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: (product["brands"] as? String)?
                .split(separator: ",").first.map(String.init)?
                .trimmingCharacters(in: .whitespaces),
            quantity: product["quantity"] as? String,
            nutrients: Nutrients(
                energyKcal: energy,
                carbs: value("carbohydrates_100g", "carbs"),
                sugar: value("sugars_100g", "sugar"),
                fiber: value("fiber_100g", "fibre"),
                protein: value("proteins_100g", "protein"),
                fat: value("fat_100g", "fat")
            ),
            missing: missing
        )
    }
}
