"""C03: one selected302 normal Gold source attempt; never controls the game."""
from pathlib import Path
import json,sys
import engine_probe
folder=Path(__file__).resolve().parent
recipe=json.loads((folder/'normal_opening_recipe.json').read_text())
print(json.dumps({'type':'normal_attempt_scope','attempt':'C03','seed':recipe['seed'],'deck':'b_red','stake':8,
 'selected_development':True,'profile':'all_unlocked_discovered_v1','max_actions':500,
 'outer_seconds':180,'qualification':False,'native_search_executed':False,'retry_context':'disabled_clean',
 'copy_branch_observed':False,'gold_objective_context':'disabled'}),flush=True)
sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed',recipe['seed'],
 '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
 '--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
 '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),'--episode','--debug-decisions']
raise SystemExit(engine_probe.main())
