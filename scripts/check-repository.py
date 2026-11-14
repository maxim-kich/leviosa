#!/usr/bin/env python3
"""Audit the proposed public file inventory without printing sensitive values."""
import base64
import pathlib
import re
import subprocess
import sys

root=pathlib.Path(__file__).resolve().parents[1]
roots=['README.md','CONTRIBUTING.md','GOVERNANCE.md','SECURITY.md','PRIVACY.md','ACKNOWLEDGEMENTS.md','CHANGELOG.md','LICENSE','VERSION','build.sh','test.sh','.gitignore','.gitattributes','.github','assets','config','Sources','Tests','scripts','vendor','docs/usage.md','docs/development.md','docs/testing.md','docs/releases.md','docs/updater.md','docs/release-notes-0.0.1.md','docs/licenses']
files=[]
for name in roots:
 p=root/name
 if not p.exists():raise SystemExit('Missing publication path: '+name)
 files.extend([p] if p.is_file() else [f for f in p.rglob('*') if f.is_file() or f.is_symlink()])
files=sorted(set(p for p in files if '__pycache__' not in p.parts and p.suffix!='.pyc' and p.name!='.DS_Store'))
patterns=[('private-key header',re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),('GitHub credential',re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{60,})')),('local absolute home path',re.compile('/'+'Users/'+r'[^/\s]+/'))]
failures=[]
for p in files:
 if p.is_symlink():
  if not p.resolve().is_relative_to(root):failures.append((p,'external symlink'))
  continue
 if p.suffix in ['.swift','.c','.h','.py','.sh','.md','.txt','.yml','.svg'] or p.name=='LICENSE':
  try:text=p.read_text()
  except UnicodeDecodeError:continue
  for label,pattern in patterns:
   if pattern.search(text):failures.append((p,label))
  for target in re.findall(r'\]\(([^)]+)\)',text) if p.suffix=='.md' else []:
   if target.startswith(('http:','https:','#','mailto:')):continue
   target=target.split('#')[0]
   if target and not (p.parent/target).exists():failures.append((p,'missing relative documentation link'))
key=(root/'config/sparkle-public-key.txt').read_text().strip()
assert len(base64.b64decode(key,validate=True))==32
version=(root/'VERSION').read_text().strip();assert re.fullmatch(r'\d+\.\d+\.\d+',version)
if failures:
 for p,label in failures:print(str(p.relative_to(root))+': '+label,file=sys.stderr)
 raise SystemExit(1)
if '--list' in sys.argv:
 print('\n'.join(str(p.relative_to(root)) for p in files))
else:print('PASS: public inventory, local links, credential-pattern scan, symlinks, version and public update key ('+str(len(files))+' files)')
