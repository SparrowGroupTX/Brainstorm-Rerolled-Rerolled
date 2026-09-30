"""C01: one fresh autonomous Red Gold attempt; no search/replay/fixture injection."""
from pathlib import Path
import json
import sys
import engine_probe
folder=Path(__file__).resolve().parent
recipe=json.loads((folder/'normal_opening_recipe.json').read_text())
print(json.dumps({'type':'normal_attempt_scope','attempt':'C01','seed':recipe['seed'],'deck':'b_red','stake':8,
                  'opening':'actual source two-Soul product route','later_offers':'unverified until actually observed',
                  'missing_gold_objective_context':'disabled; fixed-build survival baseline',
                  'profile':'all_unlocked_discovered_v1','retry_context':'disabled_clean',
                  'native_search_executed':False,'max_actions':500,'outer_seconds':180,'qualification':False}),flush=True)
sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed',recipe['seed'],
          '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
          '--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
          '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),'--episode','--debug-decisions']
raise SystemExit(engine_probe.main())
