// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [UserSettings]

    @State private var selectedTab = Tab.today
    @State private var foodEntryRequested = false

    private enum Tab { case today, history, settings }

    private var appearance: AppAppearance { settingsRows.first?.appearance ?? .system }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(foodEntryRequested: $foodEntryRequested)
                .tabItem { Label("Today", systemImage: "drop.fill") }
                .tag(Tab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(Tab.history)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            // Make sure the settings row exists before any view reads it.
            _ = UserSettings.current(in: context)
            handOverFromWidget()
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget can log drinks while the app is backgrounded; pick those up.
            if phase == .active {
                context.processPendingChanges()
                handOverFromWidget()
            }
        }
    }
    /// The widget's food button opens the app and leaves a request behind, because
    /// a widget cannot present a form itself.
    private func handOverFromWidget() {
        guard PendingAction.consume() == .trackFood else { return }
        selectedTab = .today
        foodEntryRequested = true
    }
}

#Preview {
    RootView()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
