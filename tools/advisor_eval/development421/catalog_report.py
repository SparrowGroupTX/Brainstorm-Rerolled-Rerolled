"""Summarize manufactured150-Joker utility probes; never replay public captures."""
from pathlib import Path
import json
P=Path(__file__).resolve().parent
cols=['high_card','pair','full_house','straight','flush','king_pair'];rows=[]
for line in (P/'catalog_audit_final.log').read_text(encoding='utf-8-sig').splitlines():
 if not line.startswith('AUDIT\t'):continue
 _,key,name,known,old,*vs=line.split('\t')
 rows.append({'key':key,'name':name,'baseline_known':known=='true','baseline_pair':float(old),'contexts':dict(zip(cols,map(float,vs)))})
assert len(rows)==150
(P/'catalog_audit.json').write_text(json.dumps({'scope':'Manufactured static utility comparison, not captured replay or outcome evidence. Values precede complete-row admission/scoring.','rows':rows},indent=2))
missing=[r['key'] for r in rows if not r['baseline_known']]
(P/'CATALOG.md').write_text('# All150 Joker valuation audit421\n\nManufactured public contexts share a Yorick/Perkeo row and differ only in played/leveled hand or owned King population. Utility units are heuristic, not chips or win probability. Actual purchases still require legal resources, admission and available paired scoring. Original game.lua center metadata was parsed as literal data; no original code executed.\n\nBaseline420 had28 generic-unknown identities: '+', '.join('`'+k+'`' for k in missing)+'. These now have explicit bounded teacher values. Generic/collection objectives retain their rating contract.\n\n| Joker | Old known | Old Pair | High Card | Pair | Full House | Straight | Flush | King Pair |\n|---|---|---:|---:|---:|---:|---:|---:|---:|\n'+''.join('| '+r['name']+' | '+str(r['baseline_known'])+' | '+str(r['baseline_pair'])+' | '+' | '.join(str(r['contexts'][c]) for c in cols)+' |\n' for r in rows)+'\nThese six contexts expose hand-dependence and missing branches, not every possible strategy. Random triggers, exact future draw availability, best-card placement, complete edition/order interactions and delayed causal win-rate remain governed by supported scoring or unresolved. Do not interpret unchanged rows as proof of optimal value.\n')
print(json.dumps({'rows':len(rows),'formerly_unknown':len(missing),'varying_across_contexts':sum(len(set(r['contexts'].values()))>1 for r in rows)}))
