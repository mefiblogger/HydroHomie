import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allEntries: [DrinkEntry]
    @Query private var settingsRows: [UserSettings]

    @State private var range: HistoryRange = .week

    private var settings: UserSettings { settingsRows.first ?? UserSettings() }
    private var unit: VolumeUnit { settings.unit }

    private var totals: [DailyTotal] {
        HydrationStore.dailyTotals(from: allEntries, lastDays: range.days)
    }

    private var average: Double {
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0) { $0 + $1.totalML } / Double(totals.count)
    }

    private var daysGoalMet: Int {
        totals.filter { $0.totalML >= settings.dailyGoalML }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    chart
                        .frame(height: 220)
                        .padding(.vertical, 8)
                }

                Section("Summary") {
                    LabeledContent("Daily average", value: unit.format(millilitres: average))
                    LabeledContent("Goal met", value: "\(daysGoalMet) of \(range.days) days")
                }

                Section("All entries") {
                    if allEntries.isEmpty {
                        Text("No entries yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allEntries) { entry in
                            HStack {
                                Text(unit.format(millilitres: entry.amountML))
                                Spacer()
                                Text(entry.timestamp, format: .dateTime.day().month().hour().minute())
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private var chart: some View {
        Chart(totals) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Intake", unit.fromMillilitres(day.totalML))
            )
            .foregroundStyle(
                day.totalML >= settings.dailyGoalML
                    ? Color.teal.gradient
                    : Color.accentColor.gradient
            )
            .cornerRadius(4)

            RuleMark(y: .value("Goal", unit.fromMillilitres(settings.dailyGoalML)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
        }
        .chartYAxisLabel(unit.shortName)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range.axisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: range.axisFormat, centered: true)
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            HydrationLogger.delete(allEntries[index], context: context)
        }
    }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        }
    }

    var axisStride: Int {
        switch self {
        case .week: 1
        case .month: 5
        }
    }

    var axisFormat: Date.FormatStyle {
        switch self {
        case .week: .dateTime.weekday(.narrow)
        case .month: .dateTime.day()
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [DrinkEntry.self, UserSettings.self], inMemory: true)
}
