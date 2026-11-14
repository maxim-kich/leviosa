# Sparkle 2.10.1

`Sparkle.framework` is the universal macOS framework from the official Sparkle 2.10.1 distribution. It is vendored so a normal source build does not need to download a dependency or use a private signing key.

Upstream: https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1

Full copyright and third-party notices are in [docs/licenses/Sparkle-LICENSE.txt](../docs/licenses/Sparkle-LICENSE.txt), also bundled into the app. Preserve versioned symlinks and helper executables. The build signs its copied framework, not the vendored original.

Maintainer tools are downloaded separately by `scripts/fetch-sparkle-tools.sh` from the official archive, pinned to SHA-256 `1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27`. Never reuse another app’s private update key or feed.
