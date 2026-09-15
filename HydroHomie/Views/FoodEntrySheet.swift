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
    /// A catalogue food the user picked. Built but not inserted — it only joins the
    /// library if they go through with logging it.
    @State private var picked: FoodItem?

    @State private var scanning = false
    @State private var lookingUp = false
    @State private var lookupError: String?
    /// A product from Open Food Facts, on its way to the editor for checking.
    @State private var scanned: RemoteFood?
    @State private var online: [RemoteFood] = []
    @State private var searchingOnline = false
    @State private var onlineError: String?

    private var matches: [FoodItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var catalogueMatches: [CatalogFood] {
        // Anything already in the library is offered above; no point listing it twice.
        let mine = Set(items.map { $0.name.lowercased() })
        return FoodCatalog.search(search).filter { !mine.contains($0.name.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        scanning = true
                    } label: {
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }

                    NavigationLink {
                        FoodEditorView(creatingNamed: search) { item, grams in
                            log(item, grams: grams ?? item.defaultPortionGrams,
                                count: 0, kind: nil)
                        }
                    } label: {
                        Label("New food", systemImage: "plus.circle.fill")
                    }
                }

                if matches.isEmpty && catalogueMatches.isEmpty && online.isEmpty {
                    Section {
                        Text(items.isEmpty && search.isEmpty
                             ? "Your food library is empty. Scan a barcode, search, or add a food."
                             : "No food matches “\(search)”.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !matches.isEmpty {
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

                if !catalogueMatches.isEmpty {
                    Section {
                        ForEach(catalogueMatches) { food in
                            Button {
                                picked = FoodItem(
                                    name: food.name,
                                    per100g: food.nutrients,
                                    icon: .default
                                )
                            } label: {
                                CatalogRow(food: food)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Food database")
                    } footer: {
                        Text("Generic foods bundled with the app. Logging one adds it to your library, where you can rename or correct it.")
                    }
                }

                if search.trimmingCharacters(in: .whitespaces).count >= 3 {
                    Section {
                        if searchingOnline {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Searching…").foregroundStyle(.secondary)
                            }
                        } else if let onlineError {
                            Label(onlineError, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if online.isEmpty {
                            Button {
                                Task { await searchOnline() }
                            } label: {
                                Label("Search branded products", systemImage: "magnifyingglass")
                            }
                        }
                        ForEach(online) { food in
                            Button {
                                scanned = food
                            } label: {
                                RemoteRow(food: food)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Open Food Facts")
                    } footer: {
                        Text("Branded products, contributed by the public. Check the figures against the packaging before logging.")
                    }
                }
            }
            .searchable(text: $search, prompt: "Search foods")
            .navigationTitle("Track food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if lookingUp {
                    ProgressView("Looking up…")
                        .padding(24)
                        .background(.regularMaterial, in: .rect(cornerRadius: 14))
                }
            }
            .navigationDestination(item: $editing) { item in
                FoodEditorView(editing: item)
            }
            .navigationDestination(item: $picked) { item in
                LogPortionView(item: item) { grams, count, kind in
                    // Only now does it become one of the user's own foods.
                    context.insert(item)
                    log(item, grams: grams, count: count, kind: kind)
                }
            }
            .navigationDestination(item: $scanned) { food in
                FoodEditorView(
                    creatingNamed: food.displayName,
                    nutrients: food.nutrients,
                    barcode: food.barcode,
                    missing: food.missing
                ) { item, grams in
                    log(item, grams: grams ?? item.defaultPortionGrams, count: 0, kind: nil)
                }
            }
            .sheet(isPresented: $scanning) {
                BarcodeScannerView { code in
                    Task { await lookUp(code) }
                }
            }
            .alert("Barcode", isPresented: .constant(lookupError != nil)) {
                Button("OK") { lookupError = nil }
            } message: {
                Text(lookupError ?? "")
            }
            .onChange(of: search) { _, _ in
                online = []
                onlineError = nil
            }
            // On submit rather than per keystroke: Open Food Facts rate limits search
            // to roughly ten a minute, and typing would burn that in seconds.
            .onSubmit(of: .search) {
                Task { await searchOnline() }
            }
        }
    }

    private func searchOnline() async {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3, !searchingOnline else { return }

        searchingOnline = true
        onlineError = nil
        defer { searchingOnline = false }
        do {
            let results = try await OpenFoodFacts.search(query)
            let mine = Set(items.map { $0.name.lowercased() })
            online = results.filter { !mine.contains($0.displayName.lowercased()) }
            if online.isEmpty {
                onlineError = "Nothing found for “\(query)”."
            }
        } catch {
            onlineError = (error as? OpenFoodFacts.LookupError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    private func lookUp(_ barcode: String) async {
        lookingUp = true
        defer { lookingUp = false }
        do {
            scanned = try await OpenFoodFacts.lookup(barcode: barcode)
        } catch {
            lookupError = (error as? OpenFoodFacts.LookupError)?.errorDescription
                ?? error.localizedDescription
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

/// A product from Open Food Facts, with whatever the contributors filled in.
private struct RemoteRow: View {
    var food: RemoteFood

    var body: some View {
        HStack(spacing: 10) {
            Text(FoodIcon.default.rawValue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.displayName)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(Int(food.nutrients.energyKcal.rounded())) kcal per 100 g")
                    if !food.missing.isEmpty {
                        Text("· incomplete")
                            .foregroundStyle(Color.over)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// A catalogue result: nutrition only, no portions of its own yet.
private struct CatalogRow: View {
    var food: CatalogFood

    var body: some View {
        HStack(spacing: 10) {
            Text(FoodIcon.default.rawValue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .foregroundStyle(.primary)
                Text("\(Int(food.nutrients.energyKcal.rounded())) kcal per 100 g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
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
