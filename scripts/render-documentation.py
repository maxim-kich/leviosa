#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["markdown-it-py==4.0.0"]
# ///
"""Render every proposed public documentation file, in full, for owner approval."""
import base64
import hashlib
import html
import json
import pathlib
import posixpath
import subprocess
from markdown_it import MarkdownIt

root=pathlib.Path(__file__).resolve().parents[1]
paths=[pathlib.Path(p) for p in subprocess.check_output(['python3','scripts/check-repository.py','--list'],cwd=root,text=True).splitlines()]
paths=[p for p in paths if p.suffix=='.md' or p.name in ['LICENSE','Sparkle-LICENSE.txt']]
order=['README.md','ACKNOWLEDGEMENTS.md','CONTRIBUTING.md','PRIVACY.md','SECURITY.md','GOVERNANCE.md','CHANGELOG.md','LICENSE','docs/usage.md','docs/development.md','docs/testing.md','docs/updater.md','docs/releases.md','docs/release-notes-0.0.1.md','docs/licenses/README.md','docs/licenses/Sparkle-LICENSE.txt','docs/licenses/provenance.md','config/README.md','vendor/README.md']
paths.sort(key=lambda p:(order.index(str(p)) if str(p) in order else len(order),str(p)))
md=MarkdownIt('commonmark',{'html':False})
lookup={str(p):'doc-'+str(i) for i,p in enumerate(paths)}
current_path=pathlib.Path('README.md')
def link_open(tokens,idx,options,env):
 href=tokens[idx].attrGet('href') or ''
 if not href.startswith(('https:','http:','mailto:','#')):
  target=posixpath.normpath(str(current_path.parent/href.split('#')[0]))
  if target in lookup:tokens[idx].attrSet('href','#'+lookup[target])
 return md.renderer.renderToken(tokens,idx,options,env)
md.renderer.rules['link_open']=link_open
sections=[];manifest=[]
for i,p in enumerate(paths):
 current_path=p
 raw=(root/p).read_text();digest=hashlib.sha256(raw.encode()).hexdigest()
 if p==pathlib.Path('README.md'):
  header='<p align="center"><img src="assets/app-icon.png" width="128" alt="LeviOsa icon"></p>'
  assert raw.startswith(header)
  image=base64.b64encode((root/'assets/app-icon.png').read_bytes()).decode()
  content='<p style="text-align:center"><img src="data:image/png;base64,'+image+'" width="128" alt="LeviOsa icon"></p>'+md.render(raw[len(header):])
 else:content=md.render(raw) if p.suffix=='.md' else '<pre>'+html.escape(raw)+'</pre>'
 sections.append('<details id="doc-'+str(i)+'" '+('open' if p==pathlib.Path('README.md') else '')+'><summary>'+html.escape(str(p))+'</summary><div class="document">'+content+'</div></details>')
 manifest.append({'path':str(p),'sha256':digest})
style='body{margin:0;color:var(--foreground);font:14px/1.6 var(--font-sans)}h1{font-size:24px}h2{font-size:19px}h3{font-size:16px}a{color:var(--primary)}.intro{margin-bottom:20px}.intro p{margin:8px 0;color:var(--muted-foreground)}details{border-top:1px solid var(--border);padding:12px 0}summary{cursor:pointer;font-weight:600;overflow-wrap:anywhere}.document{padding:4px 0 12px}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:var(--code-background);padding:16px;border-radius:var(--radius);font:12px/1.6 var(--font-mono)}code{font-family:var(--font-mono);font-size:12px}blockquote{border-left:2px solid var(--border);margin-left:0;padding-left:16px;color:var(--muted-foreground)}'
intro='<div class="intro"><h1>LeviOsa 0.0.1 · documentation approval</h1><p>Complete public texts: a short product README, concise project policies, technical guides in docs/, and full notices in docs/licenses/. Candidate reports and approval evidence remain local. Nothing has been published. Expand each file to review it; signed-candidate acceptance remains separate.</p><p>'+str(len(paths))+' documents · source and content hashes saved alongside this packet.</p></div>'
output=root/'build/documentation-review';output.mkdir(parents=True,exist_ok=True)
(output/'index.html').write_text('<!doctype html><html><head><meta charset="utf-8"><style>'+style+'</style></head><body>'+intro+''.join(sections)+'<script>document.addEventListener("click",e=>{const a=e.target.closest("a");if(a&&a.hash.startsWith("#doc-")){const d=document.getElementById(a.hash.slice(1));if(d)d.open=true;}});</script></body></html>')
(output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Rendered '+str(len(paths))+' complete public documents: '+str(output/'index.html'))
