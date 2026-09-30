"""Recorded late decision chains; no alternative gameplay evaluation."""
from pathlib import Path
import sqlite3,json
from collections import Counter
P=Path(__file__).resolve().parent;O=P/'late';O.mkdir(exist_ok=False)
db=sqlite3.connect((P/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
ds=json.loads((P/'analysis/decisions.json').read_text())
def snap(seq):return json.loads(db.execute('select data from events where seq=?',(seq,)).fetchone()[0])['context']['snapshot']
def card(c):return {k:c.get(k) for k in ('id','key','rank','suit','enhancement','edition','seal','debuff')}
uses=[];entries=[]
for d in ds:
    a=d['action']or{}
    if d['run']==9 and a.get('kind') in ('use','choose') and d['selected_card'].get('key')=='c_chariot':
        s=snap(d['observation_sequence']);h=s.get('hand',[])
        uses.append({'request':d['sequence'],'ante':s.get('ante'),'round':s.get('round'),'boss':s.get('blind_choices',{}).get('Boss'),
            'targets':[card(h[i-1]) for i in a.get('targets',[])], 'hand':[card(c) for c in h], 'lines':d['advice'].get('lines')})
    if d['run'] in (3,4,7,9) and a.get('kind')=='select_blind':
        s=snap(d['observation_sequence'])
        entries.append({'run':d['run'],'request':d['sequence'],'ante':s.get('ante'),'cash':s.get('dollars'),
            'blind_on_deck':s.get('blind_on_deck'),'row':s.get('jokers'),'inventory':s.get('consumeables'),
            'steel_population':[card(c) for c in s.get('playing_cards',[]) if c.get('enhancement')=='m_steel']})
counts=Counter();sale=[]
for d in ds:
    a=d['action']or{}
    if a.get('kind')=='sell' and a.get('area')=='jokers':
        sale.append({'run':d['run'],'request':d['sequence'],'key':d['selected_card'].get('key'),'title':d['advice'].get('title'),'followup':a.get('followup'),'lines':d['advice'].get('lines')})
    if d['advice'].get('reroll_review'):
        rr=d['advice']['reroll_review'];counts[rr.get('status')]+=1
for k,v in {'run9_chariot':uses,'loss_blind_entries':entries,'joker_sales':sale,'reroll_statuses':dict(counts)}.items():(O/(k+'.json')).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
print('Chariot',[(x['request'],x['ante'],[(t.get('rank'),t.get('suit')) for t in x['targets']],x['boss']) for x in uses])
print('Sales',[(x['run'],x['request'],x['key'],bool(x['followup'])) for x in sale])
print('Reroll statuses',dict(counts))
