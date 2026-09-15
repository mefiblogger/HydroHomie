// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CustomAmountSheet: View {
    var unit: VolumeUnit
    var onAdd: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var fieldFocused: Bool

    private var parsedML: Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return unit.toMillilitres(value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text(unit.shortName)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Enter how much you drank in \(unit.shortName).")
                }
            }
            .navigationTitle("Custom amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let ml = parsedML {
                            onAdd(ml)
                            dismiss()
                        }
                    }
                    .disabled(parsedML == nil)
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.height(220)])
    }
}
