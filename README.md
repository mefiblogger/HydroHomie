# Water Tracker

A SwiftUI hydration tracker for iOS 17+, with Apple Health sync and an interactive
home screen widget.

## Requirements

- Xcode 26+ (iOS 26.5 SDK), iOS 17.0 deployment target
- No third-party dependencies

## Getting started

```bash
open WaterTracker.xcodeproj
```

Select the `WaterTracker` scheme and run. Building for the simulator needs no signing;
running on a device requires setting `DEVELOPMENT_TEAM` and registering the
`group.com.watertracker.app` App Group and HealthKit capability on your Apple
Developer account.

## Targets

| Target | Purpose |
|---|---|
| `WaterTracker` | The app — Today, History and Settings tabs |
| `WaterTrackerWidget` | Home screen widget (small + medium) with one-tap logging |
| `WaterTrackerTests` | Unit tests for unit conversion and daily aggregation |

## Layout

```
Shared/              compiled into both the app and the widget
  Models/            DrinkEntry, UserSettings, VolumeUnit
  Persistence/       SharedModelContainer, HydrationStore
  Intents/           AddDrinkIntent — backs the widget's quick-add buttons
  Assets.xcassets
WaterTracker/
  Views/             RootView, TodayView, HistoryView, SettingsView, ProgressRing, …
  Services/          HydrationLogger, HealthKitService, NotificationScheduler
WaterTrackerWidget/  widget bundle, timeline provider and widget views
Config/              Info.plists and entitlements for both bundles
```

## Design notes

**Everything is stored in millilitres.** `VolumeUnit` converts only at the display
layer, so switching between ml and fl oz never mutates stored data or accumulates
rounding drift.

**One SwiftData store, shared through an App Group.** `SharedModelContainer` points
the store at the `group.com.watertracker.app` container so the widget reads the same
data the app writes. It falls back to the target's own Application Support directory
when the entitlement isn't granted, so an unsigned build still runs.

**`HydrationLogger` is the single funnel** for adding and deleting drinks — haptics,
HealthKit mirroring and widget refresh all happen there, so behaviour is identical no
matter which screen originated the change.

**The widget writes directly to the store.** `AddDrinkIntent` runs in the widget's own
process, inserts the entry and reloads the timeline, so logging from the home screen
never launches the app.

## Tests

```bash
xcodebuild -project WaterTracker.xcodeproj -scheme WaterTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Not yet implemented

- Reminder scheduling is wired up but the permission flow hasn't been exercised end to end
- No app icon artwork — `AppIcon.appiconset` is an empty 1024×1024 slot
- HealthKit is write-only; nothing reads back water logged by other apps
