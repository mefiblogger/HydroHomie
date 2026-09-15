// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allEntries: [DrinkEntry]
    @Query private var settingsRows: [UserSettings]

    @State private var showingCustomAmount = false

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }
    private var unit: VolumeUnit { settings.unit }

    private var todaysEntries: [DrinkEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDateInToday($0.timestamp) }
    }

    private var total: Double { HydrationStore.total(of: todaysEntries) }
    private var goal: Double { max(settings.dailyGoalML, 1) }
    private var progress: Double { total / goal }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    ring
                    QuickAddRow(unit: unit) { amount in
                        add(amount)
                    } onCustom: {
                        showingCustomAmount = true
                    }
                    recentEntries
                }
                .padding()
            }
            .navigationTitle("Today")
            .sheet(isPresented: $showingCustomAmount) {
                CustomAmountSheet(unit: unit) { amount in
                    add(amount)
                }
            }
        }
    }

    private var ring: some View {
        ZStack {
            ProgressRing(progress: progress)
            VStack(spacing: 4) {
                Text(unit.format(millilitres: total))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("of \(unit.format(millilitres: goal))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if progress >= 1 {
                    Label("Goal reached", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.goal)
                        .padding(.top, 2)
                }
            }
        }
        .frame(width: 230, height: 230)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var recentEntries: some View {
        if todaysEntries.isEmpty {
            ContentUnavailableView(
                "Nothing logged yet",
                systemImage: "drop",
                description: Text("Tap an amount above to start tracking today.")
            )
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's log")
                    .font(.headline)
                ForEach(todaysEntries) { entry in
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(unit.format(millilitres: entry.amountML))
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                        Button {
                            delete(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete entry")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func add(_ amountML: Double) {
        HydrationLogger.add(amountML: amountML, settings: settings, context: context)
    }

    private func delete(_ entry: DrinkEntry) {
        HydrationLogger.delete(entry, context: context)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [DrinkEntry.self, UserSettings.self], inMemory: true)
}
