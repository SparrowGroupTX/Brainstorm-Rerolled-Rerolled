"""Summarize already decoded public events; no further external file reads."""
from pathlib import Path
from collections import Counter,defaultdict
import hashlib
import json
import statistics

HERE=Path(__file__).resolve().parent
INPUT=HERE/'public_log_observations.json'
data=json.loads(INPUT.read_text());events=data['events'];byseq={e['sequence']:e for e in events}
callbacks={e['details']['action_sequence']:e for e in events if e['kind']=='action_callback_result'}
settled={e['details']['latest_action_sequence']:e for e in events if e['kind']=='state_after_actions'}
attempts=[e for e in events if e['kind']=='auto_run' and e['details'].get('event')=='action_attempt']
run_starts=[e for e in events if e['kind']=='auto_run' and e['details'].get('event')=='run_started']

def yorick(s):return [{'id':j['id'],'x_mult':j['ability'].get('x_mult'),'countdown':j['ability'].get('yorick_discards')} for j in (s or {}).get('jokers',[]) if j.get('key')=='j_yorick']
def inventory(s):return dict(Counter(c.get('key') for c in (s or {}).get('consumeables',[])))
rows=[]
for event in attempts:
    sequence=event['sequence'];details=event['details'];action=details['action'];before=event['state'];advice=details.get('advice') or {}
    request=byseq.get(sequence+1);matched=request and request['kind']=='action_requested' and request['details'].get('input',{}).get('action')==action
    after_event=settled.get(request['sequence']) if matched else None;after=after_event['state'] if after_event else None
    callback=callbacks.get(request['sequence']) if matched else None
    observed=byseq.get(sequence+4)
    if not (observed and observed['kind']=='auto_run' and observed['details'].get('event')=='action_observed'):observed=None
    delay=observed['details']['time']-details['time'] if observed else None
    row={'sequence':sequence,'at':event['at'],'seed':event['seed'],'run_action':details.get('run_action'),
         'ante':before.get('ante'),'round':before.get('round'),'phase':before.get('phase'),
         'action':action,'title':advice.get('title'),'request_exactly_matches':bool(matched),
         'callback_accepted':callback['details'].get('callback_returned') if callback else None,
         'settled_sequence':after_event['sequence'] if after_event else None,'end_to_next_advice_observation_seconds':delay,
         'target_before':before.get('blind',{}).get('chips'),'chips_before':before.get('chips'),
         'chips_after':after.get('chips') if after else None,'phase_after':after.get('phase') if after else None,
         'dollars_before':before.get('dollars'),'dollars_after':after.get('dollars') if after else None}
    text=' '.join(advice.get('lines') or [])
    row['growth_discard']='grow Yorick' in (advice.get('title') or '') and action['kind']=='discard'
    row['consumable_already_clear']=action['kind']=='use' and 'existing clearing play' in text
    if row['growth_discard'] or row['consumable_already_clear']:
        row.update(advice_lines=advice.get('lines'),yorick_before=yorick(before),yorick_after=yorick(after),inventory_before=inventory(before),inventory_after=inventory(after) if after else None)
    if action['kind']=='play':
        same_round=after is not None and after.get('round')==before.get('round') and event['seed']==after_event['seed']
        if same_round and isinstance(before.get('chips'),(int,float)) and isinstance(after.get('chips'),(int,float)) and after['chips']>=before['chips']:
            row['observed_chip_delta']=after['chips']-before['chips']
            target=before.get('blind',{}).get('chips')
            if isinstance(target,(int,float)) and target>0:
                row['observed_cumulative_to_target']=after['chips']/target
                row['observed_delta_to_remaining']=(after['chips']-before['chips'])/max(1,target-before['chips'])
                row['observed_clear']=after['chips']>=target
        row['advice_lines']=advice.get('lines')
    rows.append(row)

runs=[]
for idx,start in enumerate(run_starts):
    end=run_starts[idx+1]['sequence'] if idx+1<len(run_starts) else float('inf')
    records=[r for r in rows if start['sequence']<r['sequence']<end]
    terminals=[e for e in events if start['sequence']<e['sequence']<end and e['kind']=='auto_run' and e['details'].get('event')=='run_finished']
    last=terminals[-1] if terminals else next(e for e in reversed(events) if start['sequence']<=e['sequence']<end and e['state'] and e['seed']==start['seed'])
    delays=[r['end_to_next_advice_observation_seconds'] for r in records if r['end_to_next_advice_observation_seconds'] is not None]
    plays=[r for r in records if r['action']['kind']=='play']
    grouped=defaultdict(list)
    for r in records:
        if r['end_to_next_advice_observation_seconds'] is not None:grouped[r['action']['kind']].append(r['end_to_next_advice_observation_seconds'])
    terminal=None
    if terminals:
        t=terminals[0];s=t['state'];proof=t['details'].get('evidence',{})
        terminal={'sequence':t['sequence'],'outcome':t['details'].get('outcome'),'evidence':proof,
                  'game_over_observed':t.get('game_over'),'ante':s['ante'],'round':s['round'],'blind':s['blind'],
                  'chips':s['chips'],'dollars':s['dollars'],'hands_left':s['hands_left'],'discards_left':s['discards_left'],
                  'run_seconds':t['details'].get('run_seconds'),'run_actions':t['details'].get('run_actions'),
                  'yorick':yorick(s),'jokers':[j.get('key') for j in s['jokers']],'inventory':inventory(s),
                  'loss_consistent':t['details'].get('outcome')=='loss' and t.get('game_over') is True and proof.get('source')=='GAME_OVER' and proof.get('verified') is True and s['chips']<s['blind']['chips']}
    runs.append({'run_number':start['details']['run_number'],'seed':start['seed'],'loaded_version':start['version'],'started_at':start['at'],
                 'actions_logged':len(records),'actions_by_kind':dict(Counter(r['action']['kind'] for r in records)),
                 'actions_by_phase':dict(Counter(r['phase'] for r in records)),
                 'matching_requests':sum(r['request_exactly_matches'] for r in records),'accepted_callbacks':sum(r['callback_accepted'] is True for r in records),
                 'settled_associations':sum(r['settled_sequence'] is not None for r in records),
                 'skip_blinds':[{'sequence':r['sequence'],'ante':r['ante'],'blind':r['action'].get('blind'),'title':r['title']} for r in records if r['action']['kind']=='skip_blind'],
                 'growth_discards':[r for r in records if r['growth_discard']],
                 'already_clearing_consumable_actions':[r for r in records if r['consumable_already_clear']],
                 'development_action_observation_seconds':{label:sum(r['end_to_next_advice_observation_seconds'] or 0 for r in records if r[field])
                                                           for label,field in [('growth_discards','growth_discard'),('already_clearing_consumable_uses','consumable_already_clear')]},
                 'play_count':len(plays),'plays_with_observed_deltas':sum('observed_chip_delta' in r for r in plays),
                 'clear_ratios':{'greater_than_2x':sum(r.get('observed_cumulative_to_target',0)>2 for r in plays),
                                 'greater_than_1_5x':sum(r.get('observed_cumulative_to_target',0)>1.5 for r in plays),
                                 'top':[{'sequence':r['sequence'],'ante':r['ante'],'round':r['round'],'target':r['target_before'],
                                         'observed_chips':r['chips_after'],'observed_ratio':r.get('observed_cumulative_to_target'),'advice_title':r['title']}
                                        for r in sorted(plays,key=lambda r:r.get('observed_cumulative_to_target',0),reverse=True)[:6]]},
                 'timing':{'matched_action_to_observation_count':len(delays),'sum_seconds':sum(delays),'median_seconds':statistics.median(delays) if delays else None,
                           'maximum_seconds':max(delays) if delays else None,'by_action':{k:{'count':len(v),'sum_seconds':sum(v),'median_seconds':statistics.median(v),'max_seconds':max(v)} for k,v in grouped.items()},
                           'scope':'Wall time from auto action attempt to next fresh-advice observation, including action/animation/settling/advice/logging. Not isolated advisor computation time or saved-time estimate.'},
                 'terminal':terminal,'last_public_observation':{'at':last['at'],'sequence':last['sequence'],'phase':last['state']['phase'],'ante':last['state']['ante'],'round':last['state']['round'],'dollars':last['state']['dollars']},
                 'terminal_absent_in_read_prefix':not terminals})

report={'scope':'Existing opt-in public logs, bounded fixed input prefix; no gameplay, replay, rescoring, simulation, source execution, save/profile reads or new experiment.',
        'input_projection_sha256':hashlib.sha256(INPUT.read_bytes()).hexdigest(),'inputs':data['inputs'],'parse_errors':data['errors'],'limits':data['caps'],'actual_parse_cost':data['actual'],
        'runs':runs,'actions':rows,
        'logging_gaps':['No published decision start/end timestamps, elapsed computation time, evaluations/score-call count, budget allocation or cache hits in this journal schema.',
                        'Advice stores UI title/lines/action, not structured score proof, alternatives, growth policy metadata, target resource comparison or skip-route qualification.',
                        'State-after-actions is the first settled public observation and can coalesce callbacks; accepted callback alone is not effect completion.',
                        'Auto action-to-observation time includes engine animation, scheduling, advice computation and logging and cannot isolate optimization cost.',
                        'Current-prefix outcome absence is not a timeout, stop, loss or win; logging remains append-only and may continue after the fixed read.',
                        'Versions are declared by loaded public logging context; this does not independently hash the loaded Lua modules or confirm game animation speed.'],
        'analysis_tool_note':'Initial parser attempt hit a Python Counter.update(dict) mistake before output; corrected to count dictionary keys. This was a read-only analysis error, not a gameplay/evaluation result. Original logs were unchanged.'}
out=HERE/'public_run_report_final.json'
with out.open('x',encoding='utf-8') as stream:json.dump(report,stream,indent=2);stream.write('\n')
print(json.dumps({'report_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'runs':[{
    'run_number':r['run_number'],'seed':r['seed'],'actions':r['actions_logged'],'action_counts':r['actions_by_kind'],
    'request_matches':r['matching_requests'],'callback_accepted':r['accepted_callbacks'],'settled':r['settled_associations'],
    'plays':r['play_count'],'observed_play_deltas':r['plays_with_observed_deltas'],'growth':len(r['growth_discards']),
    'already_clearing_uses':len(r['already_clearing_consumable_actions']),'ratios':r['clear_ratios'],
    'timing':r['timing'],'terminal':r['terminal'],'last':r['last_public_observation']} for r in runs]},indent=2))
