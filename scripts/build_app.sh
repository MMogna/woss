#!/bin/bash
# Builds dist/Woss.app  —  usage:  ./scripts/build_app.sh
#
# Optional environment variables:
#   SIGN_IDENTITY   code-signing identity to use (default: "Woss Dev" if it exists, else ad-hoc)
#   BUNDLE_ID       default: com.mmogna.woss
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Woss"
BUNDLE_ID="${BUNDLE_ID:-com.mmogna.woss}"
VERSION="0.1.0"
APP="dist/$APP_NAME.app"

echo "▶ Building release binary"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -x "$BIN" ]; then
    echo "✗ Could not find the built binary at: $BIN"
    exit 1
fi

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
    <key>CFBundleName</key>               <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>        <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>         <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>         <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>            <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>     <string>13.0</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
</dict>
</plist>
PLIST

# --- signing -----------------------------------------------------------------
# macOS ties the Accessibility permission to the app's signature. An ad-hoc signature
# ("-") changes on every build, so you'd have to re-grant the permission after each
# rebuild. A stable certificate named "Woss Dev" (see README) avoids that.
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    if security find-identity -p codesigning 2>/dev/null | grep -q "Woss Dev"; then
        IDENTITY="Woss Dev"
    else
        IDENTITY="-"
    fi
fi
if [ "$IDENTITY" = "-" ]; then
    echo "▶ Signing (ad-hoc — permission may need re-granting after each rebuild)"
else
    echo "▶ Signing with: $IDENTITY"
fi
codesign --force --deep --sign "$IDENTITY" "$APP"
codesign --verify --verbose "$APP"

echo ""
echo "✓ Built $APP"
echo "  Try it:    open $APP"
echo "  Install:   cp -R $APP /Applications/"
