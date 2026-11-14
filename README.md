<p align="center"><img src="assets/app-icon.png" width="128" alt="LeviOsa icon"></p>

# LeviOsa

Draw a symbol on your Mac’s trackpad to open an application.

## Download

[Download LeviOsa for macOS](https://github.com/maxim-kich/leviosa/releases/latest).

Move LeviOsa to Applications and open it. No Xcode or terminal commands are needed to use the app.

## Get started

Allow LeviOsa in **Settings → General → Accessibility** before recording or drawing. Command capture runs only during drawing.

1. Open **Settings → Gestures** and click **Record gesture**.
2. Draw three examples. Lift your finger and press **Enter** after each example.
3. Choose an application and click **Save**. A title is optional.
4. Press **Control–Option–G**, draw the symbol, lift, and press Enter to open the assigned app.

**C clears** the current drawing; **Escape closes** the drawing area. Multiple strokes are supported. Completing the recordings fills the form without saving automatically.

General settings lets you choose a custom activation shortcut or enable a one-finger inward swipe from a selected trackpad corner. Only **Open app** actions are available in 0.0.1. See the [usage guide and limitations](docs/usage.md).

Raw trackpad input uses Apple’s undocumented MultitouchSupport framework. Compatibility may change with macOS updates.

## Build

On an Apple Silicon Mac with Xcode 26+ and the macOS 26 SDK or newer:

```sh
./test.sh
./build.sh
```

The review app is created at `build/LeviOsa.app`. Local builds are ad-hoc signed and are not notarized distribution builds. See [development](docs/development.md) and [testing](docs/testing.md).

## Privacy and updates

Gesture examples and assigned application paths stay on your Mac. There is no cloud recognition, analytics or telemetry. [Privacy details](PRIVACY.md).

About contains **Check for Updates**, the creator link and **Licenses**, which opens the GitHub acknowledgements page. Downloading an update and restarting require separate confirmation. Updates use signed Sparkle feeds and archives. See [updater setup](docs/updater.md).

[Development](docs/development.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE) · [Licenses & Acknowledgements](ACKNOWLEDGEMENTS.md)

Created by [Maxim Kich](https://maximkich.com).
