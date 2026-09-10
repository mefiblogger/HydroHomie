import SwiftData
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    @State private var goalText: String = ""
    @State private var healthKitUnavailable = false

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    HStack {
                        TextField("Goal", text: $goalText)
                            .keyboardType(.decimalPad)
                            .onSubmit(commitGoal)
                        Text(settings.unit.shortName)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Units", selection: unitBinding) {
                        ForEach(VolumeUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
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

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                goalText = formattedGoal
            }
            .onChange(of: settings.unitRawValue) { _, _ in
                goalText = formattedGoal
            }
            .onDisappear(perform: commitGoal)
        }
    }

    // MARK: - Bindings

    private var unitBinding: Binding<VolumeUnit> {
        Binding(
            get: { settings.unit },
            set: { newValue in
                commitGoal()
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

    // MARK: - Helpers

    private var formattedGoal: String {
        let value = settings.unit.fromMillilitres(settings.dailyGoalML)
        return settings.unit == .millilitres
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }

    private func commitGoal() {
        guard let value = Double(goalText.replacingOccurrences(of: ",", with: ".")),
              value > 0 else {
            goalText = formattedGoal
            return
        }
        settings.dailyGoalML = settings.unit.toMillilitres(value)
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
        .modelContainer(for: [DrinkEntry.self, UserSettings.self], inMemory: true)
}
