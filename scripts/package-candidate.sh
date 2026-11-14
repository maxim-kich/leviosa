#!/bin/bash
# Local candidate only: does not create a tag, remote, GitHub release, or installation.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
mkdir -p dist
ROOT=$(mktemp -d "$PWD/dist/candidate-v${VERSION}.XXXXXX")
printf '%s\n' "$ROOT" > build/last-candidate-directory.txt
export LEVIOSA_APP_PATH="$ROOT/LeviOsa.app" LEVIOSA_RELEASE_SIGNING=1
./build.sh > "$ROOT/build.log" 2>&1
./scripts/verify-candidate.sh "$LEVIOSA_APP_PATH" > "$ROOT/verification-before-notarization.txt" 2>&1
PROFILE="${LEVIOSA_NOTARY_PROFILE:-drag2-notary}"
ditto -c -k --sequesterRsrc --keepParent "$LEVIOSA_APP_PATH" "$ROOT/notarization-upload.zip"
xcrun notarytool submit "$ROOT/notarization-upload.zip" --keychain-profile "$PROFILE" --no-progress --output-format json > "$ROOT/submission.json"
SUBMISSION=$(/usr/bin/plutil -extract id raw -o - "$ROOT/submission.json")
printf 'Submission: %s\nCandidate: %s\n' "$SUBMISSION" "$ROOT"
# Result is persisted so an interrupted client can resume this submission instead of resubmitting.
./scripts/finish-candidate.sh "$ROOT"
