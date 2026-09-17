// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// One form for both defining a new food and correcting an existing one.
///
/// Editing changes the library entry only. Anything already logged keeps the
/// figures it was logged with, because `FoodEntry` snapshots them rather than
/// pointing back here.
struct FoodEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let existing: FoodItem?
    private let barcode: String?
    private let missing: [String]
    private let onSaved: (FoodItem, Double?) -> Void

    @State private var name: String
    @State private var icon: FoodIcon
    @State private var measure: FoodMeasure
    @State private var energy: String
    @State private var carbs: String
    @State private var sugar: String
    @State private var fiber: String
    @State private var protein: String
    @State private var fat: String
    @State private var portion: String
    @State private var portionTexts: [PortionKind: String]

    /// Creating: the form also logs a first portion, so a new food lands in the day
    /// in one pass.
    init(
        creatingNamed name: String = "",
        nutrients: Nutrients = Nutrients(),
        barcode: String? = nil,
        missing: [String] = [],
        onSaved: @escaping (FoodItem, Double?) -> Void
    ) {
        self.existing = nil
        self.barcode = barcode
        self.missing = missing
        self.onSaved = onSaved
        _name = State(initialValue: name)
        _icon = State(initialValue: .default)
        _measure = State(initialValue: .grams)
        _energy = State(initialValue: Self.text(nutrients.energyKcal))
        _carbs = State(initialValue: Self.text(nutrients.carbs))
        _sugar = State(initialValue: Self.text(nutrients.sugar))
        _fiber = State(initialValue: Self.text(nutrients.fiber))
        _protein = State(initialValue: Self.text(nutrients.protein))
        _fat = State(initialValue: Self.text(nutrients.fat))
        _portion = State(initialValue: "100")
        _portionTexts = State(initialValue: [:])
    }

    /// Correcting an existing food. Nothing is logged.
    init(editing item: FoodItem, onSaved: @escaping (FoodItem, Double?) -> Void = { _, _ in }) {
        self.existing = item
        self.barcode = item.barcode
        self.missing = []
        self.onSaved = onSaved
        _name = State(initialValue: item.name)
        _icon = State(initialValue: FoodIcon(rawValue: item.icon) ?? .default)
        _measure = State(initialValue: item.measure)
        _energy = State(initialValue: Self.text(item.energyKcal))
        _carbs = State(initialValue: Self.text(item.carbsGrams))
        _sugar = State(initialValue: Self.text(item.sugarGrams))
        _fiber = State(initialValue: Self.text(item.fiberGrams))
        _protein = State(initialValue: Self.text(item.proteinGrams))
        _fat = State(initialValue: Self.text(item.fatGrams))
        _portion = State(initialValue: Self.text(item.defaultPortionAmount))
        _portionTexts = State(initialValue: Dictionary(
            uniqueKeysWithValues: item.portions.map { ($0.kind, Self.text($0.amount)) }
        ))
    }

    private var isEditing: Bool { existing != nil }

    private var grams: Double? { Self.positive(portion) }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return isEditing || grams != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Measured in", selection: $measure) {
                    ForEach(FoodMeasure.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                iconPicker
            } header: {
                Text("Food")
            } footer: {
                Text(measure == .grams
                     ? "Solids are weighed. Labels give nutrition per 100 g."
                     : "Drinks are measured by volume. Labels give nutrition per 100 ml.")
            }

            if !missing.isEmpty {
                Section {
                    Label(
                        "Open Food Facts has no \(missing.joined(separator: ", ")) for this product. Check the packaging and fill it in.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                let kcal = String(localized: "kcal", comment: "Kilocalories, abbreviated")
                let g = String(localized: "g", comment: "Grams, abbreviated")
                field(String(localized: "Energy", comment: "Nutrient field"), text: $energy, suffix: kcal)
                field(String(localized: "Carbs", comment: "Macronutrient"), text: $carbs, suffix: g)
                field(String(localized: "of which sugar", comment: "Nutrient field"), text: $sugar, suffix: g)
                field(String(localized: "of which fibre", comment: "Nutrient field"), text: $fiber, suffix: g)
                field(String(localized: "Protein", comment: "Macronutrient"), text: $protein, suffix: g)
                field(String(localized: "Fat", comment: "Macronutrient"), text: $fat, suffix: g)
            } header: {
                Text("Per 100 \(measure.shortName)")
            } footer: {
                Text("Sugar and fibre are part of the carbohydrate figure, not extra to it. Leave anything you don't know blank.")
            }

            Section {
                ForEach(measure.portionKinds) { kind in
                    field(kind.singular.capitalized, text: binding(for: kind),
                          suffix: measure.shortName)
                }
            } header: {
                Text("Portions")
            } footer: {
                Text(measure == .grams
                     ? "The size of one. Set “piece” to 2 g for grapes and you can log 10 pieces later. Leave blank for any you don't use."
                     : "The size of one. Set “glass” to 250 ml for juice and you can log 2 glasses later. Leave blank for any you don't use.")
            }

            if isEditing {
                Section {
                    Text("Changes apply to this food from now on. Anything already logged keeps the figures it was logged with.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Portion to log now") {
                    HStack {
                        TextField("Amount", text: $portion)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(measure.shortName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit food" : "New food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") { save() }
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Pieces

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                  spacing: 6) {
            ForEach(FoodIcon.allCases) { option in
                Button {
                    icon = option
                } label: {
                    Text(option.rawValue)
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if option == icon {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.brand.opacity(0.22))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == icon ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }

    private func binding(for kind: PortionKind) -> Binding<String> {
        Binding(
            get: { portionTexts[kind] ?? "" },
            set: { portionTexts[kind] = $0 }
        )
    }

    private func field(_ title: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                // Fills the row rather than sitting in a narrow box: a 90pt target
                // is easy to miss, and a miss silently types into whichever field
                // still had focus.
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Values

    private static func text(_ value: Double) -> String {
        guard value > 0 else { return "" }
        return Quantity.text(value)
    }

    private static func positive(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return value
    }

    /// Blank means "unknown", which is stored as zero.
    private func amount(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")).map { max($0, 0) } ?? 0
    }

    private var enteredNutrients: Nutrients {
        Nutrients(
            energyKcal: amount(energy),
            carbs: amount(carbs),
            sugar: amount(sugar),
            fiber: amount(fiber),
            protein: amount(protein),
            fat: amount(fat)
        )
    }

    /// Only the measures that make sense for the chosen unit are kept, so switching
    /// a food from grams to millilitres does not leave a stale "piece" behind.
    private var enteredPortions: [NamedPortion] {
        measure.portionKinds.compactMap { kind in
            Self.positive(portionTexts[kind] ?? "").map { NamedPortion(kind: kind, amount: $0) }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nutrients = enteredNutrients

        if let existing {
            existing.name = trimmed
            existing.icon = icon.rawValue
            existing.measure = measure
            existing.energyKcal = nutrients.energyKcal
            existing.carbsGrams = nutrients.carbs
            existing.sugarGrams = nutrients.sugar
            existing.fiberGrams = nutrients.fiber
            existing.proteinGrams = nutrients.protein
            existing.fatGrams = nutrients.fat
            existing.portions = enteredPortions
            if let grams { existing.defaultPortionAmount = grams }
            try? context.save()
            onSaved(existing, nil)
            dismiss()
        } else {
            guard let grams else { return }
            let item = FoodItem(
                name: trimmed,
                per100g: nutrients,
                measure: measure,
                defaultPortionAmount: grams,
                portions: enteredPortions,
                icon: icon,
                barcode: barcode
            )
            context.insert(item)
            try? context.save()
            onSaved(item, grams)
        }
    }
}
