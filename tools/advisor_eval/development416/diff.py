from pathlib import Path
import difflib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
pre=json.loads((HERE/'prework.json').read_text())
paths=['Brainstorm/Advisor/'+p+'.lua' for p in ('acorn_discard','consumables','decision','growth','runtime','scoring','search','strategy')]
paths+=['tests/advisor_runtime.lua','tests/fixtures/repair416.lua']
paths+=['tests/advisor_'+p+'416.lua' for p in ('acorn_discard','mouth_planning','shop_shortfall','teacher_rescue','visible_discard')]
out=[]
for rel in paths:
 old=HERE/'before'/rel
 out.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before414/'+rel,tofile=rel))
(HERE/'focused_review.diff').write_text(''.join(out),encoding='utf-8')
print('review diff written')
