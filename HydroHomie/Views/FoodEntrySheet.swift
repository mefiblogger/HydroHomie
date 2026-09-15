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
    @State private var editing: FoodItem?

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
                        FoodEditorView(creatingNamed: search) { item, grams in
                            log(item, grams: grams ?? item.defaultPortionGrams,
                                count: 0, kind: nil)
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
                                FoodRow(item: item)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editing = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color.brand)
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
            .navigationDestination(item: $editing) { item in
                FoodEditorView(editing: item)
            }
        }
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
