"""Read-only exact C05/C08 actions and pack guard receipt arithmetic; no evaluation."""
from pathlib import Path
import hashlib
import json
import copy
import math

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
HERE = Path(__file__).resolve().parent


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(job):
    record = json.loads((BASE/job/'record.json').read_text())
    assert record['trace_sha256'] == sha(BASE/job/'trace.log')
    starts = {}; actions = {}; profiles = {}; resolved = set()
    with (BASE/job/'trace.log').open('rb') as stream:
        for line in stream:
            if not line.startswith(b'{'):
                continue
            row = json.loads(line)
            kind = row['type']; step = row.get('step')
            if kind == 'engine_episode_decision_started': starts[step] = row['snapshot']
            elif kind == 'engine_episode_action': actions[step] = row['action']
            elif kind == 'engine_episode_profile': profiles[step] = row['score_calls']
            elif kind == 'engine_episode_resolved': resolved.add(step)
    return record, starts, actions, profiles, resolved


def population(cards):
    out = {}
    for card in cards:
        ability = copy.deepcopy(card.get('ability', {})); base = copy.deepcopy(card.get('base', {}))
        ability.pop('played_this_ante', None); ability.pop('discarded', None); base.pop('times_played', None)
        ability.setdefault('perma_bonus', 0)
        row = {key: copy.deepcopy(card[key]) for key in ('key','rank','suit','nominal','enhancement','seal','edition','vampired') if key in card}
        row.update(ability=ability, base=base)
        out['string:'+card['id']] = row
    return out


def leaders(hands):
    visible = {k:v['played'] for k,v in hands.items() if v.get('visible') is not False}
    best = max(visible.values())
    return '|'.join(sorted(k for k,v in visible.items() if v == best))


def finish(world):
    r = world['endpoint_resources']; f = world['finish_details']; mods = r.get('modifiers', {})
    held = r['dollars'] + f['held_dollars']
    interest = (r['interest_amount'] * min(math.floor(held/5), r['interest_cap']/5)
                if not mods.get('no_interest') and held >= 5 else 0)
    return {'cash': held+interest+f['hand_dollars']+f['discard_dollars'],
            'blue':f['blue_planets'], 'planet':f['planet_key'], 'hand':f['planet_hand'],
            'slots_before':f['slots_before_blue'], 'slots_after':f['slots_after_blue']}


def main():
    data = {job: read(job) for job in ('C05', 'C08')}
    old, new = data['C05'], data['C08']
    shared = sorted(old[4] & new[4]); same_inputs = []; changed_inputs = []; changed_actions = []
    for step in shared:
        if old[1][step] == new[1][step]: same_inputs.append(step)
        else: changed_inputs.append({'step':step, 'fields':[k for k in sorted(set(old[1][step])|set(new[1][step])) if old[1][step].get(k)!=new[1][step].get(k)]})
        if old[2][step] != new[2][step]: changed_actions.append({'step':step,'C05':old[2][step],'C08':new[2][step],'same_complete_public_input':old[1][step]==new[1][step]})
    audit_path = BASE/'C08/audit_verified.json'
    audit = json.loads(audit_path.read_text())
    assert audit['audit_issues'] == [] and audit['disposition'] == 'loss'
    pack = next(p for p in audit['pack_choices_and_receipts'] if p['step']==12)
    d = pack['pack_diagnostics']; root = new[1][12]
    root_population = population(root['playing_cards']); root_jokers = {j['id']:j for j in root['jokers']}
    offers = {c['index']: c for c in d['comparisons']}
    incumbent = offers[d['survival_priority']['incumbent_index']]['evidence']['after_finishing']['selected']
    summaries = []
    for c in d['comparisons']:
        f = c['evidence']['after_finishing']
        summaries.append({'index':c['index'], 'selected':f['selected']['name'], 'complete':f['complete'],
                          'policies':[{'name':p['name'],'clearing_samples':p['clearing_samples'],
                                       'scores':[w['score'] for w in p['worlds']],
                                       'discarded_cards':[[len(a['indices']) for a in w['actions'] if a['kind']=='discard'] for w in p['worlds']]}
                                      for p in f['policies']]})
    comparisons = []
    for c in d['comparisons']:
        for p in c['evidence']['after_finishing']['policies']:
            if p['clearing_samples'] != 4: continue
            for aw,bw in zip(p['worlds'], incumbent['worlds']):
                ar = aw['endpoint_resources']
                br = bw['endpoint_resources'] if bw['clear'] else {'population':root_population,'inventory':root['consumeables'],'hands':root['hands'],'jokers':root['jokers']}
                failures = []; checks = {}
                def check(name, ok, details=None):
                    checks[name] = bool(ok)
                    if not ok: failures.append({'guard':name,'details':details})
                check('owned_population_identity', all(ar['population'].get(k)==v and (k not in br['population'] or ar['population'][k]==br['population'][k]) for k,v in root_population.items()))
                check('whole_inventory', ar['inventory']==root['consumeables']==br['inventory'])
                for name,h in root['hands'].items():
                    a,b = ar['hands'][name],br['hands'][name]
                    check('hand_levels:'+name, all(a[k]>=h[k] and a[k]>=b[k] for k in ('level','chips','mult')))
                    check('played_hand_identity:'+name, not (b['played']>0 and a['played']==0), {'candidate_played':a['played'],'protected_played':b['played']})
                aj,bj = ({j['id']:j for j in r['jokers']} for r in (ar,br))
                growth = []
                for identity,j in root_jokers.items():
                    x,y,z = aj[identity]['ability'],bj[identity]['ability'],j['ability']
                    if j['key']=='j_yorick':
                        delta=(x['x_mult']-y['x_mult'])/z['extra']['xmult']*z['extra']['discards']+y['yorick_discards']-x['yorick_discards']
                        owned=(x['x_mult']-z['x_mult'])/z['extra']['xmult']*z['extra']['discards']+z['yorick_discards']-x['yorick_discards']
                        check('yorick_protected_growth',delta>=0,{'card_equivalent_delta':delta,'candidate_x':x['x_mult'],'candidate_countdown':x['yorick_discards'],'protected_x':y['x_mult'],'protected_countdown':y['yorick_discards']})
                        check('yorick_root_growth',owned>=0,{'card_equivalent_delta':owned})
                        growth.append({'root_countdown':z['yorick_discards'],'candidate_countdown':x['yorick_discards'],'protected_countdown':y['yorick_discards'],'card_equivalent_delta':delta})
                        keep=lambda a:{k:v for k,v in a.items() if k not in ('x_mult','yorick_discards')}
                        check('yorick_other_ability',keep(x)==keep(y)==keep(z))
                    else: check('owned_joker_ability:'+j['key'],x==y==z)
                for key in ('hands_used','discards_used','action_count','population_loss'):
                    check(key,aw[key]<=bw[key],{'candidate':aw[key],'incumbent':bw[key]})
                check('progress',aw['progress']>=bw['progress'])
                protected_cash=bw['dollars_after'] if bw['clear'] else root['dollars']
                check('dollars_after',aw['dollars_after']>=protected_cash,{'candidate':aw['dollars_after'],'protected':protected_cash})
                check('borrowing_limit',aw['dollars_after']>=ar['bankrupt_at'])
                reward=None
                if bw['clear']:
                    af,bf=finish(aw),finish(bw); reward={'candidate':af,'incumbent':bf}
                    for key in ('cash','blue','slots_before','slots_after'):
                        check('finish_'+key,af[key]>=bf[key],{'candidate':af[key],'incumbent':bf[key]})
                    check('finish_blue_identity',bf['blue']==0 or (af['hand']==bf['hand'] and af['planet']==bf['planet']))
                    check('played_hand_leaders',leaders(ar['hands'])==leaders(br['hands']),{'candidate':leaders(ar['hands']),'incumbent':leaders(br['hands'])})
                comparisons.append({'offer':c['index'],'policy':p['name'],'world':aw['composition_world_id'],'incumbent_policy':incumbent['name'],
                                    'incumbent_clear':bw['clear'],'candidate_score':aw['score'],'incumbent_score':bw['score'],
                                    'failed_guards':failures,'checked_predicates':checks,'yorick':growth,'finish':reward})
    result={'scope':'Read-only exact public-input/action comparison and scalar resource-guard explanation from already recorded pack forecasts. No Lua/source/policy evaluation, action dispatch, rescoring or world generation.',
            'records':{job:rec[0] for job,rec in data.items()},'selected_audit_sha256':sha(audit_path),
            'source_guard_file':'C08/policy/Brainstorm/Advisor/pack_survival.lua',
            'source_guard_sha256':sha(BASE/'C08/policy/Brainstorm/Advisor/pack_survival.lua'),
            'same_complete_public_inputs':same_inputs,'changed_inputs':changed_inputs,'changed_actions':changed_actions,
            'score_call_differences':[{'step':s,'C05':old[3][s],'C08':new[3][s]} for s in shared if old[3][s]!=new[3][s]],
            'pack_step':12,'actual_selected':pack['selected_card'],'declared_family':offers[1]['evidence']['common_worlds']['continuation_family'],
            'recorded_policy_summaries':summaries,'recorded_all_clearing_resource_guards':comparisons,
            'limits':['The four composition worlds are selected mechanical forecast samples, not all Certificate generation outcomes or a blind-win probability.',
                      'No alternative Card Sharp source continuation was executed. The source attempt actually retained Certificate and lost.',
                      'Comparison of full public snapshots does not establish hidden RNG/save equivalence. Both attempts are selected dependent synthetic development data.']}
    output=HERE/'development_analysis.json'
    with output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    pointer={'filename':audit_path.name,'sha256':sha(audit_path),
             'supersedes':[{'filename':'audit.json','sha256':sha(BASE/'C08/audit.json'),'reason':'Inherited C07-only duplicated reviewed-feature metadata requirement incorrectly flagged registered C08 metadata.'},
                           {'filename':'audit_final.json','sha256':sha(BASE/'C08/audit_final.json'),'reason':'Checks were corrected but descriptive helper hash map still named the preceding helper. Selected audit binds actual imported mechanics_final.py.'}],
             'reason':'Selected corrected read-only audit verifies exact registered required feature file, frozen C07 reviewed feature map, frozen policy and actual imported helper hash. Earlier evidence is preserved.',
             'source_attempts_added':0,'policy_evaluations_added':0}
    with (BASE/'C08/selected_audit.json').open('x',encoding='utf-8') as stream:json.dump(pointer,stream,indent=2);stream.write('\n')
    print(json.dumps({'analysis_sha256':sha(output),'pointer_sha256':sha(BASE/'C08/selected_audit.json'),'same_inputs':len(same_inputs),'changed_actions':changed_actions,
                      'score_call_differences':result['score_call_differences'],'all_clearing_failures':[{'world':c['world'],'policy':c['policy'],'failures':c['failed_guards']} for c in comparisons]},indent=2))


if __name__=='__main__':main()
