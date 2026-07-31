#!/usr/bin/env bash
# Build Serene Driving for the iOS Simulator, install it and launch.
#   ./build-run.sh                 # default device
#   SD_DEVICE="iPhone 16" ./build-run.sh
set -euo pipefail

DEV="${SD_DEVICE:-iPhone 16 Pro}"
PROJ="$(cd "$(dirname "$0")" && pwd)"
APP="$PROJ/build/Debug-iphonesimulator/SereneDriving.app"
BUNDLE="company.lno.serenedriving"

echo "▶︎ Building…"
xcodebuild -project "$PROJ/SereneDriving.xcodeproj" -target SereneDriving \
  -sdk iphonesimulator -configuration Debug \
  CODE_SIGNING_ALLOWED=NO SYMROOT="$PROJ/build" build \
  | grep -E "error:|warning: [A-Z]|BUILD (SUCCEEDED|FAILED)" || true

echo "▶︎ Booting $DEV…"
xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" >/dev/null 2>&1 || true

echo "▶︎ Installing…"
xcrun simctl install "$DEV" "$APP"
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true

echo "▶︎ Launching…"
xcrun simctl launch "$DEV" "$BUNDLE" "$@"
