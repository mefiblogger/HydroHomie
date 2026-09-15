// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [UserSettings]

    private var appearance: AppAppearance { settingsRows.first?.appearance ?? .system }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "drop.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            // Make sure the settings row exists before any view reads it.
            _ = UserSettings.current(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget can log drinks while the app is backgrounded; pick those up.
            if phase == .active {
                context.processPendingChanges()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [DrinkEntry.self, FoodEntry.self, FoodItem.self, UserSettings.self], inMemory: true)
}
