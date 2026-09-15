// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// Pick a food from the library and log a portion of it, or define a new one.
/// The library is the whole store of foods for now; a barcode or database lookup
/// would seed the same `FoodItem` records rather than bypass them.
struct FoodEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.lastUsedAt, order: .reverse) private var items: [FoodItem]

    @State private var search = ""

    private var matches: [FoodItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NewFoodView(initialName: search) { item, grams, count, kind in
                            log(item, grams: grams, count: count, kind: kind)
                        }
                    } label: {
                        Label("New food", systemImage: "plus.circle.fill")
                    }
                }

                if matches.isEmpty {
                    Section {
                        Text(items.isEmpty
                             ? "Your food library is empty. Add a food to get started."
                             : "No food matches “\(search)”.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Library") {
                        ForEach(matches) { item in
                            NavigationLink {
                                LogPortionView(item: item) { grams, count, kind in
                                    log(item, grams: grams, count: count, kind: kind)
                                }
                            } label: {
                                row(item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search your foods")
            .navigationTitle("Track food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: FoodItem) -> some View {
        HStack(spacing: 10) {
            Text(item.icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(subtitle(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subtitle(_ item: FoodItem) -> String {
        let energy = "\(Int(item.energyKcal.rounded())) kcal per 100 g"
        guard !item.portions.isEmpty else { return energy }
        let measures = item.portions
            .map { "\($0.kind.singular) \(Int($0.grams.rounded())) g" }
            .joined(separator: ", ")
        return "\(energy) · \(measures)"
    }

    private func log(_ item: FoodItem, grams: Double, count: Double, kind: PortionKind?) {
        FoodLogger.log(item, grams: grams, count: count, kind: kind, context: context)
        dismiss()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(matches[index])
        }
        try? context.save()
    }
}

/// Choose how much of an existing food to log, in grams or in one of the food's
/// own named measures.
private struct LogPortionView: View {
    var item: FoodItem
    /// grams, count, kind — kind is nil when logged straight in grams.
    var onLog: (Double, Double, PortionKind?) -> Void

    @State private var measure: Measure = .grams
    @State private var quantityText = ""

    private enum Measure: Hashable {
        case grams
        case named(PortionKind)

        var kind: PortionKind? {
            if case .named(let kind) = self { return kind }
            return nil
        }
    }

    private var quantity: Double? {
        guard let value = Double(quantityText.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return value
    }

    private var grams: Double? {
        guard let quantity else { return nil }
        switch measure {
        case .grams: return quantity
        case .named(let kind): return item.grams(count: quantity, of: kind)
        }
    }

    var body: some View {
        Form {
            Section("Portion") {
                if !item.portions.isEmpty {
                    Picker("Measured in", selection: $measure) {
                        Text("Grams").tag(Measure.grams)
                        ForEach(item.portions) { portion in
                            Text(portion.kind.singular.capitalized)
                                .tag(Measure.named(portion.kind))
                        }
                    }
                }

                HStack {
                    Text(measure.kind == nil ? "Amount" : "How many")
                    Spacer(minLength: 12)
                    TextField("0", text: $quantityText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(unitSuffix)
                        .foregroundStyle(.secondary)
                }

                if measure.kind != nil, let grams {
                    LabeledContent("Weight", value: "\(Int(grams.rounded())) g")
                }
            }

            Section("This portion") {
                NutrientBreakdown(nutrients: item.nutrients(forGrams: grams ?? 0))
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    if let grams, let quantity {
                        onLog(grams, quantity, measure.kind)
                    }
                }
                .disabled(grams == nil)
            }
        }
        .onAppear {
            // A food only has named measures because they are how you think about
            // it, so lead with the first one rather than with grams.
            if let first = item.portions.first {
                measure = .named(first.kind)
            }
            resetQuantity()
        }
        .onChange(of: measure) { _, _ in resetQuantity() }
    }

    /// Singular at a count of one, so the field does not read "1 pieces".
    private var unitSuffix: String {
        guard let kind = measure.kind else { return "g" }
        return abs((quantity ?? 0) - 1) < 0.0001 ? kind.singular : kind.plural
    }

    private func resetQuantity() {
        switch measure {
        case .grams:
            quantityText = String(Int(item.defaultPortionGrams.rounded()))
        case .named:
            quantityText = "1"
        }
    }
}

/// Define a new food and log a portion of it in one pass.
private struct NewFoodView: View {
    var initialName: String
    /// item, grams, count, kind
    var onCreate: (FoodItem, Double, Double, PortionKind?) -> Void

    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var portion = "100"
    @State private var energy = ""
    @State private var carbs = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var portionTexts: [PortionKind: String] = [:]
    @State private var icon: FoodIcon = .default

    private var grams: Double? { positive(portion) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && grams != nil
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
        .navigationTitle("New food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            if name.isEmpty { name = initialName }
        }
    }

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

    private func positive(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return value
    }

    /// Blank means "unknown", which is stored as zero.
    private func amount(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")).map { max($0, 0) } ?? 0
    }

    private func save() {
        guard let grams else { return }
        let portions = PortionKind.allCases.compactMap { kind -> NamedPortion? in
            guard let weight = positive(portionTexts[kind] ?? "") else { return nil }
            return NamedPortion(kind: kind, grams: weight)
        }
        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            per100g: Nutrients(
                energyKcal: amount(energy),
                carbs: amount(carbs),
                sugar: amount(sugar),
                fiber: amount(fiber),
                protein: amount(protein),
                fat: amount(fat)
            ),
            defaultPortionGrams: grams,
            portions: portions,
            icon: icon
        )
        context.insert(item)
        try? context.save()
        onCreate(item, grams, grams, nil)
    }
}

/// Read-only nutrient list, shared by the portion and preview screens.
private struct NutrientBreakdown: View {
    var nutrients: Nutrients

    var body: some View {
        LabeledContent("Energy", value: "\(Int(nutrients.energyKcal.rounded())) kcal")
        LabeledContent("Carbs", value: grams(nutrients.carbs))
        LabeledContent("of which sugar", value: grams(nutrients.sugar))
        LabeledContent("of which fibre", value: grams(nutrients.fiber))
        LabeledContent("Protein", value: grams(nutrients.protein))
        LabeledContent("Fat", value: grams(nutrients.fat))
    }

    private func grams(_ value: Double) -> String {
        String(format: "%.1f g", value)
    }
}

#Preview {
    FoodEntrySheet()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
