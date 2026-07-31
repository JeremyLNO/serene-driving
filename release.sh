#!/usr/bin/env bash
# Archive Serene Driving and upload it to TestFlight from this Mac.
#
# Needs an App Store Connect API key. Point at your own key file and issuer —
# nothing is stored in the repo:
#
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export ASC_KEY_PATH="$HOME/Library/CloudStorage/GoogleDrive-.../AuthKey_${ASC_KEY_ID}.p8"
#   ./release.sh
#
# Build number defaults to a timestamp so every upload is unique.
set -euo pipefail

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to your AuthKey_*.p8}"

PROJ="$(cd "$(dirname "$0")" && pwd)"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%y%m%d%H%M)}"
ARCHIVE="$PROJ/build/SereneDriving.xcarchive"

echo "▶︎ Archiving (build $BUILD_NUMBER)…"
xcodebuild archive \
  -project "$PROJ/SereneDriving.xcodeproj" \
  -scheme SereneDriving \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "▶︎ Exporting and uploading to TestFlight…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$PROJ/ExportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "✅ Uploaded. It shows up in App Store Connect → TestFlight after processing."
