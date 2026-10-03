#!/bin/bash
# =============================================================================
#  build_unsigned_ipa.sh
#  Astra AI — Build an unsigned .ipa for AltStore / Sideloadly sideloading
# =============================================================================
#  This script produces an UNSIGNED .ipa that can be signed and installed
#  using AltStore, Sideloadly, or similar sideloading tools.
#
#  Requirements:
#    - macOS with Xcode 16+
#    - No Apple Developer account needed
#
#  Usage:
#    ./scripts/build_unsigned_ipa.sh
# =============================================================================

set -e

PROJECT="AstraAI.xcodeproj"
SCHEME="AstraAI"
CONFIGURATION="Release"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
PAYLOAD_DIR="${BUILD_DIR}/direct-install"
OUTPUT_IPA="${BUILD_DIR}/AstraAI-unsigned.ipa"

echo "============================================================"
echo "  Astra AI — Unsigned IPA Builder (AltStore/Sideloadly)"
echo "============================================================"

# Step 1: Clean
echo ""
echo "→ Cleaning..."
rm -rf "${BUILD_DIR}/DerivedData" "${PAYLOAD_DIR}"
xcodebuild clean -project "${PROJECT}" -scheme "${SCHEME}" -configuration "${CONFIGURATION}" -quiet 2>/dev/null || true

# Step 2: Build without code signing
echo "→ Building (unsigned, CODE_SIGNING_ALLOWED=NO)..."
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

# Step 3: Locate the .app bundle
APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphoneos/AstraAI.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: AstraAI.app not found at ${APP_PATH}"
    exit 1
fi

echo "→ Found app bundle: ${APP_PATH}"

# Step 4: Remove code signature from the app (if present)
echo "→ Removing existing code signature..."
rm -rf "${APP_PATH}/_CodeSignature"

# Step 5: Package into .ipa
echo "→ Packaging unsigned .ipa..."
mkdir -p "${PAYLOAD_DIR}/Payload"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/Payload/"
cd "${PAYLOAD_DIR}"
zip -qry "AstraAI-unsigned.ipa" Payload
cd - > /dev/null

mv "${PAYLOAD_DIR}/AstraAI-unsigned.ipa" "${OUTPUT_IPA}"

echo ""
echo "============================================================"
echo "  UNSIGNED IPA CREATED"
echo "  Location: ${OUTPUT_IPA}"
echo "  Size: $(du -h "${OUTPUT_IPA}" | cut -f1)"
echo "============================================================"
echo ""
echo "  To install this .ipa:"
echo ""
echo "  Option A — AltStore:"
echo "    1. Install AltStore on your iPhone (https://altstore.io)"
echo "    2. Connect your iPhone to your Mac"
echo "    3. Open AltServer, select 'Sideload .ipa'"
echo "    4. Select ${OUTPUT_IPA}"
echo "    5. Enter your Apple ID when prompted"
echo ""
echo "  Option B — Sideloadly:"
echo "    1. Install Sideloadly (https://sideloadly.io)"
echo "    2. Open Sideloadly on your Mac/PC"
echo "    3. Drag ${OUTPUT_IPA} into Sideloadly"
echo "    4. Enter your Apple ID"
echo "    5. Click 'Start' and follow instructions"
echo ""
echo "  Option C — TrollStore (iOS 14-16, certain versions):"
echo "    1. Install TrollStore on your iPhone"
echo "    2. Open ${OUTPUT_IPA} in TrollStore"
echo "    3. Install — no Apple ID required"
echo ""
echo "  NOTE: Free Apple ID sideloading expires after 7 days."
echo "  Re-sideload after expiration, or use a paid developer account."
echo "============================================================"
