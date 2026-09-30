"""Adapt the preceding release mechanics; never change closed historical files."""
from pathlib import Path
H=Path(__file__).resolve().parent;E=H.parents[1]
def write(name,text):
    with(H/name).open('x',encoding='utf-8')as f:f.write(text)
capture=(H.parent/'capture.py').read_text()
capture=capture.replace('EVAL=HERE.parent;ROOT=EVAL.parents[1]','EVAL=HERE.parents[1];ROOT=EVAL.parents[1]')
write('capture.py',capture)
release=(E/'development450/install/release.py').read_text()
for old,new in [('validated 450 candidate','validated 451 candidate'),
 ('repair450_candidate1','repair451_candidate1'),('repair450_installed','repair451_installed'),
 ('development450/LATEST.json','development451/install/LATEST.json'),
 ('INSTALLED_CHECKPOINT_449.json','INSTALLED_CHECKPOINT_450.json'),
 ('changed_from_installed449','changed_from_installed450'),('== 382','== 383'),
 ('2.225.0-alpha','2.226.0-alpha'),
 ('Standing user authorization: install whenever ready after passive absence; current full session preserved, no normal-exit inference.',
  'Explicit user request to install 2.226; latest public journal bytes preserved, passive process absence verified, no normal-exit inference.')]:
    assert old in release,old
    release=release.replace(old,new)
write('release.py',release)
write('SCOPE.md','''# Install451 /2.226

Explicit request: "Install the new update." Mechanically install the unchanged
qualified candidate451. No runtime edits, new policy work or renewed review.
Preserve latest public journal bytes and all candidate/prior artifacts. Fresh
successful passive absence is required immediately before deployment; no game
control or normal-exit inference. Use existing install_slice, explicit three
changed paths, backups and hash verification. Keep current config and seven DLLs.
Freeze actual installed bytes and run the required full exact-installed gate.
Update installed checkpoint/navigation while preserving candidate history. Stop.
''')
print('Prepared capture and exact release helpers; no installed files touched.')
