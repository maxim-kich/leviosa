#!/bin/bash
set -euo pipefail
APP="$1"
codesign --verify --deep --strict "$APP"
codesign -dvv "$APP" 2>&1
xcrun vtool -show-build "$APP/Contents/MacOS/LeviOsa"
python3 - "$APP" <<'PYCODE'
import base64,pathlib,plistlib,struct,subprocess,sys
app=pathlib.Path(sys.argv[1]);info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.maximkich.leviosa'
assert info['CFBundleShortVersionString']==pathlib.Path('VERSION').read_text().strip()
assert info['LSMinimumSystemVersion']=='13.0'
assert len(base64.b64decode(info['SUPublicEDKey'],validate=True))==32
assert info['SURequireSignedFeed'] and info['SUVerifyUpdateBeforeExtraction']
assert not info['SUEnableAutomaticChecks'] and not info['SUEnableSystemProfiling']
assert (app/'Contents/Resources/AppIcon.icns').is_file()
for name,size in [('MenuBarIcon.png',18),('MenuBarIcon@2x.png',36)]:
 data=(app/('Contents/Resources/'+name)).read_bytes()
 assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(size,size)
 assert data==pathlib.Path('assets',name).read_bytes()
notices={'LICENSE.txt':'LICENSE','Sparkle-LICENSE.txt':'docs/licenses/Sparkle-LICENSE.txt'}
assert {p.name for p in (app/'Contents/Resources').glob('*LICENSE*.txt')}==set(notices)
for name,source in notices.items():assert (app/('Contents/Resources/'+name)).read_bytes()==pathlib.Path(source).read_bytes()
detail=subprocess.check_output(['codesign','-dvv',str(app)],stderr=subprocess.STDOUT).decode()
assert 'Authority=Developer ID Application:' in detail and 'runtime' in detail and 'Timestamp=' in detail
for item in ['Downloader.xpc','Installer.xpc']:
 subprocess.run(['codesign','--verify','--strict',str(app/f'Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/{item}')],check=True)
print('PASS: production identity, version, minimum OS, hardened runtime, timestamp, signed updater configuration, app/menu icons, notices and helpers')
PYCODE
