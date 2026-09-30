from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'scope':'Staged Gold retention module and manufactured actual-production dependency fixtures; root integration/installation pending.',
 'contract':'reserve(snapshot,limit) reserves min(limit,8000) inside the existing shared shop allowance only for eligible supported winning-Ante missing cargo. suggest(snapshot,modules,base,remaining,yield_fn) returns suggestion-or-nil, actual_floor_calls, diagnostics.',
 'comparison':'One complete same-world comparison of the exact paid incumbent endpoint against the current hold endpoint, four public-composition worlds, fixed current physical order perendpoint, all original consumables held. Explicit sale-first incumbent must have a complete matching shop_sequence or followup and at most one sale/two visible Joker buys. Only strict distinct missing-key loss can be overridden.',
 'guards':'Small/Big/Vessel/Leaf only in winning Ante; eligible complete Gold metadata; exact whole inventory and population; supported stable/Joker startup and Perkeo certificates for both endpoints; actual paid transition legality, cash/borrow and Negative capacities; hold floor >=125%nexttarget and complete reserves; warning-free supported random floors; fully charged shared-budget work; no partial or unsupported override.',
 'reserve_limit':'8000 is a reservation within50000, not addedcompute. Some largerhands or unsupportedcomparisons mayfail or exhaust remainingbudget; nooverride in thatcase. Unusedreservation mayremainunused whenordinaryactiondoesnotneedreview.',
 'validation':'validation_04 passes56 manufacturedchecks with actual initialized production Shop/Scoring/transition dependencies. First harness expected1floor undercap1 but Shop preflight correctly performed0; failurepreserved in validation_01. Corrected assertions check actual boundedwork; failed floorqualification explicitly tests positive spentwork accounting.',
 'files':{},'root_runtime_edited':False,
 'limitations':'No observed playerpolicy replay, neworiginalsource worker, live game control, save/profile read, search, fullattempt orterminalvalidation. Doesnotclaimpriorloggedrunwouldgainsticker. Only declared paid Joker sequences; bare sales, Tarotuse, reorders andunsupportedbossesretainordinarybehavior.'}
for p in [OUT/'Brainstorm/Advisor/gold_retention.lua',OUT/'tests/advisor_gold_retention.lua',*sorted(OUT.glob('validation_*.json')),OUT/'validate.py']:
 report['files'][str(p.relative_to(ROOT))]=sha(p)
with (OUT/'component_report.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(OUT/'component_report.json'),'sha256':sha(OUT/'component_report.json')}))
