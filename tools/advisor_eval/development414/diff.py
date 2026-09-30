from pathlib import Path
import difflib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
pre=json.loads((HERE/'prework.json').read_text())
paths=['Brainstorm/Advisor/'+p+'.lua' for p in ('phase_copy','strategy','player_journal')]+['tests/advisor_runtime.lua','tests/advisor_perkeo_exit414.lua']
out=[]
for rel in paths:
 old=HERE/'before'/rel
 out.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before412/'+rel,tofile=rel))
(HERE/'focused_review.diff').write_text(''.join(out))
print('review diff written')
