# Update signing

`sparkle-public-key.txt` contains LeviOsa’s public Ed25519 update-signing key. The private key stays in macOS Keychain under `com.maximkich.leviosa.updates` and is never included in the repository or app.

The build embeds the public key and the signed release-feed URL. Update checks are manual by default. Never reuse another app’s update key or feed. See [updater setup](../docs/updater.md) and [release preparation](../docs/releases.md).
