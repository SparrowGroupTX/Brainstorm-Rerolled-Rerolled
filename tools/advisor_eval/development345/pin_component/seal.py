from pathlib import Path
import hashlib,json
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
module='Brainstorm/Advisor/gold_tarot_hold.lua'
files=[OUT/module,OUT/'before'/module,*sorted((OUT/'tests').glob('*.lua')),OUT/'validation.json',OUT/'validate.py']
report={'schema':1,'scope':'Staged raw constructor absent-pin normalization and manufactured fixtures only.',
  'before_sha256':sha(OUT/'before'/module),'after_sha256':sha(OUT/module),
  'runtime_worktree_untouched':sha(ROOT/module)==sha(OUT/'before'/module),
  'finding':'Card:init does not set pinned. copy_card transfers the absent field unchanged. Snapshot normalizes absent to false, but the source certificate checked raw false only.',
  'change':'Raw nil and false both qualify as unpinned. True and all other malformed values still reject. Normalized snapshot false requirement is unchanged.',
  'source_provenance':{
    'tools/advisor_eval/runs/chicot_order_source1/source/card.lua':{'sha256':sha(ROOT/'tools/advisor_eval/runs/chicot_order_source1/source/card.lua'),'lines':'5-72'},
    'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua':{'sha256':sha(ROOT/'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua'),'lines':'2156-2181'},
    'Brainstorm/Advisor/snapshot.lua':{'sha256':sha(ROOT/'Brainstorm/Advisor/snapshot.lua'),'lines':'33-53'}},
  'files':{str(p.relative_to(ROOT)):sha(p) for p in files},
  'validation':'Two original344 failures reproduced;52 raw capture/guard checks and67 production Runtime/Decision checks pass after fix, including complete sale then fresh purchase. Every fixture capped at60 seconds.',
  'limits':'No original-source execution, captured-state replay, save/profile read, search, complete attempt, game control or runtime installation. No claim the logged run is rescued.'}
with (OUT/'component_report.json').open('x',encoding='utf-8') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(OUT/'component_report.json'),'sha256':sha(OUT/'component_report.json'),'runtime_worktree_untouched':report['runtime_worktree_untouched']}))
