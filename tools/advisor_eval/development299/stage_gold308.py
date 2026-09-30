"""Merge independent reviewed Gold comparison drafts over exact installed307."""
from pathlib import Path
import difflib,hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
BELL=HERE/'drafts/bell_opening'
PERKEO=HERE/'drafts/gold_perkeo'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((ROOT/'tools/advisor_eval/runs/fallback307_installed/record.json').read_text())
validation=json.loads((ROOT/'tools/advisor_eval/runs/fallback307_installed_validation/report.json').read_text())
assert validation['passed']
changes={}
for name in ('shop_scoring.lua','shop_sequences.lua','gold_goal.lua','runtime.lua'):
    relative='Brainstorm/Advisor/'+name
    assert sha(ROOT/relative)==record['policy']['policy_files'][relative],relative
    changes[relative]=(ROOT/relative).read_text()
base=changes['Brainstorm/Advisor/gold_goal.lua']
assert hashlib.sha256((ROOT/'Brainstorm/Advisor/gold_goal.lua').read_bytes()).hexdigest()==json.loads((PERKEO/'base.json').read_text())['sha256']
for name in ('shop_scoring.lua','shop_sequences.lua','gold_goal.lua'):
    changes['Brainstorm/Advisor/'+name]=(BELL/name).read_text()
for name,expected in json.loads((BELL/'integration_base_sha256.json').read_text()).items():
    assert sha(ROOT/name)==expected,name
# Merge Perkeo's nonoverlapping endpoint/certificate edits into the Bell draft.
# Require each reviewed replaced span exactly once. Zero context intentionally
# keeps Bell's immediately adjacent setup-action receipt fields intact.
old=base.splitlines(keepends=True)
new=(PERKEO/'gold_goal.lua').read_text().splitlines(keepends=True)
merged=changes['Brainstorm/Advisor/gold_goal.lua']
for group in difflib.SequenceMatcher(None,old,new,autojunk=False).get_grouped_opcodes(0):
    before=''.join(old[group[0][1]:group[-1][2]])
    after=''.join(new[group[0][3]:group[-1][4]])
    assert before and merged.count(before)==1,'Overlapping Gold edits require review'
    merged=merged.replace(before,after,1)
changes['Brainstorm/Advisor/gold_goal.lua']=merged
runtime=changes['Brainstorm/Advisor/runtime.lua']
old_load="A.gold_goal = module('gold_goal')"
assert runtime.count(old_load)==1
runtime=runtime.replace(old_load,"A.gold_perkeo = module('gold_perkeo')\nA.bell_opening = module('bell_opening')\n"+old_load)
old_bind="A.shop_scoring = module('shop_scoring')"
assert runtime.count(old_bind)==1
runtime=runtime.replace(old_bind,old_bind+'\nA.shop_scoring.bell_opening=A.bell_opening')
changes['Brainstorm/Advisor/runtime.lua']=runtime
for filename,folder in (('bell_opening.lua',BELL),('gold_perkeo.lua',PERKEO)):
    relative='Brainstorm/Advisor/'+filename
    assert not (ROOT/relative).exists(),relative
    changes[relative]=(folder/filename).read_text()
for source,relative,folder in (('install_advisor_bell_opening.lua','tests/advisor_bell_opening.lua',BELL),
                               ('test_gold_perkeo.lua','tests/advisor_gold_perkeo.lua',PERKEO)):
    assert not (ROOT/relative).exists(),relative
    text=(folder/source).read_text()
    text=text.replace(folder.relative_to(ROOT).as_posix()+'/', 'Brainstorm/Advisor/')
    assert 'development299/drafts/' not in text,relative
    changes[relative]=text
target=HERE/'gold308_stage.json'
assert not target.exists()
receipt={name:{'before_sha256':sha(ROOT/name) if (ROOT/name).exists() else None,
               'after_sha256':hashlib.sha256(data.encode()).hexdigest()} for name,data in changes.items()}
for name,data in changes.items():
    with (ROOT/name).open('w',encoding='utf-8',newline='\n') as stream:stream.write(data)
with target.open('x') as stream:json.dump(receipt,stream,indent=2);stream.write('\n')
print(json.dumps({'staged_files':len(changes),'receipt':str(target)}))
