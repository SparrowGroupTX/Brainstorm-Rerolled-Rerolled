"""Compact projections of the preserved passive audit; no advisor execution."""
import collections
import hashlib
import json
from pathlib import Path

OUT=Path(__file__).parent
ROOT=Path(__file__).resolve().parents[4]
source=OUT/'passive_audit.json'
r=json.loads(source.read_text(encoding='utf-8'))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def action(e): return (e.get('details') or {}).get('input',{}).get('action',{})
def card(c):
    return {k:c[k] for k in ('id','key','name','cost','sell_cost','edition','gold_status','ability','tarot_hold_source') if k in c}
def inventory(e):
    cs=e['consumeables'];s=e['state'];classes=collections.Counter((c['key'],json.dumps(c.get('edition'),sort_keys=True),json.dumps(c.get('tarot_hold_source'),sort_keys=True)) for c in cs)
    return {'count':len(cs),'limit':s['consumable_limit'],'buffer':s['consumeable_buffer'],
      'negative_count':sum((c.get('edition') or {}).get('negative',False) for c in cs),
      'ordinary_count':sum(not c.get('edition') for c in cs),
      'classes':[{'key':key,'edition':json.loads(ed),'certificate':json.loads(cert),'count':count} for (key,ed,cert),count in classes.items()]}
def shop(e):
    a=e.get('advice') or {}
    return {'anchor':e['anchor'],'seed':e['seed'],'at':e['at'],'monotonic_seconds':e['monotonic_seconds'],'state':e['state'],
      'requested_action':action(e),'offers':[card(c) for c in e['shop_jokers']],
      'held_target_count':e['goal'].get('held_target_count'),'inventory':inventory(e),
      'gold_review':a.get('gold_review'),'timing':a.get('timing'),'advice_title':a.get('title')}

target=[e for e in r['events'] if e['seed']=='YVYN2Z11']
actions=[e for e in target if e['kind']=='action_requested']
exits=[e for e in actions if action(e).get('kind')=='leave_shop']
late=[e for e in actions if e['state'].get('phase')=='shop' and e['state'].get('ante')==8]
terminals=[]
for e in r['events']:
    d=e.get('details') or {}
    if d.get('event')=='run_finished':
        terminals.append({'anchor':e['anchor'],'seed':e['seed'],'version':e['version'],'state':e['state'],
          'details':d,'counts':e['goal'].get('counts'),'held_jokers':[card(c) for c in e['jokers']]})
source_files={}
for rel in ('Advisor/gold_goal.lua','Advisor/gold_acquisition.lua','Advisor/gold_tarot_hold.lua','Advisor/gold_perkeo.lua','Advisor/shop_scoring.lua'):
    p=ROOT/'tools/advisor_eval/runs/gold344_installed/policy/Brainstorm'/rel
    if p.exists(): source_files[rel]={'path':str(p),'sha256':digest(p)}
summary={'schema':1,'scope':'Read-only analysis of existing public passive journal. No captured-state execution, policy replay, original-source experiment, search, simulation or live control.',
  'audit':{'path':str(source),'sha256':digest(source)},'inputs':r['inputs'],'decode_errors':r['decode_errors'],
  'hash_semantics':r['hash_semantics'],'loaded_versions':r['loaded_versions'],'last_sequence':r['last_sequence'],
  'reported_win':{'seed':'YVYN2Z11','terminal_sequence':2240,'terminal_verified':True,'boss':'Verdant Leaf','score':686952,'threshold':400000,'cash':98,
    'new_gold_count':0,'progress_before':59,'progress_after':59,'run_actions':232,'run_seconds':305.7940514,
    'action_kind_counts':dict(collections.Counter(action(e).get('kind') or '(not an advisor action)' for e in actions)),
    'shop_exit_count':len(exits),'shop_exits_with_visible_missing_offer':sum(any(c['gold_status']=='missing' for c in e['shop_jokers']) for e in exits),
    'qualification':'Visible offers are not proof of affordable legal safe acquisition or retention; no counterfactual was replayed.'},
  'late_shop_actions':[shop(e) for e in late],
  'shop_exits':[{'anchor':e['anchor'],'ante':e['state']['ante'],'cash':e['state']['dollars'],
    'next_blind':e['state']['next_blind'],'held_target_count':e['goal'].get('held_target_count'),
    'missing_offers':[card(c) for c in e['shop_jokers'] if c['gold_status']=='missing']} for e in exits],
  'late_owned_row':next(e['jokers'] for e in actions if e['anchor']['sequence']==2086),
  'logged_blocking_gates':[
    {'sequences':[e['anchor']['sequence'] for e in late if e['state']['next_blind']['key'] in ('bl_small','bl_big')],
     'reason':'Each owned Joker needs a unique visible supported identity and known progress.','acquisition_comparisons':0,'acquisition_score_calls':0,
     'static_explanation':'The visible row includes j_cartomancer. Installed344 gold_goal.stable_card excludes that key and gold_perkeo.accepts_card accepts only j_perkeo. This is the first rejected owned-row identity in the recorded order. No raw game identity or hidden field was inspected.'},
    {'sequences':[e['anchor']['sequence'] for e in late if e['state']['next_blind']['key']=='bl_final_leaf'],
     'reason':'A settled nonempty inventory of at most eight cards is required.','final_comparisons':0,'final_score_calls':0,
     'static_explanation':'The existing final-shop path projects the nonempty Perkeo inventory through perkeo_inventory, which admits at most eight cards. Recorded inventory is 25–26 cards.'}],
  'additional_supported_scope_gaps':[
    'Every recorded late held Tarot is outside the installed344 Magician/Hermit constructor family (Temperance, Sun, Moon, Wheel of Fortune, Hanged Man).',
    'Installed344 gold_tarot_hold row_names also excludes Cartomancer and Caino; broadening stable_card alone would not complete this comparison.',
    'Pre-Small inventory has one free consumable slot, so a zero-generation Cartomancer proof is not applicable there. Pre-Big and final shop-exit inventories are full.',
    'Ordinary shop diagnostics also record Blind-start Joker changes are left to the existing strategy. All three late exits spent zero score calls.',
    'The actual final-blind sale removed Negative Perkeo and reduced Joker capacity from six to five with row size six to five. It did not create a free Joker slot.'],
  'terminals':terminals,'other_outcomes':'At the captured byte prefix, runs one and three are verified losses and run four has started but is right-censored. These are user-driven passive observations, not a registered experimental cohort.',
  'installed344_source_references':source_files,
  'boundaries':'Raw card.pinned absence is not visible in these normalized snapshots; any nil-versus-false constructor issue requires separate source/fixture evidence. This audit does not attribute the reported win to that issue or establish that purchasing either visible target would have won.'}
path=OUT/'summary.json'
with path.open('x',encoding='utf-8') as f: json.dump(summary,f,indent=2);f.write('\n')
print(json.dumps({'path':str(path),'bytes':path.stat().st_size,'sha256':digest(path),'late_shop_actions':len(late),'source_reference_count':len(source_files)}))
