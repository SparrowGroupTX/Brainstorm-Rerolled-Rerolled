"""Export public economic witnesses and descriptive cash-target classifications."""
from pathlib import Path
from collections import Counter
import sqlite3,json
P=Path(__file__).resolve().parent;OUT=P/'economic';OUT.mkdir(exist_ok=False)
ds=json.loads((P/'analysis/decisions.json').read_text());exits=json.loads((P/'analysis/shop_exits.json').read_text())
db=sqlite3.connect((P.parent/'development430/captures/002/events.sqlite3').as_uri()+'?mode=ro',uri=True)
def event(seq):return json.loads(db.execute('SELECT data FROM events WHERE seq=?',(seq,)).fetchone()[0])
above=[]
for d in exits:
 s=d['before'];target=25 if s['ante']>=7 else 35 if s['ante']>=4 else 50
 if s['dollars']<=target:continue
 public=event(d['observation_sequence'])['context']['snapshot']
 above.append({'run':d['run'],'request':d['sequence'],'observation':d['observation_sequence'],
  'advice':d['advice_sequence'],'settlement':d['settlement'],'cash':s['dollars'],'ante':s['ante'],
  'user_stage_target':target,'reroll_cost':s['reroll_cost'],'late_spend_review':d['advice'].get('late_spend_review'),
  'shop_boosters':[{'key':c.get('key'),'cost':c.get('cost'),'id':c.get('id')}for c in public.get('shop_booster',[])],
  'row':s['jokers'],'lines':d['advice'].get('lines')})
cases={
 'full_inventory_fool_jupiter':[2215,2219,2222,2223,2226,2228],
 'owned_blueprint_blocks_buffoon':[2995,2998,3001,3002,3005,3007],
 'visible_blueprint_focused_fallback':[30194,30197,30200,30202,30208,30211,30212,30215],
 'unaffordable_brainstorm_and_hit_road':[26213,26216,26219,26224,26225,26229,26234,26245],
 'final_leaf_sales':[15553,15557,15572,30549,30553,30606],
 'pack_conflicts':[5308,27134],
 'known_hook_target_mislabeled':[next(d['observation_sequence']for d in ds if d['sequence']==26854),
  next(d['advice_sequence']for d in ds if d['sequence']==26854),26854]}
anchors={}
for name,sequences in cases.items():
 rows=[]
 for seq in sequences:
  segment,ordinal,raw_sha=db.execute('SELECT segment,ordinal,raw_sha FROM events WHERE seq=?',(seq,)).fetchone()
  rows.append({'sequence':seq,'segment':segment,'ordinal':ordinal,'raw_sha256':raw_sha,'event':event(seq)})
 anchors[name]=[{k:v for k,v in row.items()if k!='event'}for row in rows]
 (OUT/(name+'.json')).write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
statuses=Counter((d['late_spend_review']or{}).get('status','missing')for d in above)
summary={'cash_target_exits':len(above),'total_shop_exits':len(exits),'spending_receipt_status':dict(statuses),
 'cash_exits_are_not_all_proven_errors':True,'cases':anchors,'policy_or_scorer_executed':False}
for name,value in {'above_cash_targets':above,'summary':summary}.items():
 (OUT/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'cash_target_exits':len(above),'total_shop_exits':len(exits),'status_counts':dict(statuses),'cases':list(cases)}))
