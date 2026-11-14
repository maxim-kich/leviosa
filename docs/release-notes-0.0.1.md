# LeviOsa 0.0.1

Draw a symbol on your trackpad to open an application.

- Train a gesture with three examples and assign an app.
- Activate drawing with a custom shortcut or an optional one-finger inward corner swipe.
- Use multiple strokes, Enter to submit, C to clear and Escape to close.
- Create and edit gestures in native settings with actual drawing previews and local storage.
- Download signed updates with separate download and restart confirmation.

Tested on **macOS 27.2**, Apple Silicon. Other macOS versions and hardware configurations are untested. The installation minimum is macOS 13.0, not a compatibility guarantee. Liquid Glass requires macOS 26 or later.

Drawing requires Accessibility permission. The raw input backend uses an undocumented Apple interface; behavior may change with macOS. Only Open app actions are implemented. Use distinct symbols and consistent stroke order/direction. See [known limits](usage.md#known-limits) and [test scope](testing.md).
