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
