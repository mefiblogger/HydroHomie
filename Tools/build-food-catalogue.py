"""Turn CoFID into a bundled catalogue of generic foods.

CoFID is McCance and Widdowson's Composition of Foods Integrated Dataset,
published by the UK Department of Health and Social Care under the Open
Government Licence v3.0. Source:
https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid
"""
import json
import re
import sys

import openpyxl

SHEET = "1.3 Proximates"
COLS = {"name": 1, "protein": 9, "fat": 10, "carbs": 11,
        "kcal": 12, "sugar": 16, "fiber": 25}

# Refuse-weight duplicates ("weighed with bones") and prepared UK dishes are noise
# in a food picker: the first are the same food counted differently, the second are
# recipes rather than ingredients.
EXCLUDE = re.compile(
    r"weighed with|weighed without|homemade|retail|takeaway|restaurant|"
    r"recipe|purchased|reheated|school|nursery",
    re.I)

# No per-food cap. Trimming variants to save space cost Cheddar and boiled potatoes
# on the first attempt, while saving 40 KB out of 190 — a bad trade. Too many hits
# for "beef" is a search-ranking problem, not a reason to delete food.


def number(value):
    """CoFID uses 'Tr' for trace and 'N' for not measured."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if text in {"Tr", "tr", "trace"}:
        return 0.0
    if text in {"N", "n", ""}:
        return None
    try:
        return float(text.lstrip("<>~"))
    except ValueError:
        return None


def build(path):
    sheet = openpyxl.load_workbook(path, read_only=True, data_only=True)[SHEET]
    rows = sheet.iter_rows(values_only=True)
    for _ in range(3):
        next(rows)

    foods = []
    for row in rows:
        if row[0] is None:
            continue
        name = str(row[COLS["name"]]).strip()
        if EXCLUDE.search(name):
            continue
        kcal = number(row[COLS["kcal"]])
        if kcal is None:
            continue
        foods.append({
            "n": name,
            "kcal": round(kcal, 1),
            "carb": round(number(row[COLS["carbs"]]) or 0, 2),
            "sugar": round(number(row[COLS["sugar"]]) or 0, 2),
            "fiber": round(number(row[COLS["fiber"]]) or 0, 2),
            "prot": round(number(row[COLS["protein"]]) or 0, 2),
            "fat": round(number(row[COLS["fat"]]) or 0, 2),
        })

    bases = {food["n"].split(",")[0].strip().lower() for food in foods}
    foods.sort(key=lambda f: f["n"])
    return foods, len(bases)


if __name__ == "__main__":
    source = sys.argv[1] if len(sys.argv) > 1 else "cofid.xlsx"
    target = sys.argv[2] if len(sys.argv) > 2 else "GenericFoods.json"
    kept, bases = build(source)
    blob = json.dumps(kept, separators=(",", ":"), ensure_ascii=False)
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(blob)
    print(f"{len(kept)} foods across {bases} base foods -> {len(blob.encode())/1024:.0f} KB")
