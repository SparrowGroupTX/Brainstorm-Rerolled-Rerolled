"""M06 bounded normal opening qualification. Never play/select the first blind."""
from pathlib import Path
import sys
import engine_probe
folder=Path(__file__).resolve().parent
sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed','M4BVSY11',
          '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
          '--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
          '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),'--episode','--debug-decisions',
          '--stop-on-opening-complete','--opening-only-actions','--stop-after-step','10']
raise SystemExit(engine_probe.main())
