// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// One food the model found, paired with what the catalogue made of it.
///
/// The match is a guess on top of a guess — the model's reading of the meal, then a
/// name lookup against formal CoFID descriptors — so every line stays editable and
/// nothing is logged until the user says so.
struct MealLine: Identifiable {
    let id = UUID()
    /// What the model heard, kept so the user can see why a row says what it says.
    var heard: String
    var candidates: [CatalogFood]
    var chosen: CatalogFood?
    var grams: Double

    var nutrients: Nutrients? {
        chosen.map { $0.nutrients.scaled(to: grams) }
    }
}

/// Review what was recognised, fix what is wrong, then log it.
struct RecognisedMealView: View {
    var foods: [RecognisedFood]
    var loggingOn: Date
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    @State private var lines: [MealLine] = []
    @State private var searching: MealLine.ID?

    private var usable: [MealLine] { lines.filter { $0.chosen != nil } }

    private var totalCalories: Double {
        usable.compactMap(\.nutrients?.energyKcal).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                ForEach($lines) { $line in
                    MealLineRow(line: $line) { searching = line.id }
                }
                .onDelete { lines.remove(atOffsets: $0) }
            } header: {
                Text("Recognised")
            } footer: {
                Text("Estimated from what you described. Check the amounts — a portion is the easiest thing to get wrong.")
            }

            if !usable.isEmpty {
                Section {
                    LabeledContent("Total",
                                   value: String(localized: "\(Quantity.whole(totalCalories)) kcal",
                                                 comment: "An energy amount, e.g. 240 kcal"))
                    .font(.headline)
                }
            }
        }
        .navigationTitle("Check and add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { logAll() }
                    .disabled(usable.isEmpty)
            }
        }
        .sheet(item: Binding(
            get: { searching.flatMap { id in lines.first { $0.id == id } } },
            set: { if $0 == nil { searching = nil } }
        )) { line in
            FoodChooser(line: line) { picked in
                if let index = lines.firstIndex(where: { $0.id == line.id }) {
                    lines[index].chosen = picked
                }
                searching = nil
            }
        }
        .onAppear(perform: buildLines)
    }

    private func buildLines() {
        guard lines.isEmpty else { return }
        lines = foods.map { food in
            let candidates = FoodCatalog.bestMatches(for: food.name)
            return MealLine(
                heard: food.name,
                candidates: candidates,
                // Best guess preselected, but the alternatives stay one tap away:
                // the top match is frequently not the right one.
                chosen: candidates.first,
                grams: food.grams
            )
        }
    }

    /// Each line becomes a library food and a logged portion, exactly as picking the
    /// same food from the catalogue by hand would — so nothing downstream can tell
    /// these entries came from the model.
    private func logAll() {
        let settings = settingsRows.first ?? UserSettings()
        for line in usable {
            guard let food = line.chosen else { continue }
            let item = FoodItem(name: food.name, per100g: food.nutrients, icon: .default)
            context.insert(item)
            FoodLogger.log(
                item, grams: line.grams, count: 0, kind: nil,
                at: HydrationStore.timestamp(loggingOn: loggingOn),
                settings: settings, context: context
            )
        }
        onDone()
    }
}

// MARK: - Row

private struct MealLineRow: View {
    @Binding var line: MealLine
    var onSearch: () -> Void

    @State private var gramsText = ""

    var body: some View {
        HStack(spacing: 10) {
            Text(FoodIcon.default.rawValue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    ForEach(line.candidates) { candidate in
                        Button(candidate.name) { line.chosen = candidate }
                    }
                    Divider()
                    Button("Search the food database", systemImage: "magnifyingglass", action: onSearch)
                } label: {
                    HStack(spacing: 4) {
                        Text(line.chosen?.name ?? String(localized: "No match",
                                                         comment: "Recognised food the catalogue has no entry for"))
                            .font(.subheadline)
                            .foregroundStyle(line.chosen == nil ? Color.over : .primary)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                // What the model heard, when the match renamed it — so a surprising
                // row can be understood rather than just distrusted.
                if line.chosen?.name.localizedCaseInsensitiveContains(line.heard) != true {
                    Text(String(localized: "heard “\(line.heard)”",
                                comment: "The term the model produced for a food"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let nutrients = line.nutrients {
                    Text(String(localized: "\(Quantity.whole(nutrients.energyKcal)) kcal",
                                comment: "An energy amount, e.g. 240 kcal"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            TextField("0", text: $gramsText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .onChange(of: gramsText) { _, new in
                    if let value = Double(new.replacingOccurrences(of: ",", with: ".")), value > 0 {
                        line.grams = value
                    }
                }
            Text(verbatim: "g")
                .foregroundStyle(.secondary)
        }
        .onAppear { gramsText = Quantity.whole(line.grams) }
    }
}

// MARK: - Replacing a match

/// Full catalogue search, for when none of the candidates is the food.
private struct FoodChooser: View {
    var line: MealLine
    var onPick: (CatalogFood) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [CatalogFood] {
        query.isEmpty ? line.candidates : FoodCatalog.search(query)
    }

    var body: some View {
        NavigationStack {
            List(results) { food in
                Button {
                    onPick(food)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).foregroundStyle(.primary)
                        Text(String(localized: "\(Quantity.whole(food.nutrients.energyKcal)) kcal per 100 \(FoodMeasure.grams.shortName)",
                                    comment: "Energy density of a food, e.g. 52 kcal per 100 g"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: Text("Search foods or scan a barcode"))
            .navigationTitle(line.heard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension MealLine: Equatable {
    static func == (a: MealLine, b: MealLine) -> Bool { a.id == b.id }
}
