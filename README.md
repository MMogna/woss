<p align="center">
  <img src="docs/images/woss-icon.png" alt="Woss icon" width="128" height="128">
</p>

<h1 align="center">Woss</h1>

<p align="center">
  A keyboard-driven window manager for macOS, built around <b>loops</b>:<br>
  press the same shortcut again to step through related layouts.
</p>

---

Woss lives in your menu bar and snaps, resizes, swaps and tidies windows with
<kbd>⌃</kbd><kbd>⌥</kbd> shortcuts. It is written in Swift with no dependencies.

The idea that sets it apart is the **loop**: layouts that share a key are cycled by
pressing that key repeatedly. `⌃⌥3` gives you the left third, press it again for the center
third, again for the right third. You only need to remember a handful of keys, not one per layout.

## Features

- **Snap to a layout.** Halves, thirds, quarters, three-quarters, corners, sixths, eighths,
  ninths, fullscreen and an "almost maximize". 45 layouts behind 17 keys.
- **Loops.** Layouts sharing a key cycle on repeated presses, per window.
- **Swap windows.** `⌃⌥S` puts a numbered badge on every window; press two labels and the
  windows trade position and size.
- **Tidy windows.** `⌃⌥A` arranges all visible windows into an even grid, one grid per screen.
  The grid is chosen so every window gets a natural shape and a similar size (7 windows become
  three columns holding 3, 2 and 2), never one window stretched over a whole row.
- **Double width / height / size.** Grow a window while keeping it on screen.
- **Multiple displays.** Layouts apply to the screen the window is on.
- **Rebind everything** in Preferences, including making your own loops by giving two actions
  the same key. Conflicting keys are highlighted.
- **Launch at login**, no Dock icon, light and dark menu bar icon.

## Default shortcuts

All shortcuts are <kbd>⌃</kbd><kbd>⌥</kbd> + key.

| Key | Action | Loop |
| --- | --- | --- |
| `←` `→` `↑` `↓` | Left / right / top / bottom half | |
| `↵` | Fullscreen | |
| `'` | Almost maximize | |
| `3` | Left, center, right third | 3 steps |
| `T` | Top, middle, bottom third | 3 steps |
| `4` | Four vertical quarters | 4 steps |
| `E` | Left-aligned, right-aligned three-quarters | 2 steps |
| `U` `I` `J` `K` | Top-left, top-right, bottom-left, bottom-right corner | |
| `R` | Six cells (3 × 2) | 6 steps |
| `8` | Eight cells (4 × 2) | 8 steps |
| `9` | Nine cells (3 × 3) | 9 steps |
| `X` `Y` `D` | Double width / height / both | |
| `S` | Swap two windows | |
| `A` | Tidy all windows into a grid | |

### Swapping windows

1. Press `⌃⌥S`. Every visible window gets a badge: `1`–`9`, then `A`–`Z`.
2. Press the badge of one window (it turns blue), then the badge of another.
3. The two windows exchange position and size.

`Esc`, pressing `⌃⌥S` again, switching Space, or 8 seconds without input cancels.
Badges are numbered by screen position (left to right, top to bottom), so a window keeps
its number as long as it doesn't move.

## Install

Woss is not notarized, so the simplest way to get it is to build it yourself. It takes about a
minute and needs only Xcode or the Command Line Tools:

```sh
git clone <this repository>
cd woss
./scripts/build_app.sh
open dist/Woss.app
```

Then grant **Accessibility** access when macOS asks, and use the menu bar icon →
**Launch at Login** if you want it to start with your Mac.

Full instructions, including how to keep the permission across rebuilds and what to do when
something doesn't work, are in **[docs/BUILDING.md](docs/BUILDING.md)**. To give the app to
someone else, see **[docs/DISTRIBUTING.md](docs/DISTRIBUTING.md)**.

**Requirements:** macOS 13 (Ventura) or later.

## Configuration

Preferences (menu bar icon → *Preferences…*) edits everything and writes
`~/.config/woss/config.json`. You can also edit the file by hand and choose *Reload Layouts*:

```json
{
  "layouts": [
    ["Left Half", 0, 0, 0.5, 1, "left"],
    ["Top Half", 0, 0.5, 1, 0.5, "up"]
  ],
  "actions": {
    "doubleWidth": "x",
    "doubleHeight": "y",
    "doubleSize": "d",
    "swap": "s",
    "tile": "a"
  }
}
```

A layout is `[name, x, y, width, height, key]`. The numbers are fractions of the screen's
usable area, and `y` is measured from the **bottom**. Layouts with the same key form a loop,
in file order. An empty key (`""`) unbinds an action. Missing entries fall back to the
defaults. Every save keeps the previous file as `config.json.bak`.

## Permissions and privacy

- **Accessibility** is required to move other apps' windows and to see the shortcuts.
  Some systems also ask for **Input Monitoring**.
- Woss receives every key press on your system in order to notice its shortcuts. It only acts
  on <kbd>⌃</kbd><kbd>⌥</kbd> combinations (and, during swap mode, the badge keys). Nothing is
  logged, stored or sent anywhere: there is no networking code in the app.
- **Screen Recording is not needed.** Window positions come from the window list and the
  Accessibility API; Woss never reads window contents.

## Known limitations

- Swap and tidy only see **windows on the current Space**. macOS does not let apps move
  windows that are on another Space.
- Dialogs, palettes, minimized and full-screen windows are ignored by swap and tidy.
- Shortcuts are matched by key position on a **US keyboard layout**. On other layouts the
  physical key may produce a different character than the one shown.
- A window with a minimum size can't always shrink to a small layout; Woss moves it back on
  screen but cannot make it smaller.
- Other window managers (Rectangle, Magnet…) may use the same shortcuts. Quit them or
  rebind either side.

## Project layout

```
Sources/WossCore   layouts, key codes, screen math, loops, tiling   (no AppKit, unit-tested)
Sources/Woss       menu bar, global hotkeys, Accessibility, Preferences window
Tests/             unit tests for WossCore
Resources/         app icon and menu bar icon (SVG sources included)
scripts/           build_app.sh
docs/              build and distribution guides
```

Run the tests with `swift test`.

## Ideas

Saved window arrangements ("scenes") and an experimental shortcut to send a window to the
next or previous Space are on the list. Contributions and ideas are welcome.

## Acknowledgments

Woss is inspired by [Rectangle](https://github.com/rxhanson/Rectangle), which set the
standard for keyboard window management on macOS. Woss is an independent project and is not
affiliated with it.

## License

Woss is free software, released under the **GNU General Public License v3.0 or later**
(see [LICENSE](LICENSE)). You may use, study, change and share it. If you distribute a modified
version, you must do so under the same license and make its source available.

Copyright © 2026 Woss contributors.
