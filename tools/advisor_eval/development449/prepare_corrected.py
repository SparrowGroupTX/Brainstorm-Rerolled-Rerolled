from pathlib import Path
import json,sys
H=Path(__file__).resolve().parent;E=H.parent;sys.path.insert(0,str(E))
from benchmark import file_digest
C=E/'runs/repair449_candidate1'
with(H/'unqualified_candidate1.json').open('x')as f:
 json.dump({'qualified':False,'reason':'Reviewer visibility blocker; candidate1 preserved. Initial validation was invoked before asynchronous freeze finished and exited before creating a validation directory; no gate ran.',
  'files':{str(p.relative_to(E.parents[1])).replace('\\','/'):file_digest(p)for p in C.rglob('*')if p.is_file()}},f,indent=2)
with(H/'freeze2.py').open('x')as f:f.write((H/'freeze.py').read_text().replace('repair449_candidate1','repair449_candidate2'))
p=H/'install/release.py';p.write_text(p.read_text().replace('repair449_candidate1','repair449_candidate2'))
