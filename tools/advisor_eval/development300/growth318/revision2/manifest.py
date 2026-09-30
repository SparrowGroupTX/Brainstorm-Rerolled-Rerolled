"""Freeze detached revision2 provenance; no policy/source/native execution."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
names = ('growth.lua','advisor_growth_additive.lua','detached_test.lua','existing_fixtures.lua','INTEGRATION.md','manifest.py',
         'stage_additive319.py','canonical_metadata_audit.py','canonical_metadata_audit.json')
files = {name:sha(HERE/name) for name in names}
base = ROOT/'tools/advisor_eval/runs/copy315_installed/policy/Brainstorm/Advisor/growth.lua'
fixtures = ['advisor_growth','advisor_growth_opportunities','advisor_growth_retained_steel',
            'advisor_weighted_growth','advisor_burnt_population','advisor_burnt_fallback']
record = {'schema':1,'development_label':'growth318/revision2','candidate_checkpoint':319,
          'release_number_reserved_by_root_for_other_work':318,'files':files,
          'stage':{'growth.lua':'Brainstorm/Advisor/growth.lua','advisor_growth_additive.lua':'tests/advisor_growth_additive.lua'},
          'preserved_revision1_manifest_sha256':sha(HERE.parent/'manifest.json'),
          'superseded_revision2_manifest_sha256':sha(HERE/'manifest.pre_resource.json'),
          'superseded_pre_history_manifest_sha256':sha(HERE/'manifest.final.json'),
          'preserved_review_inputs':{name:sha(HERE/name) for name in
             ('growth.pre_held_glass.lua','advisor_growth_additive.pre_resource.lua')},
          'baseline':{'path':str(base.relative_to(ROOT)),'sha256':sha(base)},
          'unchanged_dependencies':{str(p.relative_to(ROOT)):sha(p) for p in
             [ROOT/'Brainstorm/Advisor'/name for name in ('scoring.lua','strategy.lua','search.lua','snapshot.lua','decision.lua')]},
          'existing_fixtures':{name:sha(ROOT/'tests'/(name+'.lua')) for name in fixtures},
          'validation':{'command':'python -B tests/run_lua_tests.py tools/advisor_eval/development300/growth318/revision2/detached_test.lua tools/advisor_eval/development300/growth318/revision2/existing_fixtures.lua',
                        'passed':True,'new_checks':2558,'existing_checks':384,'total_checks':2942,
                        'manufactured_or_existing_pure_fixtures_only':True,'new_source_or_native_experiments':0},
          'installed_by_this_agent':False,'runtime_worktree_edited':False}
with (HERE/'manifest.reviewed.json').open('x',encoding='utf8') as f: json.dump(record,f,indent=2)
print(json.dumps({'manifest_sha256':sha(HERE/'manifest.reviewed.json'),'stage_hashes':{name:files[name] for name in record['stage']}},indent=2))
