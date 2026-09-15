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
                        NewFoodView(initialName: search) { item, grams in
                            log(item, grams: grams)
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
                                LogPortionView(item: item) { grams in
                                    log(item, grams: grams)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
            Text("\(Int(item.energyKcal.rounded())) kcal per 100 g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func log(_ item: FoodItem, grams: Double) {
        FoodLogger.log(item, grams: grams, context: context)
        dismiss()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(matches[index])
        }
        try? context.save()
    }
}

/// Choose how much of an existing food to log.
private struct LogPortionView: View {
    var item: FoodItem
    var onLog: (Double) -> Void

    @State private var portionText: String = ""

    private var grams: Double? {
        guard let value = Double(portionText.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return value
    }

    var body: some View {
        Form {
            Section("Portion") {
                HStack {
                    TextField("Amount", text: $portionText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("g")
                        .foregroundStyle(.secondary)
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
                Button("Add") { onLog(grams ?? 0) }
                    .disabled(grams == nil)
            }
        }
        .onAppear {
            portionText = String(Int(item.defaultPortionGrams.rounded()))
        }
    }
}

/// Define a new food and log a portion of it in one pass.
private struct NewFoodView: View {
    var initialName: String
    var onCreate: (FoodItem, Double) -> Void

    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var portion = "100"
    @State private var energy = ""
    @State private var carbs = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var protein = ""
    @State private var fat = ""

    private var grams: Double? { positive(portion) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && grams != nil
    }

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name", text: $name)
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

            Section("Portion to log") {
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
            defaultPortionGrams: grams
        )
        context.insert(item)
        try? context.save()
        onCreate(item, grams)
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
