"""Descriptive audit407 of copied public evidence; no policy/scorer imports."""
from pathlib import Path
from collections import Counter, defaultdict
from functools import lru_cache
import json, re, sqlite3

P=Path(__file__).resolve().parent;A=P/'analysis';OUT=P/'deep2';OUT.mkdir(exist_ok=False)
db=sqlite3.connect((P/'captures/001/events.sqlite3').as_uri()+'?mode=ro',uri=True)
read=lambda n:json.loads((A/n).read_text())
ds=read('decisions.json');runs=read('runs.json');screen=json.loads((P/'suspects/report.json').read_text())
ends={r['run']:r['end']['sequence'] for r in runs}
def arr(x):return x if isinstance(x,list) else []
@lru_cache(maxsize=256)
def event(seq):return json.loads(db.execute('select data from events where seq=?',(seq,)).fetchone()[0])
def snapshot(seq):return event(seq).get('context',{}).get('snapshot',{})
def anchor(seq):
    r=db.execute('select segment,ordinal,raw_sha from events where seq=?',(seq,)).fetchone()
    return {'sequence':seq,'segment':r[0],'ordinal':r[1],'raw_sha256':r[2]}
def later(d):
    next_action=next((x['sequence'] for x in ds if x['run']==d['run'] and x['sequence']>d['sequence'] and x['action']),ends[d['run']])
    for seq,data in db.execute("select seq,data from events where kind='teacher_observation' and run=? and seq>? and seq<? order by seq",(d['run'],d['sequence'],next_action)):
        yield seq,json.loads(data)['context']['snapshot']
def compact(c):return {k:c[k] for k in ('id','key','rank','suit','enhancement','seal','edition','ability','debuff','cost','sell_cost') if k in c}
def features(c):return {k:c.get(k) for k in ('rank','suit','enhancement','seal','edition')}

links=[];score=[];pack_choices=[];death=[];transactions=[];shop=[]
for d in ds:
    if not d['action']:continue
    q=event(d['sequence']);o=event(d['observation_sequence']);ad=event(d['advice_sequence']);action=d['action'];a=d['advice'];s=o['context']['snapshot']
    scope=lambda e:(e.get('collection_id'),e.get('context',{}).get('run_instance'))
    links.append({'request':d['sequence'],'run':d['run'],'same_scope':scope(q)==scope(o)==scope(ad),
        'same_observation':q.get('observation_id')==o.get('observation_id')==ad.get('observation_id'),
        'causal':o['sequence']<ad['sequence']<q['sequence'],'current_advice':a.get('status')=='current',
        'actual_matches_advice':a.get('action')==action,'callback_linked':bool(d['callback']),
        'marker_linked':bool(d['settlement'])})
    if action.get('kind')=='play':
        match=re.search(r'\(~([0-9]+)\)',a.get('title',''))
        if match:
            stable=next(((seq,x) for seq,x in later(d) if x.get('round')==s.get('round') and x.get('phase') in ('hand','round') and x.get('hands_played')==s.get('hands_played',0)+1),None)
            if stable:
                seq,x=stable;pred=int(match[1]);actual=x.get('chips',0)-s.get('chips',0)
                if abs(pred-actual)>max(2,pred*.02):
                    score.append({'run':d['run'],'request':anchor(d['sequence']),'observation':anchor(o['sequence']),
                        'effect':anchor(seq),'predicted_display_approx':pred,'observed_chip_delta':actual,
                        'uncertainty_disclosed':any(any(word in line.lower() for word in ('uncertain','random','averages','not a guarantee')) for line in arr(a.get('lines'))),
                        'title':a.get('title'),'lines':a.get('lines'),'blind':s.get('blind'),
                        'selected_cards':[compact(s['hand'][i-1]) for i in action.get('indices',[])],
                        'jokers':[compact(c) for c in arr(s.get('jokers'))]})
    if s.get('phase')=='pack' and action.get('kind') in ('choose','skip_pack','sell'):
        receipt=(a.get('copy_death_review') or {}).get('pack') or {}
        pack_choices.append({'run':d['run'],'request':d['sequence'],'action':action,'chosen':d['selected_card'].get('key'),
            'offers':[compact(c) for c in arr(s.get('pack_cards'))],'choices':s.get('pack_choices'),
            'receipt':receipt,'title':a.get('title'),'lines':a.get('lines')})
    if d['selected_card'].get('key')=='c_death' and action.get('kind') in ('use','choose'):
        targets=sorted(action.get('targets') or []);assert len(targets)==2
        recipient,source=[s['hand'][i-1] for i in targets];found=None
        for seq,x in later(d):
            changed=next((c for c in arr(x.get('playing_cards')) if c.get('id')==recipient.get('id')),None)
            if changed and features(changed)==features(source):found=seq;break
        death.append({'run':d['run'],'request':anchor(d['sequence']),'recipient':compact(recipient),'source':compact(source),
            'hand':[compact(c) for c in s['hand']],'confirmation':anchor(found) if found else None,
            'receipt':a.get('copy_death_review'),'title':a.get('title'),'lines':a.get('lines')})
    if action.get('kind') in ('buy','sell','open','choose','use'):
        transactions.append({'run':d['run'],'request':d['sequence'],'ante':s.get('ante'),'round':s.get('round'),
            'action':action,'card':d['selected_card'].get('key'),'cash_before':s.get('dollars'),
            'cash_at_marker':(d.get('after') or {}).get('dollars'),'title':a.get('title'),
            'core_sale':action.get('kind')=='sell' and d['selected_card'].get('key') in ('j_yorick','j_perkeo','j_blueprint','j_brainstorm')})
    if action.get('kind')=='leave_shop':
        shop.append({'run':d['run'],'request':d['sequence'],'ante':s.get('ante'),'round':s.get('round'),'cash':s.get('dollars'),
            'last_tarot_planet':s.get('last_tarot_planet'),'inventory':dict(Counter(c.get('key') for c in arr(s.get('consumeables')))),
            'negative_inventory':sum(bool((c.get('edition') or {}).get('negative')) for c in arr(s.get('consumeables'))),
            'yorick_x':next((c.get('ability',{}).get('x_mult') for c in arr(s.get('jokers')) if c.get('key')=='j_yorick'),None),
            'joker_row':[(c.get('key'),c.get('ability',{}).get('perish_tally'),c.get('debuff')) for c in arr(s.get('jokers'))],
            'lines':a.get('lines'),'gold_review':a.get('gold_review'),'copy_review':a.get('copy_death_review')})

pack_checks=[]
for p in read('buffoon_opportunities.json'):
    for request in p['opened_actions']:
        d=next(x for x in ds if x['sequence']==request)
        found=next(((seq,s) for seq,s in later(d) if s.get('phase')=='pack' and arr(s.get('pack_cards'))),None)
        pack_checks.append({'run':p['run'],'offer_id':p['card']['id'],'request':anchor(request),
            'reveal':anchor(found[0]) if found else None,'revealed_keys':[c.get('key') for c in arr(found[1].get('pack_cards'))] if found else []})

flags=[];flag_reason=Counter()
for f in screen['flags']:
    e=f['evidence'];a=f['recorded_advice'];yr=a.get('yorick_review') or {};growth=yr.get('growth') or {};risk=yr.get('risk') or {}
    # Classify evidence; not an optimal-action label.
    if f['rule']=='unused_discards_at_clear' and e['nominal_unskipped_blinds_including_current']==1:category='final_boss_no_later_growth'
    elif growth.get('reasons'):category='explicit_conservative_guard'
    elif f['rule']=='short_discard' and risk.get('compared') and not risk.get('qualified_five_count'):category='compared_five_but_none_qualified'
    elif not e.get('active_growth_jokers'):category='no_watched_growth_joker'
    elif yr:category='comparison_receipt_without_complete_rejection_utility'
    else:category='no_growth_receipt_for_this_decision'
    flag_reason[(f['rule'],category)]+=1
    flags.append({'id':f['id'],'rule':f['rule'],'run':f['run']['run_number'],'request':f['anchors']['request']['sequence'],
        'evidence_category':category,'reason':growth.get('reasons'),'risk':risk,'growth':growth,
        'status':'insufficient_evidence' if category not in ('final_boss_no_later_growth','no_watched_growth_joker') else 'contextual_not_automatic_error'})

timings=read('timings.json')
caps={phase:sum(t.get('phase')==phase and t.get('evaluations',0)>=cap for t in timings) for phase,cap in [('hand',140000),('shop',50000),('pack',50000)]}
receipt_counts=Counter();fishing=Counter();pack_reasons=Counter()
for d in ds:
    a=d['advice'];c=a.get('copy_death_review') or {}
    for k in ('acquisition','choice','focused_replacements','focused_direct','death','fishing','pack'):
        if k in c:receipt_counts[k]+=1
    if c.get('fishing'):fishing[c['fishing'].get('reason','unknown')]+=1
    for line in a.get('lines',[]):
        if 'could not complete' in line or 'outside' in line or 'unsupported' in line:pack_reasons[line]+=1
watch=read('copy_opportunities.json')
watch_counts={key:{'offered':sum(x['card']['key']==key for x in watch),'acquired':sum(x['card']['key']==key and x['first_owned_sequence'] is not None for x in watch)} for key in ('j_blueprint','j_brainstorm','j_invisible')}
summary={'link_checks':len(links),'link_failures':[x for x in links if not all(x[k] for k in ('same_scope','same_observation','causal','current_advice','actual_matches_advice','callback_linked','marker_linked'))],
    'watch_offers':watch_counts,'buffoon_reveals':len(pack_checks),'buffoon_reveals_confirmed':sum(bool(x['reveal']) for x in pack_checks),
    'death_uses':len(death),'death_confirmed':sum(bool(x['confirmation']) for x in death),'display_score_divergences':len(score),
    'undisclosed_divergences':sum(not x['uncertainty_disclosed'] for x in score),'exact_cap_decisions':caps,
    'copy_receipt_counts':dict(receipt_counts),'death_fishing_reasons':dict(fishing),
    'flag_categories':[{'rule':k[0],'category':k[1],'count':v} for k,v in flag_reason.items()],
    'coverage_or_support_notes':dict(pack_reasons)}
for name,data in {'links':links,'score_divergences':score,'pack_choices':pack_choices,'death':death,'transactions':transactions,
    'shop_exits':shop,'pack_reveal_checks':pack_checks,'flag_adjudication':flags,'summary':summary}.items():
    (OUT/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='coverage_or_support_notes'}))
