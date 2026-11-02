#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Checks that this Mac has everything needed to build Woss. It only looks; it changes nothing.
#
#   ./scripts/check_deps.sh            full report
#   ./scripts/check_deps.sh --quiet    only problems (this is what build_app.sh runs)
#
# Exit status: 0 = ready to build (warnings are fine), 1 = something must be fixed first.
# No internet connection is needed to build Woss: it has no third-party dependencies.
set -u
cd "$(dirname "$0")/.."

QUIET=0
if [ "${1:-}" = "--quiet" ]; then QUIET=1; fi

FAILURES=0
WARNINGS=0

say()  { if [ "$QUIET" = "0" ]; then printf '%s\n' "$1"; fi; }
ok()   { if [ "$QUIET" = "0" ]; then printf '  ✓ %s\n' "$1"; fi; }
note() { if [ "$QUIET" = "0" ]; then printf '  ℹ %s\n' "$1"; fi; }
warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '  ⚠ %s\n' "$1"
    if [ -n "${2:-}" ]; then printf '      → %s\n' "$2"; fi
}
fail() {
    FAILURES=$((FAILURES + 1))
    printf '  ✗ %s\n' "$1"
    if [ -n "${2:-}" ]; then printf '      → %s\n' "$2"; fi
}

finish() {
    say ""
    if [ "$FAILURES" -gt 0 ]; then
        printf '✗ %d problem(s) to fix before building. Fix them, then run this check again.\n' "$FAILURES"
        exit 1
    fi
    if [ "$WARNINGS" -gt 0 ]; then
        printf '✓ Ready to build (the warning above is not blocking).\n'
    else
        say "✓ Everything needed is in place. Next: ./scripts/build_app.sh"
    fi
    exit 0
}

say "Checking this Mac for building Woss"
say ""

# --- operating system ---------------------------------------------------------
if [ "$(uname -s)" != "Darwin" ]; then
    fail "This is not a Mac ($(uname -s))." "Woss only builds and runs on macOS 13 or later."
    finish
fi

OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 0)"
OS_MAJOR="${OS_VERSION%%.*}"
case "$OS_MAJOR" in ''|*[!0-9]*) OS_MAJOR=0 ;; esac
if [ "$OS_MAJOR" -ge 13 ]; then
    ok "macOS $OS_VERSION"
else
    fail "macOS $OS_VERSION is too old (13 or later is required)." \
         "Update in System Settings → General → Software Update."
fi

case "$(uname -m)" in
    arm64)  note "Apple Silicon Mac (arm64)" ;;
    x86_64) note "Intel Mac (x86_64)" ;;
    *)      note "Architecture: $(uname -m)" ;;
esac

# --- developer tools ----------------------------------------------------------
if ! DEV_DIR="$(xcode-select -p 2>/dev/null)" || [ ! -d "$DEV_DIR" ]; then
    fail "Xcode developer tools are not installed." \
         "Run:  xcode-select --install   (accept the window that opens, wait until it finishes, then run this check again)"
    finish # nothing below can work without them, and we must not trigger their installer
fi
ok "Developer tools: $DEV_DIR"

# --- Swift --------------------------------------------------------------------
if ! command -v swift >/dev/null 2>&1; then
    fail "The 'swift' command was not found." "Install Xcode, or run:  xcode-select --install"
else
    SWIFT_OUT="$(swift --version 2>&1)"
    SWIFT_STATUS=$?
    if printf '%s' "$SWIFT_OUT" | grep -qi 'license'; then
        fail "The Xcode license has not been accepted yet." "Run:  sudo xcodebuild -license accept"
    elif [ "$SWIFT_STATUS" -ne 0 ]; then
        fail "'swift --version' failed." "It said: $(printf '%s' "$SWIFT_OUT" | head -n 1)"
    else
        SWIFT_VERSION="$(printf '%s\n' "$SWIFT_OUT" \
            | sed -n 's/.*Swift version \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)"
        if [ -z "$SWIFT_VERSION" ]; then
            warn "Could not read the Swift version." "It said: $(printf '%s' "$SWIFT_OUT" | head -n 1)"
        else
            SW_MAJOR="${SWIFT_VERSION%%.*}"
            SW_MINOR="${SWIFT_VERSION#*.}"
            if [ "$SW_MAJOR" -gt 5 ] || { [ "$SW_MAJOR" -eq 5 ] && [ "$SW_MINOR" -ge 9 ]; }; then
                ok "Swift $SWIFT_VERSION"
            else
                fail "Swift $SWIFT_VERSION is too old (5.9 or later is required)." \
                     "Update Xcode or the Command Line Tools in System Settings → General → Software Update."
            fi
        fi
    fi
fi

# --- macOS SDK ----------------------------------------------------------------
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [ -n "$SDK_PATH" ] && [ -d "$SDK_PATH" ]; then
    ok "macOS SDK found"
else
    fail "The macOS SDK was not found." \
         "Reinstall the developer tools:  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
fi

# --- system tools used by the build script --------------------------------------
MISSING=""
for tool in codesign security ditto lipo; do
    if ! command -v "$tool" >/dev/null 2>&1; then MISSING="$MISSING $tool"; fi
done
if [ -z "$MISSING" ]; then
    ok "System tools (codesign, security, ditto, lipo)"
else
    fail "Missing system tools:$MISSING" "They come with macOS and the developer tools:  xcode-select --install"
fi

# --- the project itself ---------------------------------------------------------
PROJECT_OK=1
for f in Package.swift Resources/AppIcon.icns Resources/MenuIcon.png scripts/build_app.sh; do
    if [ ! -f "$f" ]; then
        fail "Missing project file: $f" "Is this the complete Woss folder? Download or clone it again."
        PROJECT_OK=0
    fi
done
if [ "$PROJECT_OK" = "1" ]; then ok "Project files present"; fi

if [ -f scripts/build_app.sh ] && [ ! -x scripts/build_app.sh ]; then
    warn "scripts/build_app.sh is not executable." \
         "Run:  chmod +x scripts/*.sh   (or start it with:  bash scripts/build_app.sh)"
fi

# --- optional things (information only) -------------------------------------------
if command -v security >/dev/null 2>&1; then
    IDENTITIES="$(security find-identity -p codesigning 2>/dev/null || true)"
    if printf '%s' "$IDENTITIES" | grep -q 'Woss Dev'; then
        note "Signing certificate 'Woss Dev' found: the Accessibility permission will survive rebuilds."
    else
        note "No 'Woss Dev' signing certificate (optional). The app is then signed ad-hoc and macOS asks for"
        note "the Accessibility permission again after each rebuild. See docs/BUILDING.md to create one."
    fi
fi
if [ -f .env ]; then note "Found a .env file: its settings will be used by build_app.sh."; fi

finish
