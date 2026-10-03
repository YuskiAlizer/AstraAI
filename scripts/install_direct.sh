#!/bin/bash
# =============================================================================
#  install_direct.sh
#  Astra AI — Install directly on a connected iPhone via Xcode
# =============================================================================
#  This script builds the app and installs it directly on a connected iPhone.
#  No .ipa file needed — Xcode installs the signed app directly.
#
#  Requirements:
#    - macOS with Xcode 16+
#    - iPhone connected via USB and trusted
#    - Apple ID configured in Xcode → Settings → Accounts
#    - Your Apple ID added as a development team
#
#  Usage:
#    ./scripts/install_direct.sh [TEAM_ID]
#
#  If TEAM_ID is omitted, uses automatic signing (Xcode picks the team).
# =============================================================================

set -e

PROJECT="AstraAI.xcodeproj"
SCHEME="AstraAI"
TEAM_ID="${1:-}"
BUILD_DIR="build"

echo "============================================================"
echo "  Astra AI — Direct Device Install"
if [ -n "${TEAM_ID}" ]; then
    echo "  Team ID: ${TEAM_ID}"
else
    echo "  Team: automatic"
fi
echo "============================================================"

# Check for connected devices
echo ""
echo "→ Checking for connected devices..."
DEVICES=$(xcrun devicectl list devices --json 2>/dev/null || echo "")
if [ -z "${DEVICES}" ] || echo "${DEVICES}" | grep -q "No devices"; then
    echo "WARNING: No connected device detected."
    echo "  Make sure your iPhone is:"
    echo "  - Connected via USB"
    echo "  - Unlocked"
    echo "  - Trusted (tap 'Trust This Computer' on the iPhone)"
    echo ""
    echo "  Continue anyway? (y/N)"
    read -r CONTINUE
    if [ "${CONTINUE}" != "y" ] && [ "${CONTINUE}" != "Y" ]; then
        exit 0
    fi
fi

# Step 1: Build for the connected device
echo ""
echo "→ Building for device..."
BUILD_ARGS=(
    -project "${PROJECT}"
    -scheme "${SCHEME}"
    -configuration "Debug"
    -destination "generic/platform=iOS"
    -derivedDataPath "${BUILD_DIR}/DerivedData"
    build
)

if [ -n "${TEAM_ID}" ]; then
    BUILD_ARGS+=("DEVELOPMENT_TEAM=${TEAM_ID}")
fi

xcodebuild "${BUILD_ARGS[@]}"

# Step 2: Find the built .app
APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Debug-iphoneos/AstraAI.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: AstraAI.app not found at ${APP_PATH}"
    exit 1
fi

echo ""
echo "→ App built successfully: ${APP_PATH}"

# Step 3: Install on device
echo "→ Installing on connected device..."

# Try using devicectl (Xcode 16+)
DEVICE_ID=$(xcrun devicectl list devices --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    devices = data.get('result', {}).get('devices', [])
    for d in devices:
        if d.get('connectionProperties', {}).get('transportType') == 'wired':
            print(d.get('hardwareProperties', {}).get('udid', ''))
            break
except:
    pass
" 2>/dev/null)

if [ -n "${DEVICE_ID}" ]; then
    echo "  Device UDID: ${DEVICE_ID}"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP_PATH}"
    echo ""
    echo "============================================================"
    echo "  APP INSTALLED SUCCESSFULLY"
    echo "  Find Astra AI on your iPhone's home screen."
    echo "============================================================"
else
    echo "  Could not detect device via devicectl."
    echo "  Falling back to manual installation..."
    echo ""
    echo "  Open Xcode → Window → Devices and Simulators"
    echo "  Drag this app onto your device:"
    echo "  ${APP_PATH}"
    echo ""
    echo "  Or use the iOS app deployment tool:"
    echo "  ios-deploy --bundle ${APP_PATH}"
    echo ""
    echo "  To install ios-deploy: npm install -g ios-deploy"
fi
