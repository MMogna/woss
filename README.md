# Woss

A native macOS window snapper written in Swift. Ctrl+Option + key snaps the frontmost window
to a grid layout; pressing the same key again cycles through the layouts sharing that key.
Shortcuts can be rebound from the menu bar → Preferences….

## Build the app

    ./scripts/build_app.sh
    open dist/Woss.app                 # try it
    cp -R dist/Woss.app /Applications/ # install it

Then use the menu bar icon → **Launch at Login** to start it automatically.

On first launch macOS asks for **Accessibility** permission: System Settings → Privacy &
Security → Accessibility → enable **Woss**. Hotkeys start working as soon as it is enabled.
If they still don't, also enable **Input Monitoring** for Woss.

### Keeping the permission between rebuilds (recommended, one-time)

Without a stable signing certificate, macOS treats every rebuild as a new app and forgets the
permission. Create a free local certificate once:

1. Open **Keychain Access** → menu **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: `Woss Dev` · Identity Type: *Self Signed Root* · Certificate Type: **Code Signing** → Create.

`build_app.sh` finds it automatically and uses it.

## Tidy windows

Press **⌃⌥A**: all visible windows are arranged into a neat grid, one grid per screen. Windows
keep their rough relative position, and a short last row is stretched to fill the width.

## Swap windows

Press **⌃⌥S**: every visible window gets a badge (1-9, then a-z). Press the badge of one window,
then another: they trade position and size. **Esc** (or ⌃⌥S again, or 8 s idle) cancels.
Badges are numbered by screen position (left to right, top to bottom). The key can be changed
in Preferences → Windows.

## Develop

    swift test        # unit tests (core logic)
    swift run Woss    # run without building the .app (permission goes to your terminal app)

Config: `~/.config/woss/config.json`, written by Preferences → Save & Close:

    { "layouts": [ ["Left Half", 0, 0, 0.5, 1, "left"], ... ],
      "actions": { "doubleWidth": "x", "doubleHeight": "y", "doubleSize": "d", "swap": "s", "tile": "a" } }

An empty string unbinds an action. The old format (a plain array of layouts) is still read.

## Layout

- `Sources/WossCore`  – layouts, key codes, screen math, cycling (no AppKit, tested)
- `Sources/Woss`      – menu bar, global hotkeys, Accessibility window control, settings UI
- `Tests/WossCoreTests`
- `Resources/`        – app icon and menu bar icon
- `scripts/build_app.sh`
