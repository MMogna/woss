# Building Woss

Woss is a Swift package with no third-party dependencies.

## Requirements

- macOS 13 (Ventura) or later
- Xcode **or** the Command Line Tools. If `swift --version` prints nothing useful, run:

  ```sh
  xcode-select --install
  ```

## Check your Mac first

```sh
./scripts/check_deps.sh
```

The script only looks, it never changes anything. It checks the macOS version, the developer
tools, the Swift version, the macOS SDK and the system tools the build uses, and for each
problem it prints the command that fixes it. Typical results:

| Message | What to do |
| --- | --- |
| Xcode developer tools are not installed | Run `xcode-select --install`, accept the window that opens, wait for it to finish, then run the check again |
| The Xcode license has not been accepted | Run `sudo xcodebuild -license accept` |
| macOS or Swift is too old | Update in System Settings → General → Software Update |
| Missing project file | The folder is incomplete: clone or download it again |

Woss has **no third-party dependencies**, so nothing else has to be installed and no internet
connection is needed to build. `build_app.sh` runs this check automatically before building, so
you can also skip straight to the next step.

## Build and run

```sh
git clone <this repository>
cd woss

./scripts/check_deps.sh     # optional but recommended
swift test                  # optional: run the unit tests
./scripts/build_app.sh      # creates dist/Woss.app
open dist/Woss.app
```

If a script is not executable (this can happen when files travel through chat apps or some
archive tools), run it with `bash scripts/build_app.sh`, or fix it once with
`chmod +x scripts/*.sh`.

To install it, copy the app to `/Applications` and, from the menu bar icon, switch on
**Launch at Login**:

```sh
cp -R dist/Woss.app /Applications/
```

### Build options

| Command | Result |
| --- | --- |
| `./scripts/build_app.sh` | App for the Mac you are building on |
| `UNIVERSAL=1 ./scripts/build_app.sh` | App for Apple Silicon **and** Intel |
| `ZIP=1 ./scripts/build_app.sh` | Also creates `dist/Woss-<version>.zip` |

### Personal settings (`.env`)

Settings that depend on you live in a `.env` file, which git ignores. Copy the example and edit it:

```sh
cp .env.example .env
```

| Variable | Meaning | Default |
| --- | --- | --- |
| `BUNDLE_ID` | Identifier of the built app, e.g. `com.yourname.woss` | `com.example.woss` |
| `SIGN_IDENTITY` | Code-signing identity to use | `Woss Dev` if it exists, otherwise ad-hoc |

## Permissions

On first launch macOS asks for **Accessibility** access. Open **System Settings → Privacy &
Security → Accessibility** and switch **Woss** on. The shortcuts start working as soon as it is
enabled. If they still do nothing, also enable Woss under **Input Monitoring**.

### Keeping the permission across rebuilds (recommended for developers)

macOS ties the permission to the app's code signature. Without a stable certificate every
rebuild looks like a new app and the permission has to be granted again. Create a free local
certificate once:

1. Open **Keychain Access**.
2. Menu **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Name: `Woss Dev` · Identity Type: *Self Signed Root* · Certificate Type: **Code Signing**.
4. Click **Create**.

`build_app.sh` detects it automatically.

## Developing

```sh
swift test        # unit tests for the core logic
swift run Woss    # run without building the .app
```

When started with `swift run`, the Accessibility permission belongs to the terminal app you
ran it from (Terminal, iTerm, VS Code…), and the *Launch at Login* switch does not work.

The code is split in two targets so the logic can be tested without a screen:

- `WossCore`: layouts, key codes, geometry, loops, tiling, config file. No AppKit.
- `Woss`: everything that touches macOS (event tap, Accessibility API, windows, menus).

## Troubleshooting

**The shortcuts do nothing.**
Check Accessibility (and Input Monitoring) for Woss. If Woss is already in the list but
disabled-looking or stuck after a rebuild, remove it with the **−** button, then start the app
again and re-enable it. From a terminal you can also reset it:
`tccutil reset Accessibility <your bundle id>`.

**A shortcut works in one app but not another.**
That app may use the same shortcut itself, or another window manager (Rectangle, Magnet…) is
running. Quit it or rebind the shortcut in Preferences.

**`swift build` fails.**
Make sure `swift --version` reports 5.9 or newer, and that the Command Line Tools match your
macOS version. If the build state is odd, delete the `.build` folder and try again.

**macOS says the app can't be opened.**
This only happens to an app that was downloaded or received from someone else. See
[DISTRIBUTING.md](DISTRIBUTING.md).

## Uninstall

1. Quit Woss from its menu bar icon (switch off *Launch at Login* first).
2. Delete `Woss.app`.
3. Optionally delete `~/.config/woss` and remove Woss from the Accessibility list.
