#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$1";APP="$ROOT/LeviOsa.app";PROFILE="${LEVIOSA_NOTARY_PROFILE:-drag2-notary}"
SUBMISSION=$(/usr/bin/plutil -extract id raw -o - "$ROOT/submission.json")
if ! xcrun notarytool wait "$SUBMISSION" --keychain-profile "$PROFILE" --timeout 20m --no-progress --output-format json > "$ROOT/notarization-result.json";then
 xcrun notarytool info "$SUBMISSION" --keychain-profile "$PROFILE" --output-format json > "$ROOT/notarization-result.json"
fi
STATUS=$(/usr/bin/plutil -extract status raw -o - "$ROOT/notarization-result.json")
[ "$STATUS" = Accepted ] || { echo "Notarization is $STATUS. Resume this saved submission; do not resubmit." >&2;exit 1; }
xcrun notarytool log "$SUBMISSION" --keychain-profile "$PROFILE" "$ROOT/notarization-log.json"
xcrun stapler staple "$APP";xcrun stapler validate "$APP"
./scripts/verify-candidate.sh "$APP" > "$ROOT/verification.txt" 2>&1
spctl --assess --type execute --verbose=4 "$APP" > "$ROOT/gatekeeper.txt" 2>&1
VERSION=$(cat VERSION);ARCHIVE="LeviOsa-v${VERSION}-macOS-arm64.zip"
[ ! -e "$ROOT/$ARCHIVE" ] || { echo 'Final archive already exists; refusing overwrite.' >&2;exit 1; }
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/$ARCHIVE"
./scripts/generate-update-feed.sh "$ROOT/$ARCHIVE" "$ROOT/appcast.xml" > "$ROOT/feed-generation.log" 2>&1
(cd "$ROOT" && shasum -a 256 "$ARCHIVE" appcast.xml > SHA256SUMS.txt)
printf 'Signed and notarized local candidate ready: %s\nNothing published.\n' "$ROOT"
