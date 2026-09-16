# Tools

## build-food-catalogue.py

Regenerates `HydroHomie/Resources/GenericFoods.json` from CoFID.

```bash
curl -L -o cofid.xlsx \
  "https://assets.publishing.service.gov.uk/media/60538b91e90e07527df82ae4/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021..xlsx"
python3 Tools/build-food-catalogue.py cofid.xlsx HydroHomie/Resources/GenericFoods.json
```

Needs `openpyxl`. The generated file is committed, so building the app never
touches the network and any change to the catalogue is reviewable in a diff.

### Source and licence

CoFID — McCance and Widdowson's *The Composition of Foods Integrated Dataset*,
UK Department of Health and Social Care, 2021. Published under the
[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/),
which permits commercial use with attribution. The attribution appears in the
app under Settings and in the project README.

Chosen over USDA FoodData Central because its dairy fat classes, breads and
cereals match European products. USDA is public domain and would carry no
attribution obligation, but its figures describe US foods.

## Launch artwork

`HydroHomie/Resources/LaunchBackground{,@2x,@3x}.png` are rendered from a vector
source at a 430x932pt base — 1290x2796 at @3x, which covers the tallest iPhone
natively. To regenerate from a new PDF:

```bash
swift Tools/render-launch-artwork.swift launch.pdf HydroHomie/Resources/LaunchBackground.png 430 932
swift Tools/render-launch-artwork.swift launch.pdf HydroHomie/Resources/LaunchBackground@2x.png 860 1864
swift Tools/render-launch-artwork.swift launch.pdf HydroHomie/Resources/LaunchBackground@3x.png 1290 2796
```

Then bump `CFBundleVersion`: iOS caches the rendered launch screen per build and
will keep showing the old one otherwise.

They are loose bundle files rather than an asset catalog image on purpose — see
the README's design notes.

## Localization

User-visible strings live in String Catalogs:

| File | Covers |
|---|---|
| `HydroHomie/Localizable.xcstrings` | the app |
| `HydroHomieWidget/Localizable.xcstrings` | the widget (its own bundle, so its own catalog) |
| `HydroHomie/InfoPlist.xcstrings` | the camera and Health permission prompts |

`SWIFT_EMIT_LOC_STRINGS` is on for every target, so `Text`, `Label`, `Button`,
`Section` and `navigationTitle` literals are extracted automatically. Strings built
in code need an explicit `String(localized:)` — see `PortionKind` for the pattern.

After adding or changing a string, refresh the catalogs:

    ./Tools/sync-localizations.sh

Xcode only writes catalogs back from the IDE; `xcodebuild` extracts the strings but
does not merge them. The script does the merge with `xcstringstool sync`, so the
catalogs stay correct from the command line.

### Adding a language

1. Add the region to `knownRegions` in `project.pbxproj`.
2. Add a `"<code>"` entry under `localizations` for each string in the catalogs.
3. Optionally add `"<code>"` names to `HydroHomie/Resources/GenericFoods.json` —
   each food's `n` is a language map, and `CatalogFood.preferred(from:preferring:)`
   picks by `Locale.preferredLanguages` and falls back to English. Search matches
   every language's name, so a translated food is findable by either name.

No Swift changes are needed for any of this. Do steps 1 and 2 together: a region
with no translations makes iOS advertise a language that renders entirely in English.

### Things to watch

- **Numbers** go through `Quantity` (in `VolumeUnit.swift`), which is locale-aware —
  Hungarian writes `25,4` where English writes `25.4`. Never use `String(format:)`.
  `Quantity.locale` exists only so tests do not depend on the host's region.
- **Portion plurals** are two separate strings, `singular` and `plural`. Languages
  that keep the noun singular after a numeral — Hungarian says "10 darab", not
  "darabok" — translate both to the same word.
- **`rawValue` is never localized.** `PortionKind` and `FoodMeasure` raw values are
  persisted in `FoodEntry` and `NamedPortion`; they must mean the same thing in
  every language.
