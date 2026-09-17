// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// Suggests daily calorie and water targets from body measurements.
///
/// Nothing is applied unless the user accepts it, and the inputs are remembered so
/// the estimate can be revisited without typing it all again.
struct EnergyCalculatorView: View {
    /// What the calculator produced, plus the inputs, so Settings can remember them.
    struct Result {
        var calories: Double
        var waterML: Double
        var weightKg: Double
        var heightCm: Double
        var age: Int
        var sex: BiologicalSex
        var activity: ActivityLevel
    }

    var goal: WeightGoal
    var unit: VolumeUnit
    var onAccept: (Result) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sex: BiologicalSex
    @State private var activity: ActivityLevel
    @State private var weight: String
    @State private var height: String
    @State private var age: String

    init(
        settings: UserSettings,
        goal: WeightGoal,
        unit: VolumeUnit,
        onAccept: @escaping (Result) -> Void
    ) {
        self.goal = goal
        self.unit = unit
        self.onAccept = onAccept
        _sex = State(initialValue: settings.sex)
        _activity = State(initialValue: settings.activity)
        _weight = State(initialValue: settings.bodyWeightKg > 0
                        ? String(Int(settings.bodyWeightKg.rounded())) : "")
        _height = State(initialValue: settings.bodyHeightCm > 0
                        ? String(Int(settings.bodyHeightCm.rounded())) : "")
        _age = State(initialValue: settings.age > 0 ? String(settings.age) : "")
    }

    // Bounded, so a mistyped digit cannot produce a confident-looking nonsense
    // target. A 180 cm height typed into the wrong field reads as 18030.
    private var weightKg: Double? { inRange(weight, 20...400) }
    private var heightCm: Double? { inRange(height, 50...250) }
    private var years: Int? {
        guard let value = Int(age), (10...120).contains(value) else { return nil }
        return value
    }

    private var estimate: (calories: Double, water: Double)? {
        guard let weightKg, let heightCm, let years else { return nil }
        return (
            EnergyEstimate.dailyCalories(
                sex: sex, weightKg: weightKg, heightCm: heightCm,
                age: years, activity: activity, goal: goal
            ),
            EnergyEstimate.dailyWaterML(weightKg: weightKg, activity: activity)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    field("Weight", text: $weight,
                          suffix: String(localized: "kg", comment: "Kilograms, abbreviated"))
                    field("Height", text: $height,
                          suffix: String(localized: "cm", comment: "Centimetres, abbreviated"))
                    field("Age", text: $age,
                          suffix: String(localized: "years", comment: "Unit after an age"))
                } header: {
                    Text("About you")
                } footer: {
                    Text("Sex and age are needed for the Mifflin–St Jeor equation, which is what produces the estimate.")
                }

                Section("Activity") {
                    Picker("Activity", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.displayName)
                                Text(level.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    if let estimate {
                        LabeledContent("Calories",
                                       value: "\(Int(estimate.calories.rounded())) kcal")
                        LabeledContent("Water",
                                       value: unit.format(millilitres: estimate.water))
                        LabeledContent("Goal", value: goal.displayName)
                    } else {
                        Text(prompt)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Suggested daily targets")
                } footer: {
                    Text("An estimate from population averages, adjusted for your goal. Individual needs vary — treat it as a starting point, and talk to a doctor or dietitian if you have health conditions or specific targets.")
                }
            }
            .navigationTitle("Work out my goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use these") {
                        guard let estimate, let weightKg, let heightCm, let years else { return }
                        onAccept(Result(
                            calories: estimate.calories,
                            waterML: estimate.water,
                            weightKg: weightKg,
                            heightCm: heightCm,
                            age: years,
                            sex: sex,
                            activity: activity
                        ))
                        dismiss()
                    }
                    .disabled(estimate == nil)
                }
            }
        }
    }

    /// Names the field that is wrong rather than saying "fill it in" at someone who
    /// already has.
    private var prompt: String {
        if weightKg == nil && !weight.isEmpty {
            return String(localized: "That weight looks wrong — expected 20 to 400 kg.",
                          comment: "Validation message")
        }
        if heightCm == nil && !height.isEmpty {
            return String(localized: "That height looks wrong — expected 50 to 250 cm.",
                          comment: "Validation message")
        }
        if years == nil && !age.isEmpty {
            return String(localized: "That age looks wrong — expected 10 to 120.",
                          comment: "Validation message")
        }
        return String(localized: "Fill in weight, height and age to see a suggestion.",
                      comment: "Prompt shown until the calculator has enough input")
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }

    private func inRange(_ text: String, _ range: ClosedRange<Double>) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              range.contains(value) else { return nil }
        return value
    }
}
