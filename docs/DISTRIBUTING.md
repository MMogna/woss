# Giving Woss to someone else

There are three ways, from easiest for you to easiest for them.

## 1. They build it themselves (recommended)

Send them the source (a zip of the repository, or the repository link). They need a Mac with
macOS 13 or later and Xcode or the Command Line Tools, then:

```sh
unzip woss.zip && cd woss          # skip this if they cloned the repository
./scripts/build_app.sh             # or: bash scripts/build_app.sh
cp -R dist/Woss.app /Applications/
open /Applications/Woss.app
```

An app that is built on the same Mac it runs on carries no "downloaded from the internet"
flag, so macOS shows no warning. They only have to grant **Accessibility** (see
[BUILDING.md](BUILDING.md)). Details such as the optional `.env` file are in the same guide.

## 2. You send them the built app

Build a version that runs on both Apple Silicon and Intel and zip it with the signature
intact:

```sh
UNIVERSAL=1 ZIP=1 ./scripts/build_app.sh     # creates dist/Woss-<version>.zip
```

Send `dist/Woss-<version>.zip`. Do not zip the app by hand with another tool; `ditto` (used by
the script) keeps it valid.

Because the app is **not notarized by Apple**, macOS blocks it the first time on any Mac that
received it by download, chat or AirDrop. The recipient has to approve it once:

- **macOS 15 (Sequoia) and later:** try to open the app, then go to **System Settings →
  Privacy & Security**, scroll to the message about Woss and click **Open Anyway**.
- **macOS 13 and 14:** right-click the app, choose **Open**, then **Open** again.
- **Any version, from Terminal:**

  ```sh
  xattr -dr com.apple.quarantine /Applications/Woss.app
  ```

Then they grant **Accessibility** access to Woss like in the build guide. The permission is
per Mac and per person; nothing from your own setup is carried over.

Only share builds with people who trust you, since they are skipping Apple's checks.

## 3. Proper distribution (no warnings)

For an app that opens with a plain double-click on anyone's Mac, it has to be signed with a
**Developer ID** certificate and **notarized** by Apple. That requires membership in the Apple
Developer Program (paid, yearly). Once you have it, the build script can sign with your
Developer ID through `SIGN_IDENTITY` in `.env`, and the notarization step can be added.
