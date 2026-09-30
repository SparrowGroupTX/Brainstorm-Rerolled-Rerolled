"""Read-only paired outcomes/public-prefix audit. Never imports policy/source code."""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import json
from stdout_transport import open_trace,verify_trace,MAX_DECODED

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915'
EXCLUDED={'state_fingerprint','before_fingerprint','after_fingerprint','fingerprint','observation_key','identity',
          'pseudorandom','rng','_shop_scoring','_retry','_retry_context','retry_context'}
TOP=set('active_tags ante bankrupt_at blind blind_choices blind_on_deck blind_states chips completionist_goal consumable_limit consumeable_buffer consumeable_usage consumeable_usage_total consumeables current_round deck deck_key discards_left discards_used dollars hand hand_limit hand_size hands hands_left hands_played hands_played_total interest_amount interest_cap joker_limit jokers modifiers next_blind next_blind_chips normal_opening opening_pack pack_cards pack_kind pack_type pack_choices phase playing_cards probabilities rental_rate reroll_cost round round_bonus round_resets route_blinds route_tags shop_booster shop_jokers shop_vouchers shop_forecast skip_tags skips stake starting_deck_size state unused_discards used_vouchers win_ante certificate_pool last_tarot_planet first_used_hand_level filter_info challenge'.split())
CARD_AREAS=('hand','deck','playing_cards','jokers','consumeables','shop_jokers','shop_vouchers','shop_booster','pack_cards')

def sha(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def load(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def digest(value):return hashlib.sha256(canonical(value)).hexdigest()
def pick(value,keys):return {key:value[key] for key in keys if key in value}
def sanitize(value):
    if isinstance(value,dict):return {key:sanitize(item) for key,item in value.items() if key not in EXCLUDED}
    if isinstance(value,list):return [sanitize(item) for item in value]
    return value
def hidden(card):
    return card.get('facing')=='back' or any(card.get(key) for key in ('face_down','identity_redacted','unknown','concealed'))
def public_snapshot(snapshot):
    """Canonical public fields, never parsing raw identity/fingerprint strings.

    Ordinary undealt backs are known deck composition; actual concealed hand
    cards/Wheel cards are removed from every overlapping population view.
    """
    concealed_ids={c.get('id') for area in CARD_AREAS for c in snapshot.get(area,[])
                   if ((area not in ('deck','playing_cards') and hidden(c)) or
                       c.get('identity_redacted') or c.get('unknown') or c.get('concealed') or
                       (c.get('ability') or {}).get('wheel_flipped')) and c.get('id') is not None}
    out={key:sanitize(value) for key,value in snapshot.items() if key in TOP and key not in CARD_AREAS}
    concealed=0
    for area in CARD_AREAS:
        if area not in snapshot:continue
        cards=[]
        for card in snapshot[area]:
            blocked=card.get('id') in concealed_ids or card.get('identity_redacted') or card.get('unknown') or card.get('concealed') or (card.get('ability') or {}).get('wheel_flipped')
            if area not in ('deck','playing_cards') and hidden(card):blocked=True
            if blocked:cards.append({'identity_redacted':True});concealed+=1
            else:cards.append(sanitize(card))
        # Remaining deck/population is a multiset, never a hidden draw order.
        if area in ('deck','playing_cards'):cards.sort(key=lambda card:canonical(card))
        out[area]=cards
    unknown=sorted(set(snapshot)-TOP-EXCLUDED)
    return out,{'concealed_card_entries':concealed,'unclassified_top_fields':unknown,
                'scope':'Equality of declared public snapshot projection; not hidden RNG/save equivalence.'}


def compact(snapshot):
    value=pick(snapshot,['ante','round','phase','dollars','chips','hands_left','discards_left','hands_played_total'])
    value['blind']=pick(snapshot.get('blind') or {},['key','name','chips'])
    value['hand']=[pick(card,['rank','suit','enhancement','seal','debuff','identity_redacted']) for card in snapshot.get('hand',[])]
    value['jokers']=[pick(card,['key','id','sell_cost','identity_redacted'])|{'growth':pick(card.get('ability') or {},['x_mult','yorick_discards','perish_tally','rental'])} for card in snapshot.get('jokers',[])]
    value['consumables']=[pick(card,['key','identity_redacted'])|{'negative':bool((card.get('edition') or {}).get('negative'))} for card in snapshot.get('consumeables',[])]
    return value


def trace_index(folder,record):
    trace=(folder/record.get('trace_path','trace.log')).resolve();trace.relative_to(folder.resolve())
    if record.get('worker_reaped') is not True or record.get('stdout_drain_completed',True) is not True:raise ValueError('Unconfirmed process/writer termination')
    if sha(trace)!=record['trace_sha256']:raise ValueError('Stored trace hash differs')
    verified=verify_trace(trace,record.get('decoded_trace_bytes',record['trace_bytes']),record.get('decoded_trace_sha256',record['trace_sha256']))
    steps={};blocks=[];terminals=[];unparsed=[];line_total=0
    with open_trace(trace) as stream:
        for number,raw in enumerate(iter(lambda:stream.readline(64*1024**2+1),b''),1):
            line_total+=len(raw)
            if len(raw)>64*1024**2 or line_total>MAX_DECODED:raise ValueError('Trace audit line/decoded cap exceeded')
            try:row=json.loads(raw)
            except (json.JSONDecodeError,UnicodeDecodeError):
                unparsed.append({'line':number,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()});continue
            if not isinstance(row,dict):continue
            kind=row.get('type')
            if kind=='engine_episode_decision_started':
                step=row['step'];public,scope=public_snapshot(row['snapshot'])
                if step in steps:raise ValueError('Duplicate decision step')
                steps[step]={'step':step,'phase':row['phase'],'public_sha256':digest(public),'projection':scope,'state':compact(public)}
            elif kind=='engine_episode_action':
                step=row['step'];entry=steps.get(step)
                if entry is None or 'action' in entry:raise ValueError('Missing/duplicate action boundary')
                entry['action']=sanitize(row['action']);entry['action_phase']=row['phase']
                entry.update(pick(row,['card_key','prediction_source','expected_score','score_bound','score_prediction']))
            elif kind=='engine_episode_resolved':
                entry=steps.get(row['step'])
                if entry is None:raise ValueError('Resolution without a public step')
                entry['resolved']=pick(row,['state','chips_delta','dollars_delta','hands_left','discards_left'])
            elif kind in ('engine_episode_score_verified','engine_episode_score_unverified','engine_episode_score_mismatch'):
                entry=steps.get(row.get('step'))
                if entry is not None:entry['score_check']=pick(row,['type','scope','predicted','actual','prediction_source','reason'])
            elif kind in ('engine_probe_blocked','engine_information_scope_gap','engine_episode_stopped') or isinstance(kind,str) and kind.endswith('error'):
                blocks.append(sanitize({key:value for key,value in row.items() if key not in ('snapshot','result','decision')}))
            elif kind=='engine_episode_terminal':terminals.append(sanitize(row))
    return {'steps':steps,'blocks':blocks,'terminals':terminals,'unparsed_lines':unparsed,'decoded_verification':verified,
            'trace_sha256':record['trace_sha256'],'trace_path':trace.name}


def first_divergence(left,right):
    if left is None or right is None:return {'status':'not_auditable_without_full_public_trace_projection'}
    prefix=[]
    keys=sorted(set(left['steps'])|set(right['steps']))
    for step in keys:
        a=left['steps'].get(step);b=right['steps'].get(step)
        if a is None or b is None:return {'status':'one_trace_ended_before_next_shared_decision','step':step,'aligned_action_prefix':prefix}
        if a['projection']['unclassified_top_fields'] or b['projection']['unclassified_top_fields']:
            return {'status':'unclassified_public_fields','step':step,'aligned_action_prefix':prefix}
        if a['phase']!=b['phase'] or a['public_sha256']!=b['public_sha256']:
            return {'status':'public_states_diverged_before_an_action_difference','step':step,'aligned_action_prefix':prefix,
                    'baseline':pick(a,['phase','public_sha256','state']),'candidate':pick(b,['phase','public_sha256','state'])}
        if a.get('action_phase',a['phase'])!=a['phase'] or b.get('action_phase',b['phase'])!=b['phase']:
            return {'status':'action_phase_inconsistent','step':step,'aligned_action_prefix':prefix}
        if 'action' not in a or 'action' not in b:
            return {'status':'matched_public_state_missing_action','step':step,'aligned_action_prefix':prefix,
                    'baseline_action':a.get('action'),'candidate_action':b.get('action')}
        if canonical(a['action'])!=canonical(b['action']):
            return {'status':'first_exact_action_difference_after_aligned_public_prefix','step':step,
                    'aligned_action_prefix':prefix,'public_sha256':a['public_sha256'],'state':a['state'],
                    'baseline_action':a['action'],'candidate_action':b['action'],
                    'scope':'All prior compared public snapshots, phases, exact actions and resolved resource effects align. Hidden RNG/order equivalence and causal outcome improvement are not asserted.'}
        if a.get('resolved')!=b.get('resolved'):
            return {'status':'same_action_resolved_differently','step':step,'aligned_action_prefix':prefix,
                    'action':a['action'],'baseline_resolved':a.get('resolved'),'candidate_resolved':b.get('resolved')}
        if 'resolved' not in a:return {'status':'shared_action_not_resolved','step':step,'aligned_action_prefix':prefix}
        prefix.append(step)
    return {'status':'no_action_difference_in_complete_shared_prefix','aligned_action_prefix':prefix}


def inventory(state,area):
    cards=state.get(area,[]);unknown=sum(bool(card.get('identity_redacted')) for card in cards)
    counts=Counter((card.get('key'),bool(card.get('negative'))) if area=='consumables' else card.get('key') for card in cards if card.get('key'))
    return counts,unknown
def observed_changes(audit):
    observations=[(action['step'],action.get('state') or {}) for action in audit['actions']]
    if audit.get('terminal_context'):observations.append(('terminal',audit['terminal_context']))
    changes=[]
    for (previous_step,left),(step,right) in zip(observations,observations[1:]):
        for area in ('jokers','consumables'):
            before,hidden_before=inventory(left,area);after,hidden_after=inventory(right,area)
            if hidden_before or hidden_after:
                if before!=after or hidden_before!=hidden_after:changes.append({'after_action_step':previous_step,'next_observation_step':step,'area':area,'status':'concealed_identity_change_unresolved'})
                continue
            added=after-before;removed=before-after
            if added or removed:changes.append({'after_action_step':previous_step,'next_observation_step':step,'area':area,
                'added':[{'identity':list(k) if isinstance(k,tuple) else k,'count':v} for k,v in sorted(added.items(),key=lambda item:str(item[0]))],
                'removed':[{'identity':list(k) if isinstance(k,tuple) else k,'count':v} for k,v in sorted(removed.items(),key=lambda item:str(item[0]))],
                'scope':'Observed ownership delta between public snapshots, not an imputed purchase, retention guarantee or sticker.'})
    return changes


def role_report(folder,audit,trace):
    record=load(folder/'record.json');registration=load(folder/'registration.json')
    if audit['record_sha256']!=sha(folder/'record.json') or audit['registration_sha256']!=sha(folder/'registration.json'):raise ValueError('Audit provenance changed')
    if record['registration_sha256']!=sha(folder/'registration.json'):raise ValueError('Registration differs from spent record')
    plays=[]
    for action in audit['actions']:
        if (action.get('action') or {}).get('kind')=='play':
            public=action.get('state') or {};resolved=action.get('resolved') or {}
            item=pick(action,['step','action','expected_score','score_bound','score_prediction','score_check','resolved'])
            item['state']=public
            if trace and action['step'] in trace['steps']:item['prediction_source']=trace['steps'][action['step']].get('prediction_source')
            if isinstance(public.get('chips'),(int,float)) and isinstance(resolved.get('chips_delta'),(int,float)):
                item['resolved_cumulative_chips']=public['chips']+resolved['chips_delta']
                target=(public.get('blind') or {}).get('chips');item['arithmetic_threshold_met']=isinstance(target,(int,float)) and target>0 and item['resolved_cumulative_chips']>=target
            plays.append(item)
    return {'job':folder.name,'outcome':audit['outcome'],'worker_status':record['status'],
            'policy_digest':audit['policy_digest'],'worker_seconds':audit['worker_seconds'],'reserved_seconds':audit['reserved_seconds'],
            'evidence':{'audit_sha256':sha(folder/'audit.json'),'record_sha256':sha(folder/'record.json'),'registration_sha256':sha(folder/'registration.json'),'trace_sha256':record['trace_sha256']},
            'plays':plays,'observed_inventory_changes':observed_changes(audit),'last_observed_state':audit.get('terminal_context') or audit.get('last_started_state'),
            'terminal':audit.get('terminal'),'terminal_consistency':audit.get('terminal_consistency'),'stops':audit.get('stops'),
            'errors':audit.get('errors'),'information_gaps':audit.get('information_gaps'),'unparsed_lines':audit.get('unparsed_lines'),
            'raw_trace_blocks':trace['blocks'] if trace else None,'score_scopes':audit['score_scopes'],
            'trace_format':record.get('trace_format','raw'),'captured_stream_complete':record.get('stdout_capture_complete'),
            'source_profile':registration['metadata'].get('profile'),'synthetic_objective':registration['metadata'].get('gold_objective_context'),
            'synthetic_gold_missing':registration['metadata'].get('synthetic_gold_missing'),'observed_player_gold_complete':registration['metadata'].get('observed_player_gold_complete')}


def pair_report(baseline,candidate,with_traces=False):
    left=BASE/baseline;right=BASE/candidate
    a=load(left/'audit.json');b=load(right/'audit.json');ra=load(left/'registration.json');rb=load(right/'registration.json')
    ma,mb=ra['metadata'],rb['metadata']
    if a['seed']!=b['seed'] or ma.get('pair_id')!=mb.get('pair_id'):raise ValueError('Require the preregistered same-seed pair')
    if ma.get('pair_role')!='baseline' or mb.get('pair_role')!='candidate':raise ValueError('Pair roles differ')
    if ma.get('paired_job')!=candidate or mb.get('paired_job')!=baseline:raise ValueError('Preregistered paired job differs')
    ta=trace_index(left,load(left/'record.json')) if with_traces else None
    tb=trace_index(right,load(right/'record.json')) if with_traces else None
    return {'schema':1,'kind':'paired_dependent_source_readonly_audit','pair_id':ma['pair_id'],'seed':a['seed'],
      'baseline':role_report(left,a,ta),'candidate':role_report(right,b,tb),'first_divergence':first_divergence(ta,tb),
      'outcome_comparison':{'baseline':a['outcome'],'candidate':b['outcome'],'terminal_win_improvement_demonstrated':a['outcome']!='win' and b['outcome']=='win'},
      'new_source_or_policy_executions':0,'new_experiment_jobs':0,'raw_fingerprint_decoding':False,
      'qualification':False,'population_inference':False,'unseen_holdout':False,
      'limits':['Selected dependent development seeds; no representative win-rate inference or confidence interval.',
        'The synthetic profile is all_unlocked_discovered_v1 with all150 Jokers missing Gold, unlike the observed player58-complete/92-missing objective.',
        'First divergence requires aligned declared public snapshots, phases, actions and prior resolved effects; it is not hidden RNG/save equivalence.',
        'Errors, unsupported stops, timeouts and censored attempts remain their recorded outcomes. Later progress or a cleared blind is not a terminal win.',
        'Different raw/gzip transports and policy work prevent attributing worker timing differences solely to a policy or compression change.',
        'Source exact scores/supported floors/random gaps, selected action legality and terminal consistency remain separate; the whole adapter is not qualified.']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('baseline');parser.add_argument('candidate');parser.add_argument('--with-traces',action='store_true');parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();out=pair_report(args.baseline,args.candidate,args.with_traces)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('x',encoding='utf-8') as stream:json.dump(out,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps({'output':str(args.output),'sha256':sha(args.output),'outcomes':out['outcome_comparison'],'first_divergence':out['first_divergence']}))
