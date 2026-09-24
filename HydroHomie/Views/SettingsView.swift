// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    @State private var goalText: String = ""
    @State private var calorieText: String = ""
    @State private var incrementText: String = ""
    @State private var healthKitUnavailable = false
    @State private var calculating = false
    /// Most recently edited first. The macro nobody has touched lately absorbs the
    /// difference, which is what makes an exact split reachable.
    @State private var macroRecency: [Macro] = Macro.allCases

    @State private var exporting = false
    @State private var importing = false
    @State private var backupFile: BackupFile?
    /// Held between picking a file and confirming, so nothing is written until the
    /// user has seen what is in it.
    @State private var pendingImport: (archive: BackupArchive, summary: BackupSummary)?
    @State private var backupMessage: BackupMessage?

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
                    field("Calories", text: $calorieText,
                          suffix: String(localized: "kcal", comment: "Kilocalories, abbreviated"),
                          onCommit: commitCalorieGoal)

                    ForEach(Macro.allCases) { macro in
                        macroRow(macro)
                    }

                    Button {
                        calculating = true
                    } label: {
                        Label("Work out my goals", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Macros split the calorie target and always total 100% — adjusting one moves the macro you changed least recently. They show on Today; only calories and water count toward goal tracking.")
                        if let macroNote {
                            Text(macroNote)
                                .foregroundStyle(Color.over)
                        }
                    }
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
                         : "New entries are written to Health: water, and the energy and nutrients of anything you log as food.")
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
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export a backup", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Restore from a backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("A backup holds everything: your log, your food library, your goals and your settings. Restoring adds what is missing and never removes anything already here.")
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
            .task {
                // Ask for the nutrition types if this install predates them. HealthKit
                // shows nothing when every type is already decided, so this is silent
                // for everyone else.
                guard settings.healthKitEnabled,
                      await !HealthKitService.shared.isAuthorizedForNutrition
                else { return }
                _ = await HealthKitService.shared.requestAuthorization()
            }
            .onChange(of: settings.unitRawValue) { _, _ in loadFields() }
            .onDisappear(perform: commitFields)
            .fileExporter(
                isPresented: $exporting,
                document: backupFile,
                contentType: .json,
                defaultFilename: backupFile?.suggestedFilename
            ) { result in
                if case .failure = result {
                    backupMessage = .init(text: String(localized: "Couldn't write the backup.",
                                                       comment: "Export failure"))
                }
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.json]
            ) { result in
                inspect(result)
            }
            // Deliberately a confirmation rather than an immediate restore: the user
            // sees what the file holds before anything touches the store.
            .alert("Restore this backup?", isPresented: restoreConfirmationBinding) {
                Button("Cancel", role: .cancel) { pendingImport = nil }
                Button("Restore") { performImport() }
            } message: {
                Text(pendingImport.map(describe) ?? "")
            }
            .alert("Backup", isPresented: backupMessageBinding) {
                Button("OK", role: .cancel) { backupMessage = nil }
            } message: {
                Text(backupMessage?.text ?? "")
            }
        }
    }

    // MARK: - Backup

    private var restoreConfirmationBinding: Binding<Bool> {
        Binding(get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } })
    }

    private var backupMessageBinding: Binding<Bool> {
        Binding(get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } })
    }

    private func prepareExport() {
        do {
            let archive = try BackupService.export(from: context, appVersion: appVersion)
            backupFile = BackupFile(archive: archive, data: try archive.encoded())
            exporting = true
        } catch {
            backupMessage = .init(text: String(localized: "Couldn't build the backup.",
                                               comment: "Export failure"))
        }
    }

    /// Reads and validates the picked file. Nothing is written yet — this only
    /// decides whether there is something worth confirming.
    private func inspect(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }

        // A file picked from Files or iCloud Drive lives outside the sandbox.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let archive = try BackupArchive.decoded(from: try Data(contentsOf: url))
            guard !archive.isEmpty else { throw BackupError.empty }
            pendingImport = (archive, BackupService.summarize(archive))
        } catch {
            backupMessage = .init(
                text: (error as? BackupError)?.errorDescription
                    ?? String(localized: "Couldn't read that file.", comment: "Import failure")
            )
        }
    }

    private func performImport() {
        guard let pending = pendingImport else { return }
        pendingImport = nil
        do {
            let result = try BackupService.restore(pending.archive, into: context)
            loadFields()
            WidgetCenter.shared.reloadAllTimelines()
            backupMessage = .init(text: describe(result))
        } catch {
            backupMessage = .init(text: String(localized: "Couldn't restore that backup.",
                                               comment: "Import failure"))
        }
    }

    /// Built a line at a time, each with its own count, so every language gets its
    /// own plural rule instead of an "1 foods" produced by concatenation.
    private func describe(_ pending: (archive: BackupArchive, summary: BackupSummary)) -> String {
        let summary = pending.summary
        var lines: [String] = []

        let entries = String(localized: "\(summary.totalEntries) entries",
                             comment: "Number of log entries in a backup")
        if let earliest = summary.earliest, let latest = summary.latest {
            let range = earliest.formatted(date: .abbreviated, time: .omitted)
                + " – " + latest.formatted(date: .abbreviated, time: .omitted)
            lines.append(String(localized: "\(entries) from \(range)",
                                comment: "Log entries and the dates they span"))
        } else {
            lines.append(entries)
        }

        lines.append(String(localized: "\(summary.foodItems) foods",
                            comment: "Number of library foods in a backup"))
        if summary.hasSettings {
            lines.append(String(localized: "Goals and settings",
                                comment: "A backup also carries these"))
        }
        return lines.joined(separator: "\n")
    }

    private func describe(_ result: ImportResult) -> String {
        guard !result.isEmpty else {
            return String(localized: "Everything in that backup was already here.",
                          comment: "Import added nothing")
        }
        let added = result.drinkEntries + result.foodEntries + result.foodItems
        // Reporting "0 entries and 0 foods" would understate an import that did
        // restore the settings, which is the common case for a second run.
        guard added > 0 else {
            return String(
                localized: "Your goals and settings were restored. Everything else was already here.",
                comment: "Import restored only the settings")
        }
        let entries = String(localized: "\(result.drinkEntries + result.foodEntries) entries",
                             comment: "Number of log entries in a backup")
        let foods = String(localized: "\(result.foodItems) foods",
                           comment: "Number of library foods in a backup")
        return String(localized: "Restored \(entries) and \(foods).",
                      comment: "What an import added")
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
                // @MainActor because this touches @State and a SwiftData model; a bare
                // Task here is not guaranteed to inherit the main actor.
                Task { @MainActor in
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

    private func macroRow(_ macro: Macro) -> some View {
        let percent = settings.macroSplit[macro]
        return Stepper(value: Binding(
            get: { percent },
            set: { setMacro(macro, to: $0) }
        ), in: 0...100, step: 5) {
            HStack {
                Text(macro.displayName)
                Spacer(minLength: 8)
                Text("\(Int(percent))%")
                    .monospacedDigit()
                    // Amber when outside the usual band — a note, not an error.
                    .foregroundStyle(settings.macroSplit.placement(of: macro) == .usual
                                     ? Color.primary : Color.over)
                Text("· \(Int(settings.macroGrams(macro).rounded())) g")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }

    /// Names any macro outside the usual guidance band, so an aggressive split reads
    /// as a choice rather than a slip.
    private var macroNote: String? {
        let split = settings.macroSplit
        let odd = split.unusual
        guard !odd.isEmpty else { return nil }

        let parts = odd.map { macro -> String in
            let range = macro.usualRange
            let name = macro.displayName.lowercased()
            let low = Int(range.lowerBound), high = Int(range.upperBound)
            return split.placement(of: macro) == .below
                ? String(localized: "\(name) below the usual \(low)–\(high)%",
                         comment: "One item in the unusual-macro list")
                : String(localized: "\(name) above the usual \(low)–\(high)%",
                         comment: "One item in the unusual-macro list")
        }
        // Joining with ", " and "and" is English punctuation; ListFormatter knows
        // what each locale actually does.
        let list = parts.formatted(.list(type: .and))
        return String(localized: "This split puts \(list). Fine if that is deliberate.",
                      comment: "Note shown when a macro split sits outside the usual range")
    }

    private func setMacro(_ macro: Macro, to percent: Double) {
        // Whichever of the other two was edited longest ago takes the difference.
        let absorber = macroRecency.last { $0 != macro } ?? Macro.allCases.first { $0 != macro }!
        settings.macroSplit = settings.macroSplit.setting(macro, to: percent, absorbedBy: absorber)
        macroRecency = [macro] + macroRecency.filter { $0 != macro }
        save()
    }

    private var weightGoalBinding: Binding<WeightGoal> {
        Binding(
            get: { settings.weightGoal },
            set: { settings.weightGoal = $0; save(); recordGoalChange() }
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
        _ title: LocalizedStringKey,
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
            ? Quantity.whole(value)
            : Quantity.oneDecimal(value)
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
        recordGoalChange()
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
        recordGoalChange()
    }

    private func commitCalorieGoal() {
        guard calorieText != String(Int(settings.dailyCalorieGoal.rounded())) else { return }
        guard let value = parsed(calorieText) else {
            calorieText = String(Int(settings.dailyCalorieGoal.rounded()))
            return
        }
        settings.dailyCalorieGoal = value
        save()
        recordGoalChange()
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

    /// Goal changes take effect tomorrow, so that how last month scored stays put.
    private func recordGoalChange() {
        GoalHistory.record(settings.resolvedGoal, in: context)
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
