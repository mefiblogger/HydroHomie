// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
import FoundationModels

/// A food the model picked out of a description or a photo, before it has been
/// matched to anything.
///
/// Note what is *not* here: no calories, no macros. The model's job is language —
/// working out that "nokedli" is a flour dumpling and roughly how much of it is on
/// the plate. Every nutrition figure comes from the catalogue, because a 3B model
/// asked for a calorie count will produce a confident, plausible, wrong one.
struct RecognisedFood: Identifiable, Equatable, Sendable {
    let id = UUID()
    /// A plain English name, whatever language the user wrote in — the catalogue is
    /// English, so this is what gets looked up.
    var name: String
    /// Estimated edible weight, grams.
    var grams: Double

    static func == (a: RecognisedFood, b: RecognisedFood) -> Bool {
        a.name == b.name && a.grams == b.grams
    }
}

/// A whole reading of one meal. Wrapped in a named type because a bare array is not
/// something a navigation destination can key off.
struct RecognisedMeal: Identifiable, Hashable {
    let id = UUID()
    var foods: [RecognisedFood]

    static func == (a: RecognisedMeal, b: RecognisedMeal) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Whether on-device recognition can run, and if not, why — because the reasons
/// differ in what the user can do about them.
enum RecogniserStatus: Equatable {
    case ready
    /// Below iOS 26: the framework does not exist on this system at all.
    case systemTooOld
    /// Hardware cannot run Apple Intelligence. Permanent for this device.
    case deviceNotEligible
    /// Capable, but the user has not switched Apple Intelligence on. They can.
    case notEnabled
    /// Switched on, model still downloading. Resolves itself.
    case modelNotReady

    var isReady: Bool { self == .ready }
}

enum RecogniserError: Error, LocalizedError, Equatable {
    case unavailable(RecogniserStatus)
    case nothingRecognised
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable(.notEnabled):
            String(localized: "Turn on Apple Intelligence in Settings to use this.",
                   comment: "Recognition unavailable")
        case .unavailable(.modelNotReady):
            String(localized: "Apple Intelligence is still getting ready. Try again shortly.",
                   comment: "Recognition unavailable")
        case .unavailable:
            String(localized: "This device can't do on-device food recognition.",
                   comment: "Recognition unavailable")
        case .nothingRecognised:
            String(localized: "Couldn't make out any food in that.",
                   comment: "Recognition found nothing")
        case .failed:
            String(localized: "Couldn't read that. Try describing it differently.",
                   comment: "Recognition failed")
        }
    }
}

/// Turns a description or a photo of a meal into a list of foods and rough weights,
/// using Apple's on-device model. Nothing leaves the phone and nothing is billed.
enum FoodRecogniser {

    /// Re-read before every use rather than cached: the user can switch Apple
    /// Intelligence off, or the model can finish downloading, while the app is open.
    static var status: RecogniserStatus {
        guard #available(iOS 26.0, *) else { return .systemTooOld }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .notEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .deviceNotEligible
        }
    }

    /// Photographs need iOS 27 — the model only took image input from that release,
    /// a year after it started taking text.
    static var supportsPhotos: Bool {
        guard #available(iOS 27.0, *) else { return false }
        return status.isReady
    }

    // MARK: - Description

    static func recognise(description: String) async throws -> [RecognisedFood] {
        let status = status
        guard status.isReady, #available(iOS 26.0, *) else {
            throw RecogniserError.unavailable(status)
        }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let reading = try await session.respond(
                to: "Meal: \(description)",
                generating: MealReading.self,
                options: options
            )
            return reading.content.foods()
        } catch {
            throw RecogniserError.failed
        }
    }

    // MARK: - Photo

    @available(iOS 27.0, *)
    static func recognise(photo: CGImage) async throws -> [RecognisedFood] {
        let status = status
        guard status.isReady else { throw RecogniserError.unavailable(status) }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let reading = try await session.respond(
                generating: MealReading.self,
                options: options
            ) {
                Attachment(photo)
                "Identify everything on the plate in this photograph."
            }
            return reading.content.foods()
        } catch {
            throw RecogniserError.failed
        }
    }

    /// Near-greedy sampling. At the default temperature the same meal decomposes on
    /// one run and comes back as a single "cheeseburger" on the next, which then
    /// matches nothing — this is extraction, not writing, so the variety is pure cost.
    @available(iOS 26.0, *)
    private static var options: GenerationOptions {
        GenerationOptions(temperature: 0.1)
    }

    // MARK: - Prompt

    /// The whole design is in here.
    ///
    /// Two instructions carry it. **Break the dish into components**, because the
    /// catalogue is a composition table of ingredients — it has burgers, cheese and
    /// buns, and no row for "cheeseburger". And **answer in English**, because the
    /// catalogue is English while the user may well not be.
    ///
    /// The last line is the important one: the model is told it is not being asked
    /// for nutrition at all.
    private static var instructions: String {
        """
        You identify foods for a nutrition tracker.

        Always break a dish into the individual foods a food composition table \
        would list, never the dish itself. "Cheeseburger" is wrong; beef burger, \
        cheese and a bread bun is right. A named dish must always come back as two \
        or more foods.

        Give each food a short, plain English name, whatever language the meal was \
        described in. Use British supermarket words: chips, not fries; aubergine, \
        not eggplant; biscuit, not cookie; coriander, not cilantro.

        Estimate the edible weight of each food in grams, for one serving as \
        described. Be realistic about ordinary portions.

        Examples:
        "cheeseburger with fries" -> beef burger 110 g, cheese 20 g, bread bun 50 g, \
        potato chips 100 g
        "marhapörkölt nokedlivel" -> beef 150 g, onion 40 g, wheat flour dumplings 150 g
        "két tojás rántotta" -> eggs 120 g, butter 10 g

        Do not estimate calories, energy or any nutrient value. You are not asked \
        for them and they are looked up elsewhere.
        """
    }
}

// MARK: - Model output

@available(iOS 26.0, *)
@Generable
private struct MealReading {
    @Guide(description: "Every individual food in the meal, broken down into separate ingredients")
    var items: [FoodReading]

    /// Drops anything with no name or a weight that cannot be real, rather than
    /// letting it reach the catalogue and match something at random.
    func foods() -> [RecognisedFood] {
        items.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, item.grams > 0, item.grams < 5_000 else { return nil }
            return RecognisedFood(name: name, grams: item.grams)
        }
    }
}

@available(iOS 26.0, *)
@Generable
private struct FoodReading {
    @Guide(description: "A short plain English name for one food, such as 'beef burger' or 'white rice'")
    var name: String

    @Guide(description: "Edible weight of this food in grams")
    var grams: Double
}
