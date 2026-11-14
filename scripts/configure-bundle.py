#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import base64
import pathlib
import plistlib
import sys

output, bundle, version, minimum = sys.argv[1:5]
key = pathlib.Path(sys.argv[5] if len(sys.argv)>5 else 'config/sparkle-public-key.txt').read_text().strip()
if len(base64.b64decode(key, validate=True)) != 32:
    raise SystemExit('Invalid Sparkle public key')
info = dict(CFBundleExecutable='LeviOsa', CFBundleIdentifier=bundle,
    CFBundleName='LeviOsa', CFBundleDisplayName='LeviOsa', CFBundlePackageType='APPL',
    CFBundleIconFile='AppIcon', CFBundleShortVersionString=version, CFBundleVersion=version,
    LSMinimumSystemVersion=minimum, LSUIElement=True, NSHighResolutionCapable=True,
    SUFeedURL='https://github.com/maxim-kich/leviosa/releases/latest/download/appcast.xml',
    SUPublicEDKey=key, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False,
    SUAllowsAutomaticUpdates=False, SUEnableSystemProfiling=False,
    SUVerifyUpdateBeforeExtraction=True, SURequireSignedFeed=True,
    SUSignedFeedFailureExpirationInterval=0, SUShowReleaseNotes=False, SUEnableJavaScript=False)
path = pathlib.Path(output)
existing = plistlib.loads(path.read_bytes()) if path.exists() else {}
existing.update(info)
path.write_bytes(plistlib.dumps(existing))
