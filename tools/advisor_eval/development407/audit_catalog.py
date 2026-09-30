"""Public offer and Glass-exposure inventory; never reconstruct alternative draws."""
from pathlib import Path
from collections import Counter,defaultdict
import json,re,sqlite3
P=Path(__file__).resolve().parent;OUT=P/'catalog';OUT.mkdir(exist_ok=False)
db=sqlite3.connect((P/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
ds=json.loads((P/'analysis/decisions.json').read_text());runs=json.loads((P/'analysis/runs.json').read_text())
def arr(v):return v if isinstance(v,list) else []
def view(c):return {k:c.get(k) for k in ('id','key','rank','suit','enhancement','edition','seal','cost','sell_cost','ability','debuff')}
selected=defaultdict(list)
for d in ds:
    if d['selected_card'].get('id'):
        selected[(d['run'],d['selected_card']['id'])].append({'sequence':d['sequence'],'action':d['action'],'title':d['advice'].get('title')})
offers={};owned={};hand_counts=defaultdict(Counter);max_inventory={};glass=[]
for seq,run,raw in db.execute("select seq,run,data from events where kind='teacher_observation' and run>0 order by seq"):
    s=json.loads(raw)['context']['snapshot']
    inventory=arr(s.get('consumeables'));counts=Counter(c.get('key') for c in inventory)
    for key,count in counts.items():
        if count>max_inventory.get((run,key),{}).get('count',0):max_inventory[(run,key)]={'run':run,'key':key,'count':count,'sequence':seq,'ante':s.get('ante')}
    for area in ('jokers','consumeables'):
        for c in arr(s.get(area)):owned.setdefault((run,c.get('id')),seq)
    for area in ('shop_jokers','pack_cards','shop_booster','shop_vouchers'):
        for c in arr(s.get(area)):
            key=(run,c.get('id'))
            if not c.get('id') or c.get('identity_redacted') or c.get('face_down'):continue
            row=offers.setdefault(key,{'run':run,'card':view(c),'area':area,'first':seq,'last':seq,
                'first_cash':s.get('dollars'),'ante':s.get('ante'),'round':s.get('round'),
                'joker_row':[view(j) for j in arr(s.get('jokers'))], 'first_inventory':dict(counts),
                'actions':selected.get(key,[])})
            row['last']=seq
for key,row in offers.items():row['first_owned']=owned.get(key)

for d in ds:
    action=d['action'] or {}
    if action.get('kind')!='play':continue
    e=json.loads(db.execute('select data from events where seq=?',(d['observation_sequence'],)).fetchone()[0]);s=e['context']['snapshot'];hand=arr(s.get('hand'))
    selected_cards=[hand[i-1] for i in action.get('indices',[])];fragile=[c for c in selected_cards if c.get('enhancement')=='m_glass' and not c.get('debuff')]
    if not fragile:continue
    following=next((x['sequence'] for x in ds if x['run']==d['run'] and x['sequence']>d['sequence'] and x['action']),next(r['end']['sequence'] for r in runs if r['run']==d['run']))
    after=None;afterseq=None
    for seq,raw in db.execute("select seq,data from events where kind='teacher_observation' and run=? and seq>? and seq<? order by seq",(d['run'],d['sequence'],following)):
        x=json.loads(raw)['context']['snapshot']
        if x.get('phase') in ('hand','round') and x.get('round')==s.get('round'):
            after,afterseq=x,seq;break
    alternatives=[];needed=(s.get('blind') or {}).get('chips',0)-s.get('chips',0)
    for line in d['advice'].get('lines',[]):
        m=re.match(r'Alternative:.*?~([0-9]+).*?\((.*)\)',line)
        if not m:continue
        indices=[int(i) for i in re.findall(r'#(\d+)',m[2])]
        if indices and all(1<=i<=len(hand) and hand[i-1].get('enhancement')!='m_glass' for i in indices) and int(m[1])>=needed*1.05:
            alternatives.append({'display':line,'indices':indices,'estimated_margin':int(m[1])/max(1,needed)})
    glass.append({'run':d['run'],'request':d['sequence'],'ante':s.get('ante'),'round':s.get('round'),
        'selected_glass':[view(c) for c in fragile],'need':needed,'advice':d['advice'],
        'confirmed_later_observation':afterseq,'selected_glass_ids_absent_after':
            [c['id'] for c in fragile if c['id'] not in {x.get('id') for x in arr((after or {}).get('playing_cards'))}] if after else None,
        'displayed_non_glass_clearing_alternatives':alternatives,'alternative_safety_not_replayed':True})

buffoons=[o for o in offers.values() if 'buffoon' in str(o['card'].get('key'))]
death=[o for o in offers.values() if o['card'].get('key')=='c_death']
summary={'distinct_visible_offers':len(offers),'death_offers':len(death),'death_chosen_or_bought':sum(any((a['action'] or {}).get('kind') in ('choose','buy') for a in o['actions']) for o in death),
    'glass_play_actions':len(glass),'glass_card_exposures':sum(len(g['selected_glass']) for g in glass),
    'glass_ids_absent_after_play':sum(len(g['selected_glass_ids_absent_after'] or []) for g in glass),
    'glass_plays_with_displayed_non_glass_clear':sum(bool(g['displayed_non_glass_clearing_alternatives']) for g in glass),
    'buffoon_by_run':[{'run':r['run'],'offered':sum(o['run']==r['run'] for o in buffoons),'opened':sum(o['run']==r['run'] and any((x['action'] or {}).get('kind')=='open' for x in o['actions']) for o in buffoons)} for r in runs]}
for name,value in {'all_offers':list(offers.values()),'death_offers':death,'buffoon_offers':buffoons,'glass_exposure':glass,'inventory_maxima':list(max_inventory.values()),'summary':summary}.items():
    (OUT/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary))
