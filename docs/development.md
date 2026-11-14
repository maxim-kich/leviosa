# Development

Use an Apple Silicon Mac with full Xcode 26+ and the macOS 26 SDK or newer selected. Command Line Tools alone are insufficient for the availability-guarded Liquid Glass APIs. Check `xcodebuild -version`. Python 3 is used by build and validation scripts.

From the repository root:

```sh
./test.sh
./build.sh
python3 scripts/check-repository.py
```

The review app is `build/LeviOsa.app`. Quit it before rebuilding, or set `LEVIOSA_APP_PATH` to a separate output. The script refuses to overwrite a running app. Default builds are ad-hoc signed and do not replace an installed app.

`VERSION` is the version source of truth. The app/executable is LeviOsa. The runtime target is macOS 13.0 on arm64; only macOS 27.2 has been tested. Keep availability guards and fallbacks; a build minimum does not establish compatibility on an untested system.

## Layout

- `Sources/`: AppKit settings/drawing UI, recognizer, persistence, shortcuts, capture lifecycle and updater.
- `Sources/Trackpad.c`: isolated dynamically loaded raw trackpad backend.
- `Tests/`: deterministic behavior and ownership checks.
- `assets/`: editable app/menu-bar SVGs, the rendered README image, and 1x/2x menu-bar PNGs.
- `docs/`: usage, development, testing, updater and release guides.
- `docs/licenses/`: full third-party notices and provenance.
- `scripts/`: local build, validation, packaging and disposable updater fixtures.

After editing the icon SVGs, run `./scripts/render-branding.sh` to regenerate the README image and native menu-bar assets. The build generates the app’s ICNS from `assets/icon.svg` and bundles both menu-bar resolutions. AppKit loads the menu image as a template so it follows the menu bar’s appearance.

`build/`, `dist/`, `.local/` and historical local QA traces are not publishable source. Do not bulk-stage the project. The public inventory is defined by `scripts/check-repository.py`.

## Data and identities

Review and distribution builds share the local gesture-library location but have separate preference domains. Use `LEVIOSA_QA_DATA_DIRECTORY` for an isolated development library. Never migrate or delete your only copy during a test. Normal builds do not enable diagnostics; optional local capture diagnostics use `LEVIOSA_CAPTURE_DIAGNOSTICS`.

Distribution identity is `com.maximkich.leviosa`. Its first launch imports only unset activation/update choices from the review preferences, once. Permission grants and diagnostic settings are excluded. macOS may require a new Accessibility grant for the distribution identity before drawing.

Set `LEVIOSA_RELEASE_SIGNING=1` and `LEVIOSA_APP_PATH` for a separate Developer ID build. The script selects an available Developer ID Application certificate; `LEVIOSA_SIGN_IDENTITY` overrides it. Release builds enable Hardened Runtime and secure timestamps and sign nested Sparkle code inside out. Never commit private keys. See [releases](releases.md) for notarization and [updater](updater.md) for signing configuration.
