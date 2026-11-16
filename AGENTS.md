# AGENTS.md

Guide for AI coding agents (and humans) working on Woss. User-facing docs live in
[README.md](README.md), [docs/BUILDING.md](docs/BUILDING.md) and
[docs/DISTRIBUTING.md](docs/DISTRIBUTING.md); this file covers what you need to change the code safely.

## What it is

Woss is a keyboard-driven macOS menu bar window manager (macOS 13+, Swift 5.9, SwiftPM,
**zero third-party dependencies**, GPL-3.0-or-later). Its core idea is the **loop**: layouts
sharing a hotkey are cycled by pressing that key again on the same window.

## Commands

```sh
swift build                    # debug build
swift test                     # unit tests (WossCore only, XCTest)
swift run Woss                 # run without bundling; Accessibility belongs to your terminal
./scripts/check_deps.sh        # read-only environment check
./scripts/build_app.sh         # dist/Woss.app  (UNIVERSAL=1, ZIP=1 options)
```

Always run `swift test` before finishing. There is no linter or formatter configured.

## Architecture

Two targets, split by whether code touches macOS:

- `Sources/WossCore` — pure logic, **no AppKit**, fully unit-tested.
  - `Layout.swift` – `Layout` (encoded as a 6-element JSON array) and `RelRect` (screen fractions, **y from bottom**).
  - `DefaultLayouts.swift` – the built-in 45 layouts / 17 keys.
  - `HotkeyTable.swift` – `ActionKeys` (non-layout actions), `HotkeyAction`, `HotkeyTable` (layouts win over actions).
  - `Hotkey` / `KeyCodes.swift` – key names ↔ physical key codes (US names, layout-independent).
  - `CycleState.swift` – loop stepping per window.
  - `Geometry.swift` – relative rect → screen frame, AX/Cocoa coordinate flips, resize clamping.
  - `Tiling.swift` – grid choice for "tidy"; `SwapLabels.swift` – badge labels by screen position.
  - `LayoutStore.swift` – `~/.config/woss/config.json` load/save, legacy bare-array format, `.bak` backup.
- `Sources/Woss` — the app.
  - `main.swift`, `AppDelegate.swift` – startup, permission retry loop, Space-change handling.
  - `AppState.swift` – current config; `onChange` rebuilds the hotkey table.
  - `HotkeyListener.swift` – CGEventTap on **its own thread**.
  - `WindowManager*.swift` – Accessibility API: snap, resize, swap, tile. Main thread only.
  - `SwapController.swift`, `SwapOverlay.swift` – swap mode and its badges.
  - `KeyLabels.swift` – what a physical key prints on the current keyboard layout (display only).
  - `MenuBarController.swift` – menu, launch at login.
  - `Preferences/` – SwiftUI preferences window (`PrefsModel` groups layouts by hotkey into rows, detects conflicts).
- `Tests/WossCoreTests` – tests for WossCore only.

## Rules and invariants

- **Put logic in WossCore** whenever it can be expressed without AppKit, and add a test there.
  The app target has no tests; keep it a thin adapter.
- **No dependencies.** Don't add packages; use Foundation/AppKit/SwiftUI.
- **Threading:** the event tap thread must never do real work. Only `table` and `modalActive`
  are shared, behind a lock; everything else is dispatched to the main thread. A slow tap
  makes the whole system keyboard lag, and macOS disables it.
- **Exactly ⌃⌥:** hotkeys match only Control+Option with no other modifiers; key repeats are
  swallowed but ignored. In swap mode every key is swallowed and forwarded.
- **Never hang on frozen apps:** keep the short AX messaging timeouts.
- **Windows are identified by AX element**, never by title (titles change on resize).
- **Coordinates:** layouts use fractions with y from the bottom; AX uses top-left origin of the
  primary screen; Cocoa uses bottom-left. Convert via `Geometry`, don't hand-roll flips.
- **Keys are stored by physical position** (US names). Show user-visible key names via `KeyLabels`.
- **Config compatibility:** `config.json` is user-edited. Keep reading the legacy format,
  keep missing fields defaulting, keep the `.bak` on save. Changing the on-disk shape needs a
  migration path and a test.
- **No networking, no logging of keystrokes.** The README promises this; keep it true.
- Every source file starts with `// SPDX-License-Identifier: GPL-3.0-or-later`.
- Comments explain *why*, briefly. Match the surrounding style.

## Adding things

- **New layout:** add it to `DefaultLayouts`, then the section/short-name mapping in
  `PrefsModel`, then update the README shortcut table and the count/key assertions in `DefaultLayoutTests` (`LogicTests.swift`).
- **New non-layout action:** add a field + `CodingKey` with default in `ActionKeys`, a case in
  `HotkeyAction`, the entry in `HotkeyTable.init`, handling in `AppDelegate`/`WindowManager`,
  a row in Preferences, a README entry, and tests.
- **User-visible behavior change:** update README.md (features, shortcuts, limitations).

## Manual verification

Window behavior can't be unit-tested. After app-target changes, build with
`./scripts/build_app.sh`, open `dist/Woss.app`, and check the affected shortcuts on more than
one app (and two displays if geometry changed). A stable `Woss Dev` signing certificate keeps
the Accessibility grant across rebuilds (see docs/BUILDING.md).

## Ideas on the roadmap

From the README: saved window arrangements ("scenes"), and moving a window to the next or
previous Space (experimental; macOS offers no public API for it).
