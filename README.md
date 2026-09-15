# HydroHomie

A SwiftUI hydration tracker for iOS 17+, with Apple Health sync and an interactive
home screen widget.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

<p>
  <img src="docs/today-light.png" width="300" alt="Today screen, light appearance">
  <img src="docs/today-dark.png" width="300" alt="Today screen, dark appearance">
</p>

## Features

- Two dashboard-style gauges counting down to your daily goals — calories outside,
  water inside; tap the readout to turn it over and see what you have had so far
- Add or remove water in one tap; press and hold the add button for an exact amount
- A configurable quick-add amount, so the buttons match the glass you actually use
- One log for the day, water and food together
- A compact macro panel tracking carbs, protein and fat against daily targets
- A food library you build up, logged by portion, with carbs, sugar, fibre,
  protein, fat and energy held per 100 g
- Foods are weighed or measured by volume: grams for solids, millilitres for
  drinks, with portions to match
- Named portions per food — define a grape's "piece" as 2 g, or a juice's
  "glass" as 250 ml, and log 10 pieces or 2 glasses
- An icon per food, chosen from a set of emoji
- Foods are editable, from Settings or while tracking — without disturbing
  anything already logged
- ~1,900 generic foods bundled with the app: searchable offline, no account,
  no API key, no network
- Barcode scanning, or type an EAN straight into the search field
- Branded-product search via Open Food Facts
- History with a 7- or 30-day chart, daily average and goal-met count
- Millilitres or US fluid ounces, switchable at any time without touching stored data
- Configurable reminders through the day
- Optional Apple Health sync, written as dietary water — and retracted when you undo
- Home screen widget, small and medium, carrying the same gauge and buttons —
  medium adds the macro panel
- Light, dark or system appearance

## Requirements

- Xcode 26+ (iOS 26.5 SDK), iOS 17.0 deployment target
- No third-party dependencies

## Getting started

```bash
open HydroHomie.xcodeproj
```

Select the `HydroHomie` scheme and run. Building for the simulator needs no signing;
running on a device requires setting `DEVELOPMENT_TEAM` and registering the
`group.com.hydrohomie.app` App Group and HealthKit capability on your Apple
Developer account.

## Targets

| Target | Purpose |
|---|---|
| `HydroHomie` | The app — Today, History and Settings tabs |
| `HydroHomieWidget` | Home screen widget (small + medium) with one-tap logging |
| `HydroHomieTests` | Unit tests for unit conversion and daily aggregation |

## Layout

```
Shared/              compiled into both the app and the widget
  Models/            DrinkEntry, UserSettings, VolumeUnit
  Persistence/       SharedModelContainer, HydrationStore
  Intents/           AddDrinkIntent — backs the widget's quick-add buttons
  Assets.xcassets
HydroHomie/
  Views/             RootView, TodayView, HistoryView, SettingsView, ProgressRing, …
  Services/          HydrationLogger, HealthKitService, NotificationScheduler
HydroHomieWidget/  widget bundle, timeline provider and widget views
Config/              Info.plists and entitlements for both bundles
```

## Design notes

**Everything is stored in millilitres.** `VolumeUnit` converts only at the display
layer, so switching between ml and fl oz never mutates stored data or accumulates
rounding drift.

**One SwiftData store, shared through an App Group.** `SharedModelContainer` points
the store at the `group.com.hydrohomie.app` container so the widget reads the same
data the app writes. It falls back to the target's own Application Support directory
when the entitlement isn't granted, so an unsigned build still runs.

**`HydrationLogger` is the single funnel** for adding and deleting drinks — haptics,
HealthKit mirroring and widget refresh all happen there, so behaviour is identical no
matter which screen originated the change.

**Colour lives in the asset catalog, not in code.** `AccentColor` (#7B3BA5), `GoalColor`
and `RingTrack` each define a light and a dark variant, and `Shared/Theme.swift`
exposes the latter two as `Color.goal` / `Color.ringTrack`. The catalog is compiled
into both the app and the widget, so a colour change lands in both at once. The
dark accent is a lightened #A870CC — the base purple is too dark to read against a
black ground.

**Appearance is a stored preference.** Settings offers System / Light / Dark, applied
with `.preferredColorScheme`. Note this governs the app only: widgets always follow
the system appearance, so a phone in light mode shows a light widget even when the
app is pinned to dark.

**The gauges fill up but the numbers count down.** Both arcs grow as you consume, which
keeps them legible as a pair, while the labels read "550 kcal left" / "500 ml left".
A literally draining calorie ring would have been full at breakfast — visually identical
to the water ring's goal-reached state, meaning the opposite thing.

**Exceeding the two goals means opposite things**, so the overflow arcs are tinted
separately: water past its goal is a win (`GoalColor`), calories past theirs is not
(`OverColor`).

**Settings fields only write back when actually edited.** A field holds its own rounded
display value, so committing an untouched one re-derives the stored amount from a
1-decimal string — 2000 ml becomes 1999 after a single trip through fl oz. The guard in
`commitGoal()` and friends exists for that reason; do not remove it.

**Nutrition is held per 100 g.** That is how both USDA FoodData Central and Open
Food Facts report it, so a future lookup against either can populate a `FoodItem`
with no conversion. Portions scale from there.

**Sugar and fibre are subsets of carbohydrate**, not siblings — never sum the three.

**The bundled catalogue is read-only and separate from your library.** ~1,900 generic
foods ship in `HydroHomie/Resources/GenericFoods.json` (202 KB), generated from CoFID
by `Tools/build-food-catalogue.py`. Searching offers your own foods first and the
catalogue below; logging a catalogue food copies it into your library, where it
becomes editable like any other. Seeding all 1,900 into SwiftData instead would have
drowned your own foods and made them deletable by accident.

**The catalogue ships uncurated on purpose.** An earlier pass trimmed it to ~800 by
ranking foods for "everydayness". It deleted Cheddar, boiled potatoes, cow's milk and
hen's eggs — the heuristic rewarded short names, so sheep's milk beat whole milk — to
save 40 KB out of 190. The median base food has exactly one variant, so the noise that
curation was meant to fix barely existed. `FoodCatalogTests` now pins the staples it
lost.

**Open Food Facts is queried live, never bundled.** Results are cached only as the
user's own `FoodItem`s, so the database's ODbL share-alike never attaches to this
project — which it would the moment a derived copy shipped inside the app.

**The search field doubles as a barcode field.** A scan just fills it in; anything
that is 8, 12, 13 or 14 digits and nothing else is treated as a barcode. That gives
one input rather than two paths, lets a barcode be typed or pasted, and means a scan
first matches *your own* foods — library items keep the barcode they were created
from, so re-scanning something finds your copy, with your portions, before it reaches
the internet.

**Search there happens on submit, not per keystroke.** Open Food Facts rate limits
search far harder than barcode lookup, around ten a minute; typing would burn that in
seconds and earn a 503. Barcode lookups are not throttled the same way, so they resolve on their own
without a submit.

**Check the HTTP status before parsing.** A throttled request returns a 503 whose body
is not JSON; without the status check that parsed as an empty result and looked
identical to "no such product", which is how the first version silently showed nothing.

**Scanned products land in the editor, not the log.** Open Food Facts is
crowd-sourced and often partial — of five Hungarian products sampled while building
this, two had no sugar or fibre and one reported 541 kcal against 0 carbs and 0
protein. The editor names what is missing so it can be corrected against the packaging.

**Why CoFID and not USDA.** USDA FoodData Central is public domain and would carry no
attribution obligation at all, which suits a dual-licensed project better. CoFID was
chosen anyway because its dairy fat classes, breads and cereals describe European
products. Neither contains Hungarian staples; no open dataset does. That gap is for
barcode lookup to close, not a composition table.

**Food icons are emoji, not SF Symbols.** The symbol library carries only fourteen
food and drink glyphs, and they are mostly vessels — of the categories worth offering
a food tracker, exactly one (`carrot.fill`) has an honest match. There is no burger,
pasta, candy, chocolate, chips or fruit, and `apple.*` is the company logo. Emoji
cover the lot at the cost of not being tintable: they render from a bitmap colour
font, so `foregroundStyle` is ignored.

**A food knows whether it is weighed or poured.** Nutrition is per 100 g for solids
and per 100 ml for drinks — the arithmetic is identical, so `FoodMeasure` only decides
what the figures are called and which portions are offered: no piece of juice, no bowl
of rice. The entry snapshots the measure too, so a juice logged in millilitres stays in
millilitres even if the library entry is later switched.

**Stored property names still say "grams" and are left that way on purpose.**
`portionGrams` and `defaultPortionGrams` hold grams *or* millilitres depending on the
food; `portionAmount` and `defaultPortionAmount` are computed aliases that read
honestly at the call site. Renaming the stored properties — even with
`@Attribute(originalName:)` — coincided with every `FoodEntry` row disappearing during
development, while `FoodItem` survived the identical change. The cause was never
pinned down, so schema changes to the log are additive only. A food library can be
rebuilt; a log cannot.

**Named portions are per food, not global.** A "piece" means 2 g for grapes and 30 g
for biscuits, so the weight lives on the `FoodItem` rather than on the `PortionKind`.
Logging records both the count and the kind alongside the resolved weight, so the log
can say "10 pieces" while the nutrition still comes from grams.

**A logged `FoodEntry` is a snapshot, not a reference.** It copies the scaled figures —
and the name, portion and icon — rather than pointing at its `FoodItem`. Correcting a
food's nutrition later cannot silently rewrite what you ate last week, and deleting it
cannot void the log. The `itemID` is kept only so "log it again" can find the source.
`EditingDoesNotRewriteHistoryTests` pins this for every field; it is the one property
of the model worth breaking a build over.

**The widget writes directly to the store.** `AddDrinkIntent` runs in the widget's own
process, inserts the entry and reloads the timeline, so adding water from the home
screen never launches the app. Logging food does need a form, so `TrackFoodIntent`
opens the app instead and leaves a `PendingAction` in the shared defaults, which
`RootView` consumes on activation and turns into the food sheet.

**The gauge, readout and macro panel live in `Shared/Views`** and are compiled into
both targets, so the widget cannot drift from the app. Each takes a `Metrics` value
for type and spacing; the readout also takes a layout, because side-by-side columns
need about 120pt of clear space inside the rings and a widget gauge has half that.

**Use `Color.brand`, never `Color.accentColor`.** Inside a widget extension the latter
resolves to the system tint rather than the asset, which silently turned every purple
in the widget blue.

## Tests

```bash
xcodebuild -project HydroHomie.xcodeproj -scheme HydroHomie \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Not yet implemented

- Barcode scanning is written but unverified: the Simulator has no camera, so it
  has only been exercised through its unavailable state. It needs a run on a device
- Sugar and fibre are tracked but have no home on the Today screen; only carbs,
  protein and fat appear in the macro panel
- History charts water only
- Macro goals have sensible defaults but no Settings UI to change them yet
- The Settings appearance picker does not affect the widget (see above)
- Reminder scheduling is wired up but the permission flow hasn't been exercised end to end
- No app icon artwork — `AppIcon.appiconset` is an empty 1024×1024 slot
- HealthKit is write-only; nothing reads back water logged by other apps

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Note
that contributions carry a licence grant, for the reason explained there.

## Licence

HydroHomie is free software, licensed under the
[GNU General Public License v3.0 or later](LICENSE).

You may use, study, share and modify it. If you distribute it or a derivative, you
must pass on the same freedoms and publish your complete corresponding source under
the GPL.

A **commercial licence** is available for anyone who wants to build on HydroHomie
without those obligations — including shipping a proprietary derivative on the App
Store, whose terms conflict with the GPL. See
[COMMERCIAL-LICENSING.md](COMMERCIAL-LICENSING.md).

Copyright (C) 2026 mefiblogger.
