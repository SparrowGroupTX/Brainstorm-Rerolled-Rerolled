"""Read preserved C06 JSON metadata only; never execute policy or source."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
source=ROOT/'tools/advisor_eval/development300/c06_postmortem/recorded_decisions.json'
data=json.loads(source.read_text(encoding='utf8'))
step=next(row for row in data['completed'] if row['step']==59)
allowed=set('name set effect type blueprint_compat bonus d_size extra_value h_dollars h_mult h_size h_x_mult hands_played_at_create mult order p_dollars perma_bonus t_chips t_mult x_mult yorick_discards eternal rental perishable perish_tally perma_debuff discarded played_this_ante extra'.split())
selected=[]
for card in step['selected']:
    ability=card['ability'];base=card['base'];rank=card['rank']
    selected.append({'id':card['id'],'key':card['key'],'name':card['name'],'effect':ability['effect'],
                     'rank':rank,'nominal':card['nominal'],'base_times_played':base.get('times_played'),
                     'bonus':ability['bonus'],'perma_bonus':ability.get('perma_bonus'),
                     'rank_and_nominal_agree':base['id']==rank and base['nominal']==card['nominal']==(11 if rank==14 else min(rank,10)),
                     'unknown_ability_fields':sorted(set(ability)-allowed)})
history={}
for row in data['completed']:
    for card in row['hand']:
        for key in ('discarded','played_this_ante'):
            if key not in history and key in card['ability']:
                history[key]={'step':row['step'],'id':card['id'],'value':card['ability'][key],
                              'python_type':type(card['ability'][key]).__name__}
receipt={'schema':1,'scope':'Read-only canonical field audit, not predicate/policy evaluation',
         'input':str(source.relative_to(ROOT)),'input_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
         'snapshot_digest':step['snapshot_digest'],'step':59,'selected_cards':selected,
         'owned_jokers':[{'key':j['key'],'name':j['ability']['name'],'effect':j['ability']['effect'],
                         'extra':j['ability'].get('extra'),'x_mult':j['ability']['x_mult'],
                         'unknown_ability_fields':sorted(set(j['ability'])-allowed)} for j in step['jokers']],
         'first_recorded_hand_history_fields':history,
         'source_provenance_for_discarded':'Current scoring.after_discard sets ability.discarded=true; projection has no held discarded field.',
         'limitations':['Projection omits deck identities and full hands table at this step.',
                        'No complete guard eligibility, action, counterfactual score or outcome was evaluated.',
                        'C06 remains a timeout.'],
         'policy_executions':0,'source_executions':0}
with (HERE/'canonical_metadata_audit.json').open('x',encoding='utf8') as out: json.dump(receipt,out,indent=2)
print(json.dumps({'audit_sha256':hashlib.sha256((HERE/'canonical_metadata_audit.json').read_bytes()).hexdigest(),
                  'selected':len(selected),'selected_unknown_ability_fields':sum(len(c['unknown_ability_fields']) for c in selected),
                  'history':history},indent=2))
