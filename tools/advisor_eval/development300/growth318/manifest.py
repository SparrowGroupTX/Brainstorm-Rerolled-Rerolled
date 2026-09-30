"""Hash detached implementation and pure-test provenance only; no runtime execution."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
files = {name: sha(HERE/name) for name in ('growth.lua','advisor_growth_additive.lua','detached_test.lua','existing_fixtures.lua','INTEGRATION.md','manifest.py')}
base = ROOT/'tools/advisor_eval/runs/copy315_installed/policy/Brainstorm/Advisor/growth.lua'
fixtures = ['advisor_growth','advisor_growth_opportunities','advisor_growth_retained_steel',
            'advisor_weighted_growth','advisor_burnt_population','advisor_burnt_fallback']
record = {'schema': 1, 'candidate_checkpoint': 318, 'files': files,
          'stage': {'growth.lua':'Brainstorm/Advisor/growth.lua','advisor_growth_additive.lua':'tests/advisor_growth_additive.lua'},
          'baseline': {'path':str(base.relative_to(ROOT)), 'sha256':sha(base)},
          'unchanged_dependencies':{str(p.relative_to(ROOT)):sha(p) for p in
             [ROOT/'Brainstorm/Advisor'/name for name in ('scoring.lua','strategy.lua','search.lua','snapshot.lua','decision.lua')]},
          'existing_fixtures':{name:sha(ROOT/'tests'/(name+'.lua')) for name in fixtures},
          'validation':{'command':'python -B tests/run_lua_tests.py tools/advisor_eval/development300/growth318/detached_test.lua tools/advisor_eval/development300/growth318/existing_fixtures.lua',
                        'passed':True,'new_checks':318,'existing_checks':384,'total_checks':702,
                        'manufactured_or_existing_pure_fixtures_only':True,'new_source_or_native_experiments':0},
          'installed_by_this_agent':False,'runtime_worktree_edited':False}
with (HERE/'manifest.json').open('x',encoding='utf8') as f: json.dump(record,f,indent=2)
print(json.dumps({'manifest_sha256':sha(HERE/'manifest.json'),'stage_hashes':{name:files[name] for name in record['stage']}},indent=2))
