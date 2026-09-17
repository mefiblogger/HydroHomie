#!/bin/bash
# Refresh the String Catalogs from the source.
#
# Xcode updates .xcstrings from the IDE only; xcodebuild extracts the strings but
# never writes them back. This builds, then merges the extracted .stringsdata into
# the catalogs so the catalogs stay correct from the command line too.
#
# Run it after adding or changing any user-visible string.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED=${DERIVED:-build}
DEST=${DEST:-'platform=iOS Simulator,name=iPhone 17'}

xcodebuild -project HydroHomie.xcodeproj -scheme HydroHomie \
    -destination "$DEST" -derivedDataPath "$DERIVED" build >/dev/null

INTERMEDIATES="$DERIVED/Build/Intermediates.noindex/HydroHomie.build/Debug-iphonesimulator"

for target in HydroHomie HydroHomieWidget; do
    data=("$INTERMEDIATES/$target.build/Objects-normal/arm64"/*.stringsdata)
    xcrun xcstringstool sync "$target/Localizable.xcstrings" --stringsdata "${data[@]}"
    echo "synced $target/Localizable.xcstrings"
done

# Report coverage, so a string added without a translation is visible rather than
# silently falling back to English at runtime.
python3 - "$@" <<'PYTHON'
import json, pathlib, sys

incomplete = False
for path in ["HydroHomie/Localizable.xcstrings",
             "HydroHomieWidget/Localizable.xcstrings",
             "HydroHomie/InfoPlist.xcstrings"]:
    strings = json.loads(pathlib.Path(path).read_text())["strings"]
    langs = {l for e in strings.values() for l in e.get("localizations", {})} - {"en"}
    for lang in sorted(langs):
        missing = [k for k, e in strings.items()
                   if lang not in e.get("localizations", {})]
        review = [k for k, e in strings.items()
                  if e.get("localizations", {}).get(lang, {})
                       .get("stringUnit", {}).get("state") == "needs_review"]
        print(f"{path} [{lang}]: {len(strings) - len(missing)}/{len(strings)} translated"
              f", {len(review)} awaiting review")
        for k in missing[:10]:
            incomplete = True
            print(f"    UNTRANSLATED {k!r}")
        if len(missing) > 10:
            print(f"    ... and {len(missing) - 10} more")

sys.exit(1 if incomplete else 0)
PYTHON
