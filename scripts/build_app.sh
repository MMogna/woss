#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds dist/Woss.app
#
#   ./scripts/build_app.sh                 build for this Mac
#   UNIVERSAL=1 ./scripts/build_app.sh     build for Apple Silicon AND Intel
#   ZIP=1 ./scripts/build_app.sh           also create dist/Woss-<version>.zip (to share)
#
# Personal settings go in a git-ignored `.env` file next to Package.swift (see .env.example):
#   BUNDLE_ID       app identifier, default: com.example.woss
#   SIGN_IDENTITY   code-signing identity, default: "Woss Dev" if it exists, else ad-hoc
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

APP_NAME="Woss"
BUNDLE_ID="${BUNDLE_ID:-com.example.woss}"
VERSION="0.1.0"
APP="dist/$APP_NAME.app"

# bash 3.2 (macOS) treats an empty array as "unset" under `set -u`, hence the odd expansion.
ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▶ Building release binary"
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/$APP_NAME"
if [ ! -x "$BIN" ]; then
    echo "✗ Could not find the built binary at: $BIN"
    exit 1
fi
echo "  architectures: $(lipo -archs "$BIN" 2>/dev/null || echo unknown)"

echo "▶ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/MenuIcon.png "$APP/Contents/Resources/MenuIcon.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>         <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>          <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>          <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>            <string>AppIcon</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>$VERSION</string>
    <key>CFBundleVersion</key>             <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>   <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
    <key>NSHighResolutionCapable</key>     <true/>
    <key>NSPrincipalClass</key>            <string>NSApplication</string>
</dict>
</plist>
PLIST

# --- signing -----------------------------------------------------------------
# macOS ties the Accessibility permission to the app's signature. An ad-hoc signature
# ("-") changes on every build, so the permission must be granted again after a rebuild.
# A stable local certificate named "Woss Dev" (see docs/BUILDING.md) avoids that.
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    # Capture first: `security | grep -q` under pipefail can fail spuriously (SIGPIPE).
    IDENTITIES="$(security find-identity -p codesigning 2>/dev/null || true)"
    if grep -q "Woss Dev" <<< "$IDENTITIES"; then
        IDENTITY="Woss Dev"
    else
        IDENTITY="-"
    fi
fi
if [ "$IDENTITY" = "-" ]; then
    echo "▶ Signing (ad-hoc: Accessibility permission must be re-granted after each rebuild)"
else
    echo "▶ Signing with: $IDENTITY"
fi
codesign --force --deep --sign "$IDENTITY" "$APP"
codesign --verify --verbose "$APP"

if [ "${ZIP:-0}" = "1" ]; then
    ZIP_PATH="dist/$APP_NAME-$VERSION.zip"
    echo "▶ Creating $ZIP_PATH"
    rm -f "$ZIP_PATH"
    # ditto (not zip) keeps the code signature and file attributes intact
    ditto -c -k --keepParent "$APP" "$ZIP_PATH"
fi

echo ""
echo "✓ Built $APP"
echo "  Try it:    open $APP"
echo "  Install:   cp -R $APP /Applications/"
