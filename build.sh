#!/bin/bash
set -e

APP_NAME="ClaudeNotify"
APP_DIR="$HOME/.claude/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building ${APP_NAME}..."

# Create app bundle structure
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy Info.plist and icon
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/"
cp "${SCRIPT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/"

# Compile Swift
swiftc "${SCRIPT_DIR}/ClaudeNotify.swift" \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework Cocoa \
    -framework UserNotifications \
    -framework ApplicationServices

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
