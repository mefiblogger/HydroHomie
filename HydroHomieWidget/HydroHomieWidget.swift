import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct HydrationEntry: TimelineEntry {
    var date: Date
    var totalML: Double
    var goalML: Double
    var unit: VolumeUnit

    var progress: Double { goalML > 0 ? totalML / goalML : 0 }

    static let placeholder = HydrationEntry(
        date: Date(), totalML: 1250, goalML: 2000, unit: .millilitres
    )
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        Task { @MainActor in completion(currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        Task { @MainActor in
            let entry = currentEntry()
            // Refresh at the next midnight so the ring resets with the new day.
            let midnight = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    @MainActor
    private func currentEntry() -> HydrationEntry {
        let context = SharedModelContainer.shared.mainContext
        let entries = (try? context.fetch(HydrationStore.entriesDescriptor(on: Date()))) ?? []
        let settings = (try? context.fetch(FetchDescriptor<UserSettings>()).first) ?? nil

        return HydrationEntry(
            date: Date(),
            totalML: HydrationStore.total(of: entries),
            goalML: settings?.dailyGoalML ?? 2000,
            unit: settings?.unit ?? .millilitres
        )
    }
}

struct HydroHomieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydroHomieWidget", provider: HydrationProvider()) { entry in
            HydroHomieWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hydration")
        .description("Today's water intake, with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HydroHomieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HydrationEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 18) {
                ring
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.unit.format(millilitres: entry.totalML))
                        .font(.title2.weight(.bold))
                    Text("of \(entry.unit.format(millilitres: entry.goalML))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    quickAddButtons
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(spacing: 8) {
                ring
                Button(intent: AddDrinkIntent(amountML: 250)) {
                    Label("250 ml", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(entry.progress, 1))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int((entry.progress * 100).rounded()))%")
                .font(.callout.weight(.bold))
                .minimumScaleFactor(0.6)
        }
        .frame(width: 74, height: 74)
    }

    private var quickAddButtons: some View {
        HStack(spacing: 6) {
            ForEach([250.0, 500.0], id: \.self) { amount in
                Button(intent: AddDrinkIntent(amountML: amount)) {
                    Text("+\(Int(entry.unit.fromMillilitres(amount).rounded()))")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    HydroHomieWidget()
} timeline: {
    HydrationEntry.placeholder
}
