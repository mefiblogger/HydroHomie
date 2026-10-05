// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Type what you ate, in any language, and let the on-device model work out what
/// the foods are.
struct DescribeFoodView: View {
    var loggingOn: Date
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var thinking = false
    @State private var failure: String?
    @State private var recognised: RecognisedMeal?
    @FocusState private var focused: Bool

    private var status: RecogniserStatus { FoodRecogniser.status }

    var body: some View {
        NavigationStack {
            Form {
                if status.isReady {
                    Section {
                        TextField("Cheeseburger with fries", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                            .focused($focused)
                            .submitLabel(.done)
                            .disabled(thinking)
                    } footer: {
                        Text("Describe the meal in your own words, in any language. Everything stays on your phone.")
                    }

                    Section {
                        Button {
                            Task { await recognise() }
                        } label: {
                            HStack {
                                Text("Work out the food")
                                Spacer()
                                if thinking { ProgressView() }
                            }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespaces).count < 3 || thinking)
                    }
                } else {
                    Section {
                        UnavailableNotice(status: status)
                    }
                }

                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Describe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $recognised) { meal in
                RecognisedMealView(foods: meal.foods, loggingOn: loggingOn) {
                    onDone()
                    dismiss()
                }
            }
            .task {
                guard status.isReady else { return }
                try? await Task.sleep(for: .milliseconds(120))
                focused = true
            }
        }
    }

    private func recognise() async {
        focused = false
        thinking = true
        failure = nil
        defer { thinking = false }

        do {
            let foods = try await FoodRecogniser.recognise(description: text)
            guard !foods.isEmpty else { throw RecogniserError.nothingRecognised }
            recognised = RecognisedMeal(foods: foods)
        } catch {
            failure = (error as? RecogniserError)?.errorDescription
                ?? RecogniserError.failed.errorDescription
        }
    }
}

/// Why recognition cannot run, phrased for what the user can actually do about it.
struct UnavailableNotice: View {
    var status: RecogniserStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "sparkles")
                .font(.headline)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            // Only offered when there is something to go and do.
            if status == .notEnabled, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        switch status {
        case .notEnabled:
            String(localized: "Apple Intelligence is off", comment: "Recognition unavailable")
        case .modelNotReady:
            String(localized: "Apple Intelligence is getting ready", comment: "Recognition unavailable")
        default:
            String(localized: "Not available on this device", comment: "Recognition unavailable")
        }
    }

    private var detail: String {
        switch status {
        case .notEnabled:
            String(localized: "Switch it on in Settings to describe or photograph a meal. Everything is worked out on your phone.",
                   comment: "Recognition unavailable")
        case .modelNotReady:
            String(localized: "The model is still downloading. Try again in a little while.",
                   comment: "Recognition unavailable")
        case .systemTooOld:
            String(localized: "Working out a meal from a description needs a newer version of iOS. Search the food database instead.",
                   comment: "Recognition unavailable")
        default:
            String(localized: "This iPhone can't run Apple Intelligence. Search the food database instead.",
                   comment: "Recognition unavailable")
        }
    }
}
