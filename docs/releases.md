# Releases

Repository: `maxim-kich/leviosa`. Sole release maintainer: `@maxim-kich`.

## Stage and compatibility

0.0.1 is the first release. It was tested on **macOS 27.2**, Apple Silicon; other systems and hardware are untested. Keep the binary minimum at macOS 13.0 without treating it as a compatibility guarantee. Do not broaden claims without validation. See [testing](testing.md).

## Package locally

Run the automated and relevant native checks, then:

```sh
./scripts/package-candidate.sh
```

Each run creates a fresh `dist/` directory. It builds arm64, embeds the icon and notices, signs with Developer ID Application, enables Hardened Runtime and timestamps, submits to Apple, saves notarization evidence, staples the ticket and checks Gatekeeper. It creates the final ZIP, signed appcast and checksums. It does not publish, tag, push or install.

Apple credentials stay in Keychain. `LEVIOSA_NOTARY_PROFILE` selects the existing profile; `LEVIOSA_SIGN_IDENTITY` selects a certificate. Updater keys are separate and product-specific. See [updater](updater.md).

If interrupted after submission, resume the saved submission rather than uploading another copy:

```sh
./scripts/finish-candidate.sh /absolute/path/to/the/candidate-directory
```

## Hosting contract

- Tag: `v0.0.1`, matching `VERSION`.
- Title: `LeviOsa 0.0.1`.
- Ordinary GitHub release, prerelease checkbox off, for compatibility with this updater.
- Assets: `LeviOsa-v0.0.1-macOS-arm64.zip`, signed `appcast.xml`, `SHA256SUMS.txt` and the reviewed source archive.
- Website links and the updater must use the same verified release assets.

GitHub’s automatic source archives are not installable app builds. Do not publish the earlier notarization-upload ZIP or overwrite a published tag.

## Publication gates

1. Obtain the owner’s approval of the complete public documentation, notices and release notes.
2. Complete the owner’s retest on the actual signed candidate and record the tested scope.
3. Pass tests and CI for the reviewed source; verify signature, notarization, hashes and first-launch behavior.
4. Publish only reviewed source and intended tags. Do not publish local data, traces, credentials, generated apps or unrelated checkpoint refs.
5. Attach the exact assets and verify public downloads/checksums before linking them elsewhere. Verify update discovery from the prior version when one exists.

Local candidate reports, approval packets and Apple submission logs stay with ignored build/release artifacts rather than the public documentation tree.

CI is read-only and never publishes or receives signing secrets. After repository creation, enable private vulnerability reporting and main/tag protection. Those remote settings are not claimed to exist before publication.
