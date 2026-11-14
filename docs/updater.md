# In-app updates

LeviOsa uses Sparkle 2.10.1 with a quiet native user driver. About provides **Check for Updates → Download & Install → Restart**. Automatic checks are off by default. No notification permission is requested, and Sparkle system profiling and installation identifiers are disabled.

Only newer ordinary GitHub releases with numeric tags, a nonempty Apple Silicon ZIP and a matching signed feed are offered. Drafts, prereleases and source-only releases are ignored. Publish `LeviOsa 0.0.1` as an ordinary release for this updater.

The public repository is `maxim-kich/leviosa`. Assets for `v0.0.1` are `LeviOsa-v0.0.1-macOS-arm64.zip` and `appcast.xml` on that release. Before a release exists, a manual check reports that no published release is available.

## Verification and restart

Feeds and archives must be signed, and archive verification happens before extraction. API metadata and the signed feed must agree. Download and restart need separate consent; cancellation disarms install-on-quit.

Capture, shortcut recording and an unsaved gesture draft block restart. Before installation, the app pauses shortcut registration, stops raw input and confirms cursor resources have been released. Cancellation or preparation failure restores input without changing saved activation choices. Stale callbacks cannot authorize installation.

The public Ed25519 key is in [config/sparkle-public-key.txt](../config/sparkle-public-key.txt). Its private key stays in Keychain under `com.maximkich.leviosa.updates`; never export it into source or logs. [Signing configuration](../config/README.md).

## Local validation

`./scripts/test-updater-local.sh MODE` builds disposable signed app versions and uses a loopback-only feed and temporary fixture keys. Successful replacement/relaunch, activation on/off preservation, cancellation, tampered feed/archive rejection and incompatible-OS rejection passed. These tests are separate from public-download verification after publication and the owner’s physical gesture retest.

See [releases](releases.md) for notarized packaging and publication gates.
