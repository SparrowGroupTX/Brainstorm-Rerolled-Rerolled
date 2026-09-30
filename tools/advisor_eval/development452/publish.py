"""Publish only the five explicitly archived navigation replacements."""
from pathlib import Path
import json,sys,shutil
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest
P=json.loads((H/'prework.json').read_text())
for rel,h in P['navigation_before'].items():
    assert file_digest(R/rel)==file_digest(H/'before'/rel)==h,rel
for rel in P['navigation_before']:
    source=H/'replacements'/Path(rel).name;assert source.is_file()
    shutil.copy2(source,R/rel)
print(json.dumps({'published':list(P['navigation_before']),
 'bytes_before':sum((H/'before'/r).stat().st_size for r in P['navigation_before']),
 'bytes_after':sum((R/r).stat().st_size for r in P['navigation_before'])}))
