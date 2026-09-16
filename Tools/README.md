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
