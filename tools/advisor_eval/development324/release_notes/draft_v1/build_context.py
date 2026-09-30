"""Build detached324 CLOSED context drafts; no runtime/current-doc mutation."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def ref(path):return {'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path)}
def dump(path,value):path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')

previous_path=ROOT/'tools/advisor_eval/development323/release_notes/context.json'
previous=read(previous_path)
assert previous['status']=='CLOSED' and previous['counts_scope']=='historical_closed_cycle'
assert not any(previous['release_counts'].values()) and previous['remaining_authority_seconds']==0
for binding in previous['evidence'].values():assert sha(ROOT/binding['path'])==binding['sha256']
closure=read(ROOT/previous['evidence']['budget']['path'])
assert closure['status']=='CLOSED' and closure['active_workers']==0 and len(closure['closed_unused_slots'])==22
assert 'C09' in closure['closed_unused_slots']
audit=ROOT/'tools/advisor_eval/development324/log_audit'
audit_manifest=read(audit/'manifest.json')
for name,digest in audit_manifest['files'].items():assert sha(audit/name)==digest
assert all(audit_manifest[key]==0 for key in ('source_workers','policy_evaluations','search_workers','gameplay_actions'))
public=read(audit/'summary.json')
assert public['loaded_version']=='Brainstorm v2.123.0-alpha'
assert public['actual']=={'files':6,'physical_bytes':14440402,'decoded_bytes':280567235,'events':1519,'parse_seconds':4.375}
assert not public['errors'] and len(public['terminal_receipts_checked'])==2
assert all(row['outcome']=='loss' and row['loss_consistent'] for row in public['terminal_receipts_checked'])
limits=read(ROOT/previous['evidence']['limits']['path'])
limits['kind']='release324_closed_historical_limits'
limits['preparation_status']='draft_runtime_test_install_details_pending'
limits['prior_evidence']['release323_context']=ref(previous_path)
limits['prior_evidence']['release323_final']=ref(ROOT/'tools/advisor_eval/runs/idle323_final/final_verification.json')
limits['prior_evidence']['release323_reset']=ref(ROOT/'tools/advisor_eval/SESSION_RESET_323.json')
limits['prior_public_observations']=limits['public_observations']
limits['public_observations']={
    'kind':'separate_bounded_read_only_opt_in_public_journal_audit_not_source_experiments',
    'manifest':ref(audit/'manifest.json'),'note':ref(audit/'AUDIT.md'),
    'summary':ref(audit/'summary.json'),'report':ref(audit/'report.json'),
    'loaded_version_declaration':'Brainstorm v2.123.0-alpha','loaded_hashes_attested':False,
    'session':'session-20260915T062915Z-1','segments':[9,10,11,12,13,14],
    'first_at_utc':'2026-09-15T06:46:17Z','last_at_utc':'2026-09-15T06:56:24Z',
    'caps':public['caps'],'actual':public['actual'],'selected_tail_integrity_errors':0,
    'earlier_session_prefix_read':False,'newly_audited_complete_receipts':{'loss':2,'win':0},
    'out_of_tail_aggregate_win':'Recorded session counter only; earlier claimed win not independently verified by this selected tail.',
    'timing_scope':'295 mixed action-to-fresh-advice wall intervals; median1.6685807999999724seconds,maximum10.033090599999923seconds. Not CPU/freeze causality or release speedup.',
    'additional_external_reads_for_release_notes':0,
}
limits['release_scope']='Routine manufactured/regression validation, read-only repository review and one expressly bounded passive public-journal tail audit. Zero source/captured/search/complete jobs. No executable/original-source archive, game control, save/profile file, rescoring or replay.'
limits['limits']='Historical C01 policy300 alone has one selected synthetic win; later releases inherit none. No player odds, unseen holdout, general adapter qualification, release324 terminal result, verified Jokerless win or human superiority. Public journal receipts remain separate; out-of-tail aggregate outcomes are not newly audited.'
limits['cpu_scope']='Prospective low-overhead opt-in elapsed wall diagnostics, with precise journal anchors and compact bounded summaries no more than once per5seconds. Live CPU percentage, freeze cause, telemetry overhead and full-run speed improvement are unmeasured. Final collector limits/code/tests/install details pending root finalization.'
limits['known_inactive_proposal']='The earlier development323/journal sketch remains preserved and inactive. New324 journal timing is a separate reviewed/frozen implementation; exact finalization pending.'
limits['release_activation']='pending_user_normal_restart; only prior loaded2.123 string observed in selected public logs'
dump(HERE/'limits.json',limits)
context=json.loads(json.dumps(previous))
context.update(release=324,created_at_utc=datetime.now(timezone.utc).isoformat(),
    preparation_status='draft_runtime_test_install_details_pending')
context['summary']='Release324 introduces zero source, captured, search or complete experiments. Its goal is bounded opt-in elapsed wall diagnostics for reported freezing, precise event-entry monotonic timestamps and compact timing summaries without per-frame snapshots or writes. Routine manufactured/regression validation and the separate bounded passive public-journal audit do not identify a live CPU/freeze cause. Exact runtime/test/install details remain pending in the detached component draft. The original gold299 cycle remains CLOSED; counts below are historical, not new324 jobs.'
historical=previous['outcome_summary'].split(' Separately,')[0]
historical=historical.replace('Policies321,322 and323','Policies321,322,323 and324')
context['outcome_summary']=historical+' Separately, the earlier loaded321 public window recorded one Ante8 Big loss and an ongoing prefix. The fresh loaded323 public tail contains two consistent losses: RH45AD21 Ante5 Big18340/37500 and YAEARC31 Ante8 Amber Acorn98808/400000. The latter incidental won flag does not override GAME_OVER, the unmet threshold or its loss receipt. The final1win/4loss session aggregate includes earlier excluded outcomes; its claimed earlier win is not newly verified by this tail audit. Public product observations remain separate from synthetic experiment counts and are not324 terminal results.'
context['limits_summary']='Historical attempts are selected dependent synthetic all_unlocked_discovered_v1 development observations, not player odds, unseen holdouts, an actual achievement, general source-adapter qualification or human superiority. No verified complete Jokerless win or50%/75% per-challenge target is demonstrated. The passive journal declares loaded2.123, without attesting loaded hashes or game speed;324 activation waits for the user normal restart. The new audit establishes mixed action-to-advice intervals and large log payloads, not isolated CPU usage, freeze causality, telemetry overhead or release speedup. Existing errors/timeouts/unsupported/censored evidence and persistent retry caps remain intact. Final diagnostic implementation and validation facts are pending root finalization.'
context['budget_summary']=previous['budget_summary'].replace('Release323 adds zero','Release324 adds zero')
context['evidence']=dict(previous['evidence'],limits=ref(HERE/'limits.json'))
dump(HERE/'context.json',context)
spec=importlib.util.spec_from_file_location('release324_context_validator',ROOT/'tools/advisor_eval/finalize_runtime_checkpoint.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
validated=module.experiment_context(HERE/'context.json')
session,budget=module.experiment_json(validated)
assert session['new_experiments']==0 and session['complete_win'] is False
assert session['historical_verified_complete_win'] is True and session['historical_counts']==previous['counts']
assert all(budget[key]==0 for key in ('new_source_components','captured_pair_jobs','captured_policy_evaluations','searches','complete_attempts'))
dump(HERE/'validation.json',{'schema':1,'kind':'read_only_context_reference_validation','status':'passed',
    'context':ref(HERE/'context.json'),'historical_counts':context['counts'],'release_counts':context['release_counts'],
    'complete_attempt_outcomes':context['complete_attempt_outcomes'],'new_experiments':0,
    'new_release_complete_win':False,'historical_verified_complete_win':True,
    'finalizer_main_executed':False,'runtime_or_current_navigation_changed':False,
    'runtime_or_install_validation':'pending_root; this validates only draft schema/references/accounting',
    'additional_external_public_log_reads':0})
names=['build_context.py','TIMING_324.md','OBJECTIVE_324.md','NEXT_324.md',
    'ARCHITECTURE_NAVIGATION_324.md','README.md','context.json','limits.json','validation.json']
dump(HERE/'INPUT_MANIFEST.json',{'schema':1,'kind':'detached_release324_input_drafts',
    'status':'runtime_test_install_details_pending','files':{name:sha(HERE/name) for name in names}})
print(json.dumps({'context':ref(HERE/'context.json'),'limits':ref(HERE/'limits.json'),
    'input_manifest':ref(HERE/'INPUT_MANIFEST.json'),'runtime_or_navigation_changed':False},indent=2))
