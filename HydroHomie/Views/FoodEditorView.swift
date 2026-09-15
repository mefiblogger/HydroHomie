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
    private let onSaved: (FoodItem, Double?) -> Void

    @State private var name: String
    @State private var icon: FoodIcon
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
    init(creatingNamed name: String = "", onSaved: @escaping (FoodItem, Double?) -> Void) {
        self.existing = nil
        self.onSaved = onSaved
        _name = State(initialValue: name)
        _icon = State(initialValue: .default)
        _energy = State(initialValue: "")
        _carbs = State(initialValue: "")
        _sugar = State(initialValue: "")
        _fiber = State(initialValue: "")
        _protein = State(initialValue: "")
        _fat = State(initialValue: "")
        _portion = State(initialValue: "100")
        _portionTexts = State(initialValue: [:])
    }

    /// Correcting an existing food. Nothing is logged.
    init(editing item: FoodItem, onSaved: @escaping (FoodItem, Double?) -> Void = { _, _ in }) {
        self.existing = item
        self.onSaved = onSaved
        _name = State(initialValue: item.name)
        _icon = State(initialValue: FoodIcon(rawValue: item.icon) ?? .default)
        _energy = State(initialValue: Self.text(item.energyKcal))
        _carbs = State(initialValue: Self.text(item.carbsGrams))
        _sugar = State(initialValue: Self.text(item.sugarGrams))
        _fiber = State(initialValue: Self.text(item.fiberGrams))
        _protein = State(initialValue: Self.text(item.proteinGrams))
        _fat = State(initialValue: Self.text(item.fatGrams))
        _portion = State(initialValue: Self.text(item.defaultPortionGrams))
        _portionTexts = State(initialValue: Dictionary(
            uniqueKeysWithValues: item.portions.map { ($0.kind, Self.text($0.grams)) }
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
            Section("Food") {
                TextField("Name", text: $name)
                iconPicker
            }

            Section {
                field("Energy", text: $energy, suffix: "kcal")
                field("Carbs", text: $carbs, suffix: "g")
                field("of which sugar", text: $sugar, suffix: "g")
                field("of which fibre", text: $fiber, suffix: "g")
                field("Protein", text: $protein, suffix: "g")
                field("Fat", text: $fat, suffix: "g")
            } header: {
                Text("Per 100 g")
            } footer: {
                Text("Sugar and fibre are part of the carbohydrate figure, not extra to it. Leave anything you don't know blank.")
            }

            Section {
                ForEach(PortionKind.allCases) { kind in
                    field(kind.singular.capitalized, text: binding(for: kind), suffix: "g")
                }
            } header: {
                Text("Portions")
            } footer: {
                Text("The weight of one. Set “piece” to 2 g for grapes and you can log 10 pieces later. Leave blank for any you don't use.")
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
                        Text("g")
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
        return value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
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

    private var enteredPortions: [NamedPortion] {
        PortionKind.allCases.compactMap { kind in
            Self.positive(portionTexts[kind] ?? "").map { NamedPortion(kind: kind, grams: $0) }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nutrients = enteredNutrients

        if let existing {
            existing.name = trimmed
            existing.icon = icon.rawValue
            existing.energyKcal = nutrients.energyKcal
            existing.carbsGrams = nutrients.carbs
            existing.sugarGrams = nutrients.sugar
            existing.fiberGrams = nutrients.fiber
            existing.proteinGrams = nutrients.protein
            existing.fatGrams = nutrients.fat
            existing.portions = enteredPortions
            if let grams { existing.defaultPortionGrams = grams }
            try? context.save()
            onSaved(existing, nil)
            dismiss()
        } else {
            guard let grams else { return }
            let item = FoodItem(
                name: trimmed,
                per100g: nutrients,
                defaultPortionGrams: grams,
                portions: enteredPortions,
                icon: icon
            )
            context.insert(item)
            try? context.save()
            onSaved(item, grams)
        }
    }
}
