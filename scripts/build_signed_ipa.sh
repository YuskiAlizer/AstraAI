#!/bin/bash
# =============================================================================
#  build_signed_ipa.sh
#  Astra AI — Build a signed .ipa for direct installation via Xcode or Ad Hoc
# =============================================================================
#  This script produces a SIGNED .ipa using your Apple Developer certificate.
#  Works with both free (personal) and paid Apple Developer accounts.
#
#  Requirements:
#    - macOS with Xcode 16+
#    - Apple ID (free or paid developer account)
#    - iPhone UDID registered if using Ad Hoc distribution
#
#  Usage:
#    ./scripts/build_signed_ipa.sh <TEAM_ID> [BUNDLE_ID] [METHOD]
#
#  Arguments:
#    TEAM_ID   — Your Apple Developer Team ID (e.g., ABCDE12345)
#    BUNDLE_ID — (Optional) Custom bundle ID. Default: com.astraai.app
#    METHOD    — (Optional) "development" or "ad-hoc". Default: development
#
#  Examples:
#    ./scripts/build_signed_ipa.sh ABCDE12345
#    ./scripts/build_signed_ipa.sh ABCDE12345 com.myname.astraai development
#    ./scripts/build_signed_ipa.sh ABCDE12345 com.myname.astraai ad-hoc
# =============================================================================

set -e

# Parse arguments
TEAM_ID="${1:?Usage: $0 <TEAM_ID> [BUNDLE_ID] [METHOD]}"
BUNDLE_ID="${2:-com.astraai.app}"
METHOD="${3:-development}"

PROJECT="AstraAI.xcodeproj"
SCHEME="AstraAI"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/AstraAI.xcarchive"
IPA_DIR="${BUILD_DIR}/ipa"
EXPORT_OPTIONS="DirectInstall/ExportOptions-${METHOD}.plist"

echo "============================================================"
echo "  Astra AI — Signed IPA Builder"
echo "  Team ID:   ${TEAM_ID}"
echo "  Bundle ID: ${BUNDLE_ID}"
echo "  Method:    ${METHOD}"
echo "============================================================"

# Validate export options file
if [ ! -f "${EXPORT_OPTIONS}" ]; then
    echo "ERROR: Export options file not found: ${EXPORT_OPTIONS}"
    echo "Available methods: development, ad-hoc"
    exit 1
fi

# Step 1: Create a temporary export options plist with the actual team ID
TEMP_EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions-temp.plist"
mkdir -p "${BUILD_DIR}"
sed "s/YOUR_TEAM_ID/${TEAM_ID}/g" "${EXPORT_OPTIONS}" > "${TEMP_EXPORT_OPTIONS}"

# For ad-hoc, also update the bundle ID in provisioning profiles
if [ "${METHOD}" = "ad-hoc" ]; then
    sed -i '' "s/com.astraai.app/${BUNDLE_ID}/g" "${TEMP_EXPORT_OPTIONS}" 2>/dev/null || \
    sed -i "s/com.astraai.app/${BUNDLE_ID}/g" "${TEMP_EXPORT_OPTIONS}"
fi

# Step 2: Clean
echo ""
echo "→ Cleaning..."
rm -rf "${ARCHIVE_PATH}" "${IPA_DIR}"
xcodebuild clean -project "${PROJECT}" -scheme "${SCHEME}" -quiet 2>/dev/null || true

# Step 3: Archive
echo "→ Archiving (signed with team ${TEAM_ID})..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
  CODE_SIGN_STYLE=Automatic \
  -quiet

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "ERROR: Archive failed"
    exit 1
fi

# Step 4: Export signed .ipa
echo "→ Exporting signed .ipa (method: ${METHOD})..."
mkdir -p "${IPA_DIR}"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${TEMP_EXPORT_OPTIONS}" \
  -exportPath "${IPA_DIR}" \
  -quiet

# Clean up temp file
rm -f "${TEMP_EXPORT_OPTIONS}"

# Step 5: Find and rename the .ipa
IPA_FILE=$(find "${IPA_DIR}" -name "*.ipa" -type f | head -1)
if [ -z "${IPA_FILE}" ]; then
    echo "ERROR: No .ipa file found in export output"
    exit 1
fi

FINAL_IPA="${BUILD_DIR}/AstraAI-${METHOD}.ipa"
mv "${IPA_FILE}" "${FINAL_IPA}"

echo ""
echo "============================================================"
echo "  SIGNED IPA CREATED"
echo "  Location: ${FINAL_IPA}"
echo "  Size: $(du -h "${FINAL_IPA}" | cut -f1)"
echo "============================================================"
echo ""
echo "  Installation methods:"
echo ""
echo "  1. Xcode direct install:"
echo "     - Connect your iPhone via USB"
echo "     - Open Xcode → Window → Devices and Simulators"
echo "     - Select your iPhone"
echo "     - Drag ${FINAL_IPA} into 'Installed Apps' section"
echo ""
echo "  2. Apple Configurator:"
echo "     - Open Apple Configurator 2"
echo "     - Connect your iPhone"
echo "     - Drag ${FINAL_IPA} onto the device"
echo ""
echo "  3. OTA (Ad Hoc only, requires HTTPS server):"
echo "     - Host the .ipa on an HTTPS server"
echo "     - Create an itms-services manifest plist"
echo "     - Open the manifest URL on your iPhone"
echo ""
if [ "${METHOD}" = "development" ]; then
    echo "  NOTE: Free Apple ID certificates expire after 7 days."
    echo "  Rebuild after expiration or use a paid developer account."
fi
echo "============================================================"
