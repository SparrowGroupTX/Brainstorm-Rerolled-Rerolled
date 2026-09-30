"""Read-only trace audit followed by immutable audit receipts; no source execution."""
from pathlib import Path
import hashlib
import json

base=Path(__file__).resolve().parents[1]/'runs/gold299_20260914'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def rows(path):return [json.loads(line) for line in path.read_text().splitlines() if line.startswith('{')]
for job in ['M02','M05']:
    folder=base/job;trace=folder/'trace.log';record=json.loads((folder/'record.json').read_text())
    data=rows(trace)
    assert sha(trace)==record['trace_sha256'] and record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert not any(r.get('type')=='engine_episode_action' for r in data)
    terminal=[r for r in data if r.get('type')=='engine_episode_terminal']
    callbacks=[r for r in data if r.get('type')=='engine_normal_progress_callback']
    if job=='M02':
        blocked=[r for r in data if r.get('type')=='engine_probe_blocked']
        assert record['status']=='error' and not terminal and len(blocked)==1 and 'CURSOR' in blocked[0]['reason']
        result={'status':'preserved_mechanical_error','case_started':'terminal_win_final','cases_completed':0,
                'reason':blocked[0]['reason'],'partial_progress_callback_count':len(callbacks),
                'interpretation':'Synthetic state reached original progress callbacks, then presentation-boundary error. No terminal outcome or successful qualification.'}
    else:
        assert record['status']=='complete' and record['exit_code']==0 and len(terminal)==4
        started=[r['scenario'] for r in data if r.get('type')=='mechanical_case_started']
        finished=[r for r in data if r.get('type')=='mechanical_case_finished']
        expected=['terminal_win_final','terminal_loss_final','terminal_saved_final','terminal_unsaved_final']
        assert started==expected and [r['scenario'] for r in finished]==expected and all(r['exit_code']==0 for r in finished)
        cases=[]
        for index,(scenario,t) in enumerate(zip(expected,terminal)):
            evidence=t['normal_progress'];context=evidence['final_context'];outcome=['win','loss','win','loss'][index]
            assert t['decisions']==0 and t['outcome']==outcome and context['ante']==8 and context['target']==800000
            assert context['chips']==[800000,0,200000,199999][index]
            assert t['source_game_won'] is True and t['game_over']==(outcome=='loss')
            assert evidence['deck_progress']==(outcome=='win') and evidence['joker_progress']==(outcome=='win')
            assert evidence['source_saved']==(index==2) and evidence['threshold_met']==(index==0)
            events=evidence['callbacks'] if isinstance(evidence['callbacks'],list) else []
            if outcome=='win':
                assert [e['name'] for e in events]==['set_joker_win','set_deck_win']
                assert events[-1]['before']['deck_wins']==0 and events[-1]['after']['deck_wins']==1
                assert events[-1]['after']['ante']==9 and not events[0]['after']['jokers']
            else:assert not events
            cases.append({'scenario':scenario,'expected_mechanical_terminal':outcome,'observed_terminal':t,
                          'verified':True,'complete_attempt':False})
        result={'status':'passed_four_mechanical_terminal_cases','cases':cases,
                'qualified_slice':'Original normal Gold final-round boundary, loss precedence, exact threshold, explicit Mr Bones survival and deck-win increment.',
                'unqualified_slice':'Joker-win callback ran with empty retained row in the positive cases; nonempty retained Joker increments need a separate mechanical case. Entire adapter and real player cohorts remain unqualified.'}
    result.update({'schema':1,'job':job,'record_sha256':sha(folder/'record.json'),'trace_sha256':sha(trace),
                   'registration_sha256':sha(folder/'registration.json'),'policy_decisions':0,
                   'selected_complete_attempts':0,'gameplay_wins':0,'qualification':False,
                   'profile':'synthetic all_unlocked_discovered_v1; no actual player profile/save access',
                   'inference':'Injected source-method fixtures, not autonomous runs or measured win odds.'})
    with (folder/'audit.json').open('x') as stream:json.dump(result,stream,indent=2)
    print(job,result['status'])
