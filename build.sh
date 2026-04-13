#!/bin/bash
set -e

APP_NAME="ClaudeNotify"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building ${APP_NAME} (SPM + Sparkle)..."
echo ""

# Resolve dependencies
echo "Resolving dependencies..."
swift package resolve --package-path "${SCRIPT_DIR}"

# Build for Apple Silicon
echo "Building for arm64..."
swift build -c release --arch arm64 --package-path "${SCRIPT_DIR}"

# Build for Intel
echo "Building for x86_64..."
swift build -c release --arch x86_64 --package-path "${SCRIPT_DIR}"

# Create app bundle structure
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${FRAMEWORKS_DIR}"

# Create universal binary
ARM64_BIN="${SCRIPT_DIR}/.build/arm64-apple-macosx/release/${APP_NAME}"
X86_BIN="${SCRIPT_DIR}/.build/x86_64-apple-macosx/release/${APP_NAME}"
echo "Creating universal binary..."
lipo -create "${ARM64_BIN}" "${X86_BIN}" -output "${MACOS_DIR}/${APP_NAME}"

# Copy resources + set build number (YYYYMMDD)
BUILD_NUMBER=$(date +%Y%m%d)
sed "s/BUILD_NUMBER/${BUILD_NUMBER}/" "${SCRIPT_DIR}/Resources/Info.plist" > "${CONTENTS_DIR}/Info.plist"
cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
echo "Build number: ${BUILD_NUMBER}"

# Create .lproj directories for supported languages (enables Sparkle localization)
for lang in en ko zh-Hans ja es vi pt-BR; do
    mkdir -p "${RESOURCES_DIR}/${lang}.lproj"
done

# Copy Sparkle.framework from SPM artifacts
SPARKLE_FW=$(find "${SCRIPT_DIR}/.build/artifacts" -name "Sparkle.framework" -path "*/macos-*" | head -1)
if [ -z "${SPARKLE_FW}" ]; then
    echo "Error: Sparkle.framework not found in .build/artifacts/"
    exit 1
fi
echo "Copying Sparkle.framework..."
rm -rf "${FRAMEWORKS_DIR}/Sparkle.framework"
cp -R "${SPARKLE_FW}" "${FRAMEWORKS_DIR}/"

# Code sign (inside-out: XPC services → framework → app bundle)
# --preserve-metadata=entitlements keeps Sparkle's original XPC entitlements needed for auto-update
echo "Code signing..."
codesign --force --sign - --preserve-metadata=entitlements "${FRAMEWORKS_DIR}/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - --preserve-metadata=entitlements "${FRAMEWORKS_DIR}/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - --preserve-metadata=entitlements "${FRAMEWORKS_DIR}/Sparkle.framework"
codesign --force --sign - --options runtime \
    --entitlements "${SCRIPT_DIR}/Resources/ClaudeNotify.entitlements" \
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
