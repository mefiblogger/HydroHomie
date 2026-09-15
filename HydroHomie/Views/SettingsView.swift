// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    @State private var goalText: String = ""
    @State private var calorieText: String = ""
    @State private var incrementText: String = ""
    @State private var healthKitUnavailable = false
    @State private var calculating = false

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Goal", selection: weightGoalBinding) {
                        ForEach(WeightGoal.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    field("Water", text: $goalText, suffix: settings.unit.shortName,
                          onCommit: commitGoal)
                    field("Calories", text: $calorieText, suffix: "kcal",
                          onCommit: commitCalorieGoal)

                    Button {
                        calculating = true
                    } label: {
                        Label("Work out my goals", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Not sure what to aim for? The calculator estimates both from your height, weight and activity.")
                }

                Section {
                    field("Amount", text: $incrementText, suffix: settings.unit.shortName,
                          onCommit: commitIncrement)
                } header: {
                    Text("Quick add")
                } footer: {
                    Text("How much the water buttons add or remove. Press and hold the add button for a one-off amount.")
                }

                Section("Units") {
                    Picker("Water", selection: unitBinding) {
                        ForEach(VolumeUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        FoodLibraryView()
                    } label: {
                        Label("Food library", systemImage: "carrot")
                    }
                } header: {
                    Text("Food")
                } footer: {
                    Text("Correcting a food changes it from now on. Anything already logged keeps the figures it was logged with.")
                }

                Section("Reminders") {
                    Toggle("Remind me to drink", isOn: remindersBinding)
                    if settings.remindersEnabled {
                        Stepper(
                            "Every \(settings.reminderIntervalHours) h",
                            value: intervalBinding,
                            in: 1...6
                        )
                        Picker("From", selection: startHourBinding) {
                            ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                        }
                        Picker("Until", selection: endHourBinding) {
                            ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                        }
                    }
                }

                Section {
                    Toggle("Sync to Apple Health", isOn: healthKitBinding)
                } header: {
                    Text("Health")
                } footer: {
                    Text(healthKitUnavailable
                         ? "Apple Health isn't available on this device."
                         : "New entries are written to Health as dietary water.")
                }

                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    // The Open Government Licence requires attribution; this is it.
                    Text(FoodCatalog.attribution)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $calculating) {
                EnergyCalculatorView(
                    settings: settings,
                    goal: settings.weightGoal,
                    unit: settings.unit
                ) { result in
                    apply(result)
                }
            }
            .onAppear(perform: loadFields)
            .onChange(of: settings.unitRawValue) { _, _ in loadFields() }
            .onDisappear(perform: commitFields)
        }
    }

    // MARK: - Bindings

    private var unitBinding: Binding<VolumeUnit> {
        Binding(
            get: { settings.unit },
            set: { newValue in
                commitFields()
                settings.unit = newValue
                save()
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { settings.remindersEnabled },
            set: { newValue in
                Task {
                    if newValue {
                        let granted = await NotificationScheduler.requestAuthorization()
                        guard granted else { return }
                    }
                    settings.remindersEnabled = newValue
                    save()
                    await NotificationScheduler.reschedule(from: settings)
                }
            }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { settings.reminderIntervalHours },
            set: { settings.reminderIntervalHours = $0; saveAndReschedule() }
        )
    }

    private var startHourBinding: Binding<Int> {
        Binding(
            get: { settings.reminderStartHour },
            set: { settings.reminderStartHour = $0; saveAndReschedule() }
        )
    }

    private var endHourBinding: Binding<Int> {
        Binding(
            get: { settings.reminderEndHour },
            set: { settings.reminderEndHour = $0; saveAndReschedule() }
        )
    }

    private var healthKitBinding: Binding<Bool> {
        Binding(
            get: { settings.healthKitEnabled },
            set: { newValue in
                Task {
                    if newValue {
                        let ok = await HealthKitService.shared.requestAuthorization()
                        healthKitUnavailable = !ok
                        guard ok else { return }
                    }
                    settings.healthKitEnabled = newValue
                    save()
                }
            }
        )
    }

    private var weightGoalBinding: Binding<WeightGoal> {
        Binding(
            get: { settings.weightGoal },
            set: { settings.weightGoal = $0; save() }
        )
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { settings.appearance },
            set: { settings.appearance = $0; save() }
        )
    }

    // MARK: - Field plumbing

    /// A label with a trailing numeric field and a unit suffix.
    private func field(
        _ title: String,
        text: Binding<String>,
        suffix: String,
        onCommit: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onSubmit(onCommit)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }

    private func loadFields() {
        goalText = formattedVolume(settings.dailyGoalML)
        calorieText = String(Int(settings.dailyCalorieGoal.rounded()))
        incrementText = formattedVolume(settings.waterIncrementML)
    }

    /// Fields commit on submit, but also when the screen goes away with the keyboard
    /// still up — otherwise an edit in progress would be silently dropped.
    private func commitFields() {
        commitGoal()
        commitCalorieGoal()
        commitIncrement()
    }

    // MARK: - Helpers

    private func formattedVolume(_ millilitres: Double) -> String {
        let value = settings.unit.fromMillilitres(millilitres)
        return settings.unit == .millilitres
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }

    private func parsed(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return value
    }

    /// Fills in both goals and remembers the measurements, so reopening the
    /// calculator does not mean typing it all again.
    private func apply(_ result: EnergyCalculatorView.Result) {
        settings.dailyCalorieGoal = result.calories.rounded()
        settings.dailyGoalML = result.waterML
        settings.bodyWeightKg = result.weightKg
        settings.bodyHeightCm = result.heightCm
        settings.age = result.age
        settings.sex = result.sex
        settings.activity = result.activity
        save()
        loadFields()
    }

    private func commitGoal() {
        // An untouched field holds its own rounded display value. Writing that back
        // would re-derive the stored amount from a 1-decimal string, so 2000 ml
        // becomes 1999 after one trip through fl oz. Only commit real edits.
        guard goalText != formattedVolume(settings.dailyGoalML) else { return }
        guard let value = parsed(goalText) else {
            goalText = formattedVolume(settings.dailyGoalML)
            return
        }
        settings.dailyGoalML = settings.unit.toMillilitres(value)
        save()
    }

    private func commitCalorieGoal() {
        guard calorieText != String(Int(settings.dailyCalorieGoal.rounded())) else { return }
        guard let value = parsed(calorieText) else {
            calorieText = String(Int(settings.dailyCalorieGoal.rounded()))
            return
        }
        settings.dailyCalorieGoal = value
        save()
    }

    private func commitIncrement() {
        guard incrementText != formattedVolume(settings.waterIncrementML) else { return }
        guard let value = parsed(incrementText) else {
            incrementText = formattedVolume(settings.waterIncrementML)
            return
        }
        settings.waterIncrementML = settings.unit.toMillilitres(value)
        save()
    }

    private func save() {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveAndReschedule() {
        save()
        Task { await NotificationScheduler.reschedule(from: settings) }
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
