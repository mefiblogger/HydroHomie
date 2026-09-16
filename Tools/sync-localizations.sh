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
