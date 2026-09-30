"""Read-only compact audit and public-field projections; no policy execution."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT/'tools/advisor_eval'))
from read_player_log import records
def sha(raw): return hashlib.sha256(raw).hexdigest()
def save(name,value):
    p=OUT/name
    with p.open('x',encoding='utf-8',newline='\n') as f: json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
    return {'path':str(p),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
audit_path=OUT/'passive_audit.json';audit=json.loads(audit_path.read_text(encoding='utf-8'))
events=audit['events'];latest_win=max((e for e in events if (e.get('details') or {}).get('outcome')=='win'),key=lambda e:e['anchor']['sequence'])
seed=latest_win['seed'];run=[e for e in events if e['seed']==seed]
actions=[e for e in run if e['kind']=='action_requested']
def act(e): return (e.get('details') or {}).get('input',{}).get('action',{})
late=[e for e in actions if e['state'].get('phase')=='shop' and e['state'].get('ante')==8]
last_shop=max(late,key=lambda e:e['anchor']['sequence'])
def field_card(c):
    fields=('id','key','name','base','base_cost','edition','cost','sell_cost','debuff','pinned','face_down','seal')
    out={key:c.get(key) for key in fields}
    out['ability_keys']=sorted(c.get('ability',{}));out['ability']=c.get('ability')
    out['tarot_hold_source']=c.get('tarot_hold_source')
    out['public_fields_present']=sorted(c)
    return out
field_ref=save('public_failure_fields.json',{'schema':1,'anchor':last_shop['anchor'],'loaded_version':last_shop['version'],
  'inventory_count':len(last_shop['consumeables']),'consumable_limit':last_shop['state']['consumable_limit'],
  'consumeable_buffer':last_shop['state']['consumeable_buffer'],'cards':[field_card(c) for c in last_shop['consumeables']],
  'qualification':'These are exact public snapshot card fields. Normalized pinned/debuff/face_down are not raw Card constructor observations. Failed certificates do not log raw params, registry identity, raw front, seal-presence or settled presentation fields; absent public keys must not be imputed.'})

# Census only the exact byte prefixes already hashed by audit.py; no new tail.
classes=collections.Counter();ids={};examples=[];decoded=0
for inp in audit['inputs']:
    with Path(inp['path']).open('rb') as f: data=f.read(inp['bytes'])
    assert sha(data)==inp['input_sha256'],'Previously audited byte prefix changed'
    for ordinal,(raw,frame) in enumerate(records(io.BytesIO(data)),1):
        e=json.loads(raw);decoded+=1;s=e.get('context',{}).get('snapshot',{})
        for area in ('consumeables','shop_jokers','pack_cards'):
            for card in s.get(area,[]):
                cert=card.get('tarot_hold_source')
                if not isinstance(cert,dict): continue
                key=(card.get('key'),cert.get('supported'),cert.get('reason'))
                classes[key]+=1
                ids.setdefault(key,set()).add(str(card.get('id')))
                if cert.get('supported') is True and len(examples)<8:
                    examples.append({'sequence':e.get('sequence'),'area':area,'segment':Path(inp['path']).name,
                      'ordinal':ordinal,'decoded_event_sha256':sha(raw),'stored_frame_sha256':frame.get('frame_sha256'),'card':card})
census_ref=save('certificate_census.json',{'schema':1,'decoded_events':decoded,
  'scope':'Every consumeables/shop_jokers/pack_cards public card observation in the exact already-audited byte prefixes; repeated observations are not independent samples.',
  'classes':[{'key':key,'supported':supported,'reason':reason,'observation_count':count,'distinct_public_ids':len(ids[(key,supported,reason)])} for (key,supported,reason),count in sorted(classes.items(),key=lambda p:str(p[0]))],
  'supported_observation_count':sum(n for (_,supported,_),n in classes.items() if supported is True),'supported_examples':examples,
  'inputs':audit['inputs']})
def compact_shop(e):
    s=e['state'];a=e.get('advice') or {};inventory=collections.Counter((c['key'],bool((c.get('edition') or {}).get('negative'))) for c in e['consumeables'])
    return {'anchor':e['anchor'],'action':act(e),'cash':s['dollars'],'next_blind':s['next_blind'],
      'inventory_count':len(e['consumeables']),'consumable_limit':s['consumable_limit'],'consumeable_buffer':s['consumeable_buffer'],
      'inventory_classes':[{'key':key,'negative':negative,'count':n} for (key,negative),n in inventory.items()],
      'offers':[{k:c.get(k) for k in ('id','key','name','cost','edition','ability','gold_status')} for c in e['shop_jokers']],
      'gold_review':a.get('gold_review'),'advice_title':a.get('title'),'timing':a.get('timing')}
terminals=[{'anchor':e['anchor'],'loaded_version':e['version'],'seed':e['seed'],'state':e['state'],'details':e['details'],
  'counts':e['goal'].get('counts'),'row':[{k:c.get(k) for k in ('id','key','name','gold_status','edition')} for c in e['jokers']]} for e in events if (e.get('details') or {}).get('event')=='run_finished']
exits=[e for e in actions if act(e).get('kind')=='leave_shop']
source_files={}
for name in ('tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua',
             'tools/advisor_eval/runs/chicot_order_source1/source/card.lua',
             'tools/advisor_eval/runs/gold345_installed/policy/Brainstorm/Advisor/gold_tarot_hold.lua',
             'tools/advisor_eval/runs/gold345_installed/policy/Brainstorm/Advisor/snapshot.lua'):
    p=ROOT/name;source_files[name]=sha(p.read_bytes())
summary={'schema':1,'scope':'New read-only passive public log analysis only. All345 allowances remain closed. No advisor policy, source component, search, attempt, save/profile access, executable or game-control call.',
  'audit':{'path':str(audit_path),'sha256':sha(audit_path.read_bytes())},'inputs':audit['inputs'],'hash_semantics':audit['hash_semantics'],
  'loaded_versions':audit['loaded_versions'],'last_sequence':audit['last_sequence'],'decode_errors':audit['decode_errors'],
  'latest_verified_win':{'sequence':latest_win['anchor']['sequence'],'seed':seed,'loaded_version':latest_win['version'],
    'score':latest_win['state']['chips'],'target':latest_win['state']['blind']['chips'],'boss':latest_win['state']['blind']['key'],
    'cash':latest_win['state']['dollars'],'gold_award':latest_win['details']['gold_award'],'counts':latest_win['goal']['counts'],
    'actions':latest_win['details']['run_actions'],'seconds':latest_win['details']['run_seconds'],
    'jokers':[{k:c.get(k) for k in ('key','name','gold_status')} for c in latest_win['jokers']]},
  'run_summary':{'shop_exit_count':len(exits),'exits_with_visible_missing_offer':sum(any(c['gold_status']=='missing' for c in e['shop_jokers']) for e in exits),
    'action_counts':dict(collections.Counter(act(e).get('kind') or '(non-advisor callback)' for e in actions)),
    'scope':'Visible missing offers are not evidence of a safe legal retained purchase. Same seed was previously development data; not an independent holdout.'},
  'late_shop_actions':[compact_shop(e) for e in late],
  'late_public_row':last_shop['jokers'],'public_failure_fields':field_ref,'certificate_census':census_ref,
  'direct_observations':['Loaded345 generated fresh failure certificates; these are not unchanged old344 certificates.',
    'All26 held Tarots at final shop2195 have supported=false and the generic copied-Tarot ability/edition/front/parameters reason.',
    'Full26/26 inventory passed the conditional Cartomancer row gate, then acquisition rejected its whole-inventory certificate before any score call.',
    'Pre-Small22/23 inventory still rejected the owned row; pre-Big24/24 accepted its row but had no visible missing Joker.',
    'No retention comparison ran at these shop exits because the ordinary action was not a sale-first Joker action.'],
  'source_derived_mismatch':{'finding':'Vanilla create_card supplies params.bypass_back=G.GAME.selected_back.pos; copy_card retains params. Installed345 params_ok accepts only four Boolean fields and rejects bypass_back.',
    'source_lines':{'common_events.lua':'2126-2130 create_card;2175-2179 copy_card','gold_tarot_hold.lua':'168-171 params_allowed/params_ok;224 capture guard'},
    'attribution_limit':'The newly logged generic failure is consistent with this exact source mismatch, but failed certificate output does not include raw params. Do not present bypass_back as directly observed or refresh captured certificates.'},
  'source_sha256':source_files,'terminals':terminals,
  'censoring':'The subsequent run is unfinished at the frozen log prefix; no outcome is imputed.',
  'limits':'No complete comparison, alternative purchase, retention improvement, terminal rescue or numerical win odds is established by this passive audit.'}
report=save('summary.json',summary)
print(json.dumps({'summary':report,'public_fields':field_ref,'certificate_census':census_ref,'supported_observations':sum(n for (_,supported,_),n in classes.items() if supported is True)}))
