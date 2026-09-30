"""Additional descriptive cohort checks. No runtime modules or policy evaluation."""
from pathlib import Path
import json, sqlite3
from collections import Counter
P=Path(__file__).resolve().parent; O=P/'followup'; O.mkdir(exist_ok=False)
db=sqlite3.connect((P/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
load=lambda n:json.loads((P/n).read_text())
ds=load('analysis/decisions.json'); packs=load('deep2/pack_choices.json')
def state(seq):return json.loads(db.execute('select data from events where seq=?',(seq,)).fetchone()[0])['context']['snapshot']
def short(d):return {k:d.get(k) for k in ('run','sequence','action','selected_card','advice','observation_sequence')}
def arr(x):return x if isinstance(x,list) else []
death=[]
for offer in load('catalog/death_offers.json'):
    choices=[p for p in packs if p['run']==offer['run'] and any(c.get('id')==offer['card']['id'] for c in p['offers'])]
    death.append({'offer':offer,'choices':choices})
buffoon=[]
for offer in load('catalog/buffoon_offers.json'):
    s=state(offer['last']); exits=[]
    for d in ds:
        if d['run']==offer['run'] and d['observation_sequence'] and offer['first']<=d['observation_sequence']<=offer['last'] and (d['action'] or {}).get('kind')=='leave_shop':exits.append(short(d))
    buffoon.append({'offer':offer,'last_cash':s.get('dollars'),'last_owned_blueprint':any(c.get('key')=='j_blueprint' for c in arr(s.get('jokers'))),
        'last_row':[c.get('key') for c in arr(s.get('jokers'))],'directly_affordable_at_last_observation':s.get('dollars',0)>=offer['card'].get('cost',100000),'exits':exits})
critical={14069,14081,14091,14102,6735,7406,12464,4857}
lastshops=[]
for run in (3,4,7,9):
    shop=[d for d in ds if d['run']==run and (d['action'] or {}).get('kind')=='leave_shop']
    for d in shop[-2:]:
        s=state(d['observation_sequence'])
        lastshops.append({'decision':short(d),'public_state':s})
jpacks=[p for p in packs if any(c.get('key','').startswith('j_') for c in p['offers'])]
score=[{'run':r['run'],'request':r['request']['sequence'],'predicted':r['predicted_display_approx'],'actual':r['observed_chip_delta'],
        'ratio':r['observed_chip_delta']/max(1,r['predicted_display_approx']),'lines':r['lines'],'jokers':[c.get('key') for c in r['jokers']]} for r in load('deep2/score_divergences.json')]
reroll=Counter();truncated=Counter()
for d in ds:
    g=d['advice'].get('gold_review') or {}
    if g.get('reroll'):reroll[str(g['reroll'])]+=1
    if g.get('shop_truncated'):truncated[d['run']]+=1
out={'death':death,'buffoon':buffoon,'joker_pack_choices':jpacks,'last_shops_before_loss':lastshops,
    'critical_decisions':[short(d) for d in ds if d['sequence'] in critical],'score_divergences':score,
    'summary':{'joker_pack_choices':len(jpacks),'unopened_buffoons':sum(not b['offer']['actions'] for b in buffoon),
        'unopened_directly_affordable':sum(not b['offer']['actions'] and b['directly_affordable_at_last_observation'] for b in buffoon),
        'unopened_affordable_without_blueprint':sum(not b['offer']['actions'] and b['directly_affordable_at_last_observation'] and not b['last_owned_blueprint'] for b in buffoon),
        'actual_rerolls':sum((d['action'] or {}).get('kind')=='reroll' for d in ds),'gold_shop_truncated':dict(truncated)}}
for k,v in out.items():(O/(k+'.json')).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
print(json.dumps(out['summary']))
print('Death offers:',[(x['offer']['run'],x['offer']['first'],[(d['request'],d['chosen'],d['title']) for d in x['choices']]) for x in death])
print('Joker choices:',[(x['run'],x['request'],x['chosen'],[(c['key'],c.get('edition'),c.get('ability',{}).get('perishable'),c.get('ability',{}).get('eternal'),c.get('ability',{}).get('rental')) for c in x['offers']],x['receipt']) for x in jpacks])
print('Scores:',[(s['run'],s['request'],s['predicted'],s['actual'],round(s['ratio'],2),s['jokers']) for s in score])
