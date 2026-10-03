#!/bin/bash
# Build script for Astra AI — compiles the project and generates a .ipa
# Usage: ./build.sh [development|adhoc|appstore]

set -e

METHOD=${1:-development}
PROJECT="AstraAI.xcodeproj"
SCHEME="AstraAI"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/AstraAI.xcarchive"
IPA_PATH="${BUILD_DIR}/ipa"

echo "============================================"
echo "  Astra AI Build Script"
echo "  Method: ${METHOD}"
echo "============================================"

# Clean
echo "→ Cleaning..."
xcodebuild clean -project "${PROJECT}" -scheme "${SCHEME}" -quiet

# Archive
echo "→ Archiving..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination "generic/platform=iOS" \
  -quiet

# Export
echo "→ Exporting IPA..."
mkdir -p "${IPA_PATH}"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "${IPA_PATH}" \
  -quiet

echo "============================================"
echo "  Build complete!"
echo "  IPA location: ${IPA_PATH}/"
echo "============================================"
ls -la "${IPA_PATH}/"
