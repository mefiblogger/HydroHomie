// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// The food library, reachable from Settings: browse, correct or remove the foods
/// you have defined. Editing here never touches what is already logged.
struct FoodLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var items: [FoodItem]

    @State private var search = ""
    @State private var creating = false

    private var matches: [FoodItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if matches.isEmpty {
                Section {
                    Text(items.isEmpty
                         ? "No foods yet. Foods you define while tracking show up here."
                         : "No food matches “\(search)”.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(matches) { item in
                    NavigationLink {
                        FoodEditorView(editing: item)
                    } label: {
                        FoodRow(item: item)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .searchable(text: $search, prompt: "Search your foods")
        .navigationTitle("Food library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label("New food", systemImage: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $creating) {
            FoodEditorView { _, _ in creating = false }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(matches[index])
        }
        try? context.save()
    }
}

/// Shared by the library and the tracking sheet.
struct FoodRow: View {
    var item: FoodItem

    var body: some View {
        HStack(spacing: 10) {
            Text(item.icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        let unit = item.measure.shortName
        let energy = String(localized: "\(Quantity.whole(item.energyKcal)) kcal per 100 \(unit)",
                            comment: "Energy density of a food, e.g. 52 kcal per 100 g")
        guard !item.availablePortions.isEmpty else { return energy }
        let measures = item.availablePortions
            .map {
                String(localized: "\($0.kind.singular) \(Quantity.whole($0.amount)) \(unit)",
                       comment: "A named portion and its size, e.g. bottle 500 ml")
            }
            .joined(separator: ", ")
        return "\(energy) · \(measures)"
    }
}

#Preview {
    NavigationStack {
        FoodLibraryView()
    }
    .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
