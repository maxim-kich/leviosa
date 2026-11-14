# Privacy

LeviOsa uses trackpad contact positions to recognize symbols. Trained examples, titles and assigned application paths are stored locally in `~/Library/Application Support/LeviOsa/gestures.json`. Recognition runs on your Mac; no drawings are sent to a cloud service. There is no analytics or telemetry.

The private trackpad listener runs when corner activation or drawing needs it. Pointer holding/hiding applies only during an active drawing session. Optional shortcut modes use Accessibility-gated observation or input taps. Drawing requires Accessibility permission for a session-scoped system event tap. It receives Enter, C and Escape before application/window routing, consumes those commands only while LeviOsa owns the active drawing session, and passes unrelated keys and modified shortcuts through. The tap is removed before pointer unlock or focus handoff; it does not run while idle. A local handler also supports events addressed directly to LeviOsa. Permission is checked without an automatic prompt. If command capture becomes unavailable, drawing ends and releases the pointer.

Opt-in local diagnostics record lifecycle flags, timings, window geometry and point/stroke counts. During drawing, they can also record keyboard-event categories, modifier flags and process/window identifiers to investigate input routing. They do not record drawn point coordinates, arbitrary typed text or arbitrary key codes. They are disabled by default and are not uploaded automatically. Review reports before sharing them.

Update checks contact GitHub. Downloading and restarting require separate confirmation. Automatic checks are off by default; Sparkle system profiling, cookies and installation identifiers are disabled by the update flow. Updates do not send gesture data or logs. No notification permission is requested.

The creator and license links open the relevant websites, which receive normal connection information and have their own privacy practices. Quit LeviOsa before deleting local data. Removing the gesture file deletes trained gestures; removing preferences resets settings. See the [usage guide](docs/usage.md#local-data-and-reset).
