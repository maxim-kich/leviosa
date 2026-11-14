# Usage and limitations

[Back to LeviOsa](../README.md).

## Record and edit

In **Settings → Gestures**, click the plus, draw an example, lift and press Enter. Repeat for three accepted examples. Choose an application, optionally enter a title, then Save. Recording alone does not save. The empty title falls back to the application name.

The recording surface appears above darkened Settings. **Enter submits, C clears, Escape closes.** You can lift between strokes. Clear keeps previously accepted examples; cancelling a partial re-record keeps the prior stored examples.

New gestures and saved edits appear first. Edit loads the selected item into the shared form; Cancel restores it unchanged. Save replaces that identity. Delete removes a gesture immediately and has no undo.

## Activate drawing

Use the default **Control–Option–G**, a custom shortcut set in General, or **Draw gesture** in the menu. The shortcut also closes an open drawing session.

For corner activation, enable it and choose a physical trackpad corner. Start with one finger near that corner, move diagonally inward, then lift before drawing. This is not a screen hot corner. The launch surface appears at the selected corner of the current display and closes when you leave its Space.

Draw your trained symbol, lift, then press Enter. Unknown, too-short or inconsistent drawings clear for retry. Use distinct symbols and consistent stroke order/direction. The recognizer is geometric, not machine learning.

General shows Accessibility permission status and an Open System Settings button when access is not allowed. Accessibility is required before recording or drawing, so Enter/C/Escape can be received before application/window routing. The command tap exists only during a foreground drawing session, passes unrelated keys and modified shortcuts through, and is removed on exit. Ordinary modifier-plus-key activation registration does not itself require Accessibility; Fn and modifier-only activation also use it.

Plain-letter and Shift-only activation shortcuts are rejected. Fn/modifier-only options may require Accessibility and may interact with macOS shortcuts. No permission is requested automatically. Physical Fn behavior and Secure Input are not verified.

## Settings and updates

General contains activation controls and Accessibility permission status. Gestures contains recording and the saved list. About contains Check for Updates, the creator link and Licenses (the GitHub acknowledgements page). There is no separate Website button.

Update download and restart have separate confirmations. Finish recording, shortcut recording or an unsaved gesture draft before restarting for an update. See [updater behavior](updater.md).

## Troubleshooting

- **Drawing will not open:** allow LeviOsa under General → Accessibility. If keyboard access is interrupted or Secure Input is enabled, drawing closes and releases the pointer; close secure text fields and try again.
- **No drawing input:** re-enable the listener or restart LeviOsa. Raw trackpad input must be available even when activation uses a shortcut.
- **No corner activation:** check the selected physical corner, use one finger, move inward diagonally and lift before drawing.
- **Save disabled:** finish three valid examples and choose an application. The title is optional.
- **Repeated rejection:** keep stroke order/direction consistent and avoid similar symbols.
- **Input not restored:** try Escape or switch apps; quit LeviOsa if needed and report which exit failed. Forced-kill recovery is not guaranteed.

Report reproducible bugs in [Issues](https://github.com/maxim-kich/leviosa/issues) with version, macOS, trackpad model, activation method, reproduction steps and display/Space context. Review screenshots and logs before sharing. Security reports follow [SECURITY.md](../SECURITY.md).

## Local data and reset

Quit the app and back up `~/Library/Application Support/LeviOsa/gestures.json` before changing storage. Deleting it removes trained gestures. Distribution preferences use `com.maximkich.leviosa`; review preferences use `local.maxim.leviosa.review`.

The first distribution launch imports only unset activation/update choices from the review domain, once. It never imports permission grants, diagnostic settings or installation identifiers. Later preferences stay separate.

## Known limits

Only Open app actions are implemented. Private macOS interfaces can change; trackpad hotplug may require re-enabling the listener. Recognition thresholds are provisional. Physical-size estimates are not calibrated. Other macOS versions, Intel, additional trackpad/display hardware, sustained false-activation behavior and forced-crash recovery remain untested or incompletely validated. See [test scope](testing.md).
