#!/bin/bash
set -e

APP_NAME="ClaudeNotify"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building ${APP_NAME}...
Usage: ./build.sh [macOS version]  (default: 14.0)
  ./build.sh 14.0   # macOS 14 Sonoma+
  ./build.sh 15.0   # macOS 15 Sequoia+
"

# Create app bundle structure
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy Info.plist and icon
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/"
cp "${SCRIPT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/"

# Determine deployment target
MIN_MACOS="${1:-14.0}"
echo "Target: macOS ${MIN_MACOS}+ (universal binary)"

# Compile for Apple Silicon
swiftc "${SCRIPT_DIR}/ClaudeNotify.swift" \
    -o "${MACOS_DIR}/${APP_NAME}-arm64" \
    -target arm64-apple-macosx${MIN_MACOS} \
    -framework Cocoa \
    -framework UserNotifications \
    -framework ApplicationServices \
    -F /System/Library/PrivateFrameworks \
    -framework SkyLight

# Compile for Intel
swiftc "${SCRIPT_DIR}/ClaudeNotify.swift" \
    -o "${MACOS_DIR}/${APP_NAME}-x86_64" \
    -target x86_64-apple-macosx${MIN_MACOS} \
    -framework Cocoa \
    -framework UserNotifications \
    -framework ApplicationServices \
    -F /System/Library/PrivateFrameworks \
    -framework SkyLight

# Create universal binary
lipo -create \
    "${MACOS_DIR}/${APP_NAME}-arm64" \
    "${MACOS_DIR}/${APP_NAME}-x86_64" \
    -output "${MACOS_DIR}/${APP_NAME}"
rm "${MACOS_DIR}/${APP_NAME}-arm64" "${MACOS_DIR}/${APP_NAME}-x86_64"

# Code sign
codesign --force --sign - --options runtime \
    --entitlements "${SCRIPT_DIR}/ClaudeNotify.entitlements" \
    "${APP_DIR}"

# Register with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_DIR}"

echo ""
echo "Build complete: ${APP_DIR}"
echo ""
echo "[Required] After build, toggle ClaudeNotify OFF then ON in:"
echo "  System Settings > Privacy & Security > Accessibility"
echo ""
echo "[First time] Grant notification permission when prompted."
echo "[First time] Grant Terminal automation when prompted:"
echo "  open ${APP_DIR} --args --setup-terminal"
