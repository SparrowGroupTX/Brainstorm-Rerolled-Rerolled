"""Bounded read-only extraction from a spent source trace; never executes policy."""
from pathlib import Path
from collections import Counter
import hashlib,json,sys
from stdout_transport import open_trace,verify_trace,MAX_DECODED
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915'
def sha(p):
    with p.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def load(p):return json.loads(p.read_text())
def public_state(s):
    return {k:s.get(k) for k in ('ante','round','phase','dollars','chips','hands_left','discards_left','hands_played_total')}|{
      'blind':{k:(s.get('blind') or {}).get(k) for k in ('key','name','chips')},
      'jokers':[{'key':c.get('key'),'sell_cost':c.get('sell_cost'),'debuff':c.get('debuff'),'ability':{k:(c.get('ability') or {}).get(k) for k in ('extra','x_mult','yorick_discards','perish_tally','rental')}} if c.get('facing')!='back' and not any(c.get(k) for k in ('face_down','identity_redacted','unknown','concealed')) else {'identity_redacted':True} for c in s.get('jokers',[])],
      'consumables':[{'key':c.get('key'),'negative':bool((c.get('edition') or {}).get('negative'))} for c in s.get('consumeables',[])]}
def audit(job):
    folder=BASE/job;record=load(folder/'record.json');registration=load(folder/'registration.json');trace=(folder/record.get('trace_path','trace.log')).resolve()
    trace.relative_to(folder.resolve())
    assert record['worker_reaped'] and record['trace_sha256']==sha(trace)
    assert record['registration_sha256']==sha(folder/'registration.json')
    assert record.get('stdout_drain_completed',True) is True
    assert trace.stat().st_size<=268435456
    decoded_check=verify_trace(trace,record.get('decoded_trace_bytes',record['trace_bytes']),record.get('decoded_trace_sha256',record['trace_sha256']))
    counts=Counter();profiles=[];actions=[];terminals=[];stops=[];gaps=[];score_scopes=Counter();errors=[];last_state=None;context=None;bad_lines=[];legality_failures=[]
    decoded_total=0
    with open_trace(trace) as stream:
      for number,rawline in enumerate(iter(lambda:stream.readline(67108865),b''),1):
        decoded_total+=len(rawline)
        if len(rawline)>67108864 or decoded_total>MAX_DECODED:raise ValueError('Read-only audit line/decoded cap exceeded')
        line=rawline.decode('utf-8','strict')
        try:row=json.loads(line)
        except json.JSONDecodeError:
          bad_lines.append({'line':number,'bytes':len(line.encode()),'sha256':hashlib.sha256(line.encode()).hexdigest()});continue
        if not isinstance(row,dict):continue
        kind=row.get('type','');counts[kind]+=1
        if kind=='engine_episode_decision_started':last_state=public_state(row['snapshot'])
        elif kind=='engine_episode_profile':profiles.append({k:row.get(k) for k in ('step','phase','advisor_seconds','snapshot_seconds','score_calls','evaluations')})
        elif kind=='engine_episode_action':
          action=row.get('action') or {};entry={k:row.get(k) for k in ('step','phase','action','card_key','expected_score','score_bound','score_prediction','prediction_source')};entry['state']=last_state
          area=action.get('area');idx=action.get('index')
          actions.append(entry)
        elif kind=='engine_episode_terminal':terminals.append(row)
        elif kind=='engine_episode_terminal_context':context=public_state(row.get('snapshot') or {})
        elif kind=='engine_episode_stopped':stops.append(row)
        elif kind=='engine_information_scope_gap':gaps.append(row)
        elif kind=='engine_episode_resolved':
          if actions and actions[-1]['step']==row.get('step'):
            actions[-1]['resolved']={k:row.get(k) for k in ('state','chips_delta','dollars_delta','hands_left','discards_left','engine_seconds','engine_ticks')}
        elif kind in ('engine_episode_score_verified','engine_episode_score_unverified'):
          score_scopes[row.get('scope')]+=1
          if actions and actions[-1]['step']==row.get('step'):
            actions[-1]['score_check']={k:row.get(k) for k in ('type','scope','predicted','actual','prediction_source','reason')}
        elif kind in ('engine_episode_score_mismatch','engine_episode_illegal_action'):
          errors.append({'line':number,'type':kind,'step':row.get('step',(row.get('decision') or {}).get('step')),'scope':row.get('scope'),'check':row.get('check')})
        elif kind=='engine_probe_blocked':errors.append({'line':number,'type':kind,'reason':str(row.get('reason',''))[:3000]})
        elif kind.endswith('error'):errors.append({'line':number,'type':kind,'message':str(row.get('error',row.get('message','')))[:1000]})
    outcome=record['status'] if record['status']!='complete' else 'unsupported'
    terminal_consistency=None
    if terminals:
      assert len(terminals)==1
      t=terminals[0];p=t.get('normal_progress') or {};fc=p.get('final_context') or {}
      if t['outcome']=='loss':terminal_consistency=t.get('game_over') is True;outcome='loss' if terminal_consistency else 'error'
      elif t['outcome']=='win':
        context_final=fc.get('boss') is True and fc.get('ante')==fc.get('win_ante') and isinstance(fc.get('ante'),(int,float))
        threshold=isinstance(fc.get('chips'),(int,float)) and isinstance(fc.get('target'),(int,float)) and fc['target']>0 and fc['chips']>=fc['target']
        terminal_consistency=(t.get('game_over') is False and t.get('source_profile_completed') is True and p.get('final_boss') is True and context_final and p.get('source_won') is True and p.get('deck_progress') is True and p.get('joker_progress') is True and ((p.get('threshold_met') is True and threshold) or p.get('source_saved') is True))
        outcome='win' if terminal_consistency else 'error'
      else:terminal_consistency=False;outcome='error'
      if record['status']!='complete':outcome=record['status']
    elif stops:outcome=stops[-1]['outcome'] if record['status']=='complete' else record['status']
    if errors or not record['frozen_files_unchanged'] or not record['external_files_unchanged']:outcome='error'
    out={'kind':'spent_complete_attempt_readonly_audit','job':job,'outcome':outcome,'seed':registration['metadata']['seed'],
      'role':registration['metadata'].get('pair_role'),'policy_digest':registration['metadata']['policy_digest'],
      'record_sha256':sha(folder/'record.json'),'registration_sha256':sha(folder/'registration.json'),'trace_sha256':sha(trace),'decoded_verification':decoded_check,'audit_implementation_sha256':sha(Path(__file__).resolve()),
      'worker_seconds':record['elapsed_seconds'],'reserved_seconds':record['timeout_seconds'],'counts':dict(counts),
      'terminal':terminals[0] if terminals else None,'terminal_context':context,'terminal_consistency':terminal_consistency,'stops':stops,'information_gaps':gaps,
      'last_started_state':last_state,'decisions':len(profiles),'resolved_actions':counts['engine_episode_resolved'],
      'score_scopes':dict(score_scopes),'errors':errors,'unparsed_lines':bad_lines,'profiles':profiles,'actions':actions,
      'qualification':False,'population_inference':False,'synthetic_profile':'all_unlocked_discovered_v1',
      'synthetic_objective':'synthetic_fresh_all_missing_v1','observed_player_gold_complete':58,
      'limits':['Selected dependent seed; not an unseen holdout or player win-rate cohort.','Synthetic150-missing objective differs from observed player92-missing objective.','Concealed Joker decisions stop unsupported for both policies.','Worker timing excludes live animation and user action cost.','Resolved action legality is based on inherited source callback checks and absence of rejection; not independent whole-adapter qualification.','Exact scores/supported floors/random gaps and terminal consistency are recorded separately; whole adapter unqualified.']}
    target=folder/'audit.json'
    with target.open('x',encoding='utf-8') as stream:json.dump(out,stream,indent=2);stream.write('\n')
    print(json.dumps({k:out[k] for k in ('job','outcome','seed','worker_seconds','decisions','resolved_actions','terminal_context','score_scopes','errors','stops')}))
    return out
if __name__=='__main__':audit(sys.argv[1])
