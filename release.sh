#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIGN_TOOL="${SCRIPT_DIR}/.build/artifacts/sparkle/Sparkle/bin/sign_update"
APPCAST="${SCRIPT_DIR}/appcast.xml"
APP_DIR="/Applications/ClaudeNotify.app"

# Parse arguments
MARKETING_VERSION=""
TAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) MARKETING_VERSION="$2"; shift 2 ;;
        --tag) TAG="$2"; shift 2 ;;
        *) echo "Usage: ./release.sh [--version 1.2] [--tag v1.2.0]"; exit 1 ;;
    esac
done

# Generate build number (YYYYMMDD)
BUILD_NUMBER=$(date +%Y%m%d)

echo "=== ClaudeNotify Release ==="
echo ""

# Step 1: Update marketing version if provided
if [ -n "${MARKETING_VERSION}" ]; then
    echo "[1/7] Updating marketing version to ${MARKETING_VERSION}..."
    sed -i '' "s|<string>[^<]*</string>\(<!-- MARKETING -->\)\{0,1\}|<string>${MARKETING_VERSION}</string>|" "${SCRIPT_DIR}/Resources/Info.plist" 2>/dev/null || true
    # More reliable: use python to update
    python3 -c "
import plistlib
with open('${SCRIPT_DIR}/Resources/Info.plist', 'rb') as f:
    p = plistlib.load(f)
p['CFBundleShortVersionString'] = '${MARKETING_VERSION}'
with open('${SCRIPT_DIR}/Resources/Info.plist', 'wb') as f:
    plistlib.dump(p, f)
" 2>/dev/null || true
else
    MARKETING_VERSION=$(python3 -c "
import plistlib
with open('${SCRIPT_DIR}/Resources/Info.plist', 'rb') as f:
    p = plistlib.load(f)
print(p.get('CFBundleShortVersionString', '?'))
")
    echo "[1/7] Using existing marketing version: ${MARKETING_VERSION}"
fi

TAG="${TAG:-v${MARKETING_VERSION}.${BUILD_NUMBER}}"
ZIP_NAME="ClaudeNotify-${TAG}.zip"

echo "  Marketing version: ${MARKETING_VERSION}"
echo "  Build number: ${BUILD_NUMBER}"
echo "  Tag: ${TAG}"
echo ""

# Step 2: Build
echo "[2/7] Building..."
CLAUDE_NOTIFY_BUILD_NUMBER="${BUILD_NUMBER}" "${SCRIPT_DIR}/build.sh" 2>&1 | grep -E "^(Build|Code|Creating|Copying|Resolving)"
echo ""

# Step 3: Verify build
INSTALLED_BUILD=$(defaults read "${APP_DIR}/Contents/Info.plist" CFBundleVersion)
INSTALLED_VERSION=$(defaults read "${APP_DIR}/Contents/Info.plist" CFBundleShortVersionString)
echo "[3/7] Verifying build..."
echo "  CFBundleVersion: ${INSTALLED_BUILD}"
echo "  CFBundleShortVersionString: ${INSTALLED_VERSION}"
if [ "${INSTALLED_BUILD}" != "${BUILD_NUMBER}" ]; then
    echo "Error: Build number mismatch (expected ${BUILD_NUMBER}, got ${INSTALLED_BUILD})"
    exit 1
fi
echo ""

# Step 4: Create zip
echo "[4/7] Creating zip..."
rm -f "/tmp/${ZIP_NAME}"
cd /Applications && zip -r -y -q "/tmp/${ZIP_NAME}" ClaudeNotify.app
cd "${SCRIPT_DIR}"
ZIP_SIZE=$(wc -c < "/tmp/${ZIP_NAME}" | tr -d ' ')
echo "  ${ZIP_NAME} (${ZIP_SIZE} bytes)"
echo ""

# Step 5: Sign with EdDSA
echo "[5/7] Signing with EdDSA..."
SIGN_OUTPUT=$("${SIGN_TOOL}" "/tmp/${ZIP_NAME}" 2>&1)
ED_SIGNATURE=$(echo "${SIGN_OUTPUT}" | grep -o 'edSignature="[^"]*"' | cut -d'"' -f2)
ED_LENGTH=$(echo "${SIGN_OUTPUT}" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
echo "  Signature: ${ED_SIGNATURE:0:40}..."
echo "  Length: ${ED_LENGTH}"
echo ""

# Step 6: Update appcast.xml
echo "[6/7] Updating appcast.xml..."
PUB_DATE=$(date -R)
NEW_ITEM="        <item>
            <title>${TAG}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${MARKETING_VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url=\"https://github.com/isaac9711/claude-notify/releases/download/${TAG}/${ZIP_NAME}\"
                length=\"${ED_LENGTH}\"
                type=\"application/octet-stream\"
                sparkle:edSignature=\"${ED_SIGNATURE}\"
            />
        </item>"

# Replace first <item> block or insert before </channel>
python3 -c "
import re
with open('${APPCAST}', 'r') as f:
    content = f.read()

new_item = '''${NEW_ITEM}'''

# Replace everything between <language>en</language> and </channel> with new item only
content = re.sub(
    r'(<language>en</language>\n)(.*?)(    </channel>)',
    r'\1' + new_item + '\n' + r'\3',
    content,
    flags=re.DOTALL
)

with open('${APPCAST}', 'w') as f:
    f.write(content)
"
echo "  appcast.xml updated"
echo ""

# Step 7: Create GitHub release + push
echo "[7/7] Creating GitHub release..."
git add "${SCRIPT_DIR}/Resources/Info.plist" "${APPCAST}"
git commit -m "release: ${TAG} (build ${BUILD_NUMBER})" 2>/dev/null || true
git push origin main 2>&1 | tail -1

gh release create "${TAG}" "/tmp/${ZIP_NAME}" \
    --title "${TAG}" \
    --notes "Build ${BUILD_NUMBER} | Version ${MARKETING_VERSION}

Auto-update: Existing users will receive this update automatically via Sparkle." \
    2>&1 | tail -1

echo ""
echo "=== Release Complete ==="
echo "  Tag: ${TAG}"
echo "  URL: https://github.com/isaac9711/claude-notify/releases/tag/${TAG}"
echo "  Sparkle: Users on older builds will auto-update"
