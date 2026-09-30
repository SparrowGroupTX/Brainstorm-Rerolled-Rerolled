"""Verify the passive audit and publish concise navigation without runtime edits."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,subprocess
P=Path(__file__).resolve().parent;EVAL=P.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
 with Path(p).open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,s):
 with Path(p).open('x',encoding='utf-8')as f:f.write(s)
pre=read(P/'prework.json');installed=read(EVAL/'SESSION_RESET_431.json')
assert policy_hashes(ROOT)==policy_hashes(Path(installed['installed']).parent)==pre['policy_files']==installed['policy_files']
assert test_manifest()==pre['test_files']and provenance()==pre['provenance']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():
 assert file_digest(P/'navigation_before'/rel)==h and file_digest(ROOT/rel)==h
capture=ROOT/pre['capture'];m=read(capture/'manifest.json');s=read(capture/'summary.json')
assert file_digest(capture/'manifest.json')==pre['manifest_sha256']
assert file_digest(capture/'summary.json')==pre['summary_sha256']
assert file_digest(capture/'events.sqlite3')==pre['database_sha256']
for row in m['segments']:assert file_digest(capture/'logs'/row['name'])==row['sha256']
assert s['events']==30608 and s['outcomes']=={'win':6,'loss':2,'unsupported':2}
assert len(s['starts'])==len(s['endings'])==10 and not s['unended_run_ids']and not s['errors']
a=read(P/'analysis/summary.json');d=read(P/'discard/summary.json');deep=read(P/'deep2/summary.json')
flags=read(P/'suspects/report.json');econ=read(P/'economic/summary.json')
assert a['actions_with_policy_action']==deep['link_checks']==2639 and not deep['link_failures']
assert not d['discard_resource_mismatches']and d['discard_actions']==533 and d['discarded_cards']==2101
assert d['discard_size_counts']=={'5':282,'2':39,'3':88,'1':49,'4':75}
assert d['unused_clear_count']==38 and d['unused_total']==98
assert d['development_deferred']==43 and d['development_deferred_then_non_discard']==0
assert d['enhancement_then_clear_without_discard']==24
assert flags['flags_total']==293 and flags['flags_omitted']==0
assert deep['death_uses']==deep['death_confirmed']==21 and deep['buffoon_reveals']==deep['buffoon_reveals_confirmed']==26
assert econ['cash_target_exits']==66 and econ['total_shop_exits']==190
assert econ['spending_receipt_status']=={'no_affordable_spend_above_buffer':66}
terminal=read(P/'discard/terminal.json')
assert {x['run']:x['last_play_settled']['after']['chips']for x in terminal}=={1:3600,9:5570}
findings=[
 {'id':'discard_coverage','priority':1,'classification':'confirmed_admission_gaps_not_all_safe_alternatives',
  'requests':[443,488,13323,18938,25167,25757],'next_fixture':'Qualify actual remaining canonical Joker/order families without raising budgets.'},
 {'id':'retained_anchor_portfolio','priority':1,'classification':'source_supported_candidate_coverage_hypothesis',
  'requests':[9916,9942],'next_fixture':'Blue Joker thin single anchor versus stronger resource-safe Pair; bounded second anchor within12calls.'},
 {'id':'owned_blueprint_buffoon','priority':1,'classification':'confirmed_offer_valuation_exclusion',
  'requests':[3001],'next_fixture':'Full row with owned Blueprint and replaceable noncore slot retains funded further-copy pack exploration.'},
 {'id':'cash_floor_semantics','priority':2,'classification':'confirmed_retained_floor_not_spend_trigger',
  'requests':[2826,3001,30211],'next_fixture':'One affordable spend may cross preferred target while retaining mandatory resources and engine.'},
 {'id':'world_fool_slot_exchange','priority':1,'classification':'confirmed_executable_capacity_coverage_gap',
  'requests':[2222],'next_fixture':'Whole inventory ordinary-slot sale→Fool/Jupiter exchange; Negative removal cannot create ordinary capacity.'},
 {'id':'blueprint_finishing_budget','priority':1,'classification':'confirmed_pipeline_mechanism_safe_replacement_unproved',
  'requests':[30200,30211],'next_fixture':'Complete and retain supported focused copy endpoints despite uncertain incumbent, inside existing allowance.'},
 {'id':'hit_road_fallback','priority':2,'classification':'confirmed_model_gap_choice_suboptimality_unproved',
  'requests':[26219,26229],'next_fixture':'Compare legal discard-dependent growth and perishable horizons with complete shared worlds.'},
 {'id':'hook_diagnostic','priority':3,'classification':'confirmed_misleading_reason',
  'requests':[26854],'next_fixture':'Known public Hook6400 must report unsupported boss mechanics rather than missing target.'},
 {'id':'acorn_continuity','priority':1,'classification':'repaired_in_installed2.212_loaded_validation_pending',
  'advice':[23370,26046],'evidence':'development430/TRACE.json; exact430/431 manufactured gates'}]
save(P/'FINDINGS.json',{'audit_revision':432,'loaded_version_analyzed':'2.209.0-alpha',
 'installed_version':'2.212.0-alpha','findings':findings,'counterfactual_win_claim':False})
prefix='''PASSIVE AUDIT432 COMPLETE —2026-09-27
Installed runtime remains431/2.212, both exact gates302Lua/458Python passed.
Read tools/advisor_eval/SESSION_RESET_431.md/.json for installation,
development432/REPORT.md, FINDINGS.json, AUDIT_VERIFICATION.json and REVIEW.md,
NEXT_PRIORITIES_432.md and ARCHITECTURE_MAP_432.md for the completed latest-session audit.
Preserved loaded2.209 session: development430/captures/002;30,608events,
6wins/2losses/2unsupported;10starts/10endings,no unended runs, originals untouched.
533discards/2101cards,282full-five;38clears left98discards (89before future blinds).
293suspect flags,zero omitted;2639policy-action causal joins without link failures.
Remaining: alternate retained anchors/canonical Joker proofs; full-row Buffoon
exploration stops after first Blueprint; cash targets act as minimum balances;
full-slot World/Fool/Jupiter exchange; focused Blueprint finishing/budget gap.
Negative findings: both Perkeo sales were final Leaf clears; lowcash Brainstorm
was not affordable; pack score conflicts/Invisible passes are not proved mistakes.
431 includes both Amber Acorn continuity fixes, but loaded2.212 effectiveness is
unconfirmed. No population win rate or all-fixed claim. Audit is passive only;
no new runtime edits, captured policy/scorer replay, game control or experiment.
432review exhausted. Historical experiments CLOSED. Earlier history follows.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;prior=p.read_bytes();p.write_bytes(prefix.encode()+prior);assert p.read_bytes().endswith(prior)
write(EVAL/'NEXT_PRIORITIES_432.md',
 '# Priorities432\n\nInstalled431/2.212 is release-complete. Inspect actual user-loaded discard and Amber Acorn '
 'behavior when new public evidence is supplied; no monitor implied.\n\n'
 'Next implementation should select one evidence-backed slice from development432/FINDINGS.json: '
 'bounded alternative retained anchors or missing canonical order proofs; further-copy Buffoon exploration '
 'after owning Blueprint; spend-down targets distinct from hard reserves; full-slot World/Fool/Jupiter exchange; '
 'focused visible Blueprint finishing/candidate budget preservation. Hit-the-Road comparison and truthful '
 'Hook support diagnostics follow. Preserve caps and qualify complete comparisons.\n\n'
 'Audit432 is passive and complete; sole review exhausted. Closed429/historical experiments remain closed. '
 'No new captured replay authority. Read REPORT/REVIEW/AUDIT_VERIFICATION and SESSION_RESET_431.\n')
write(EVAL/'ARCHITECTURE_MAP_432.md',
 '# Architecture432\n\nNo runtime change. Installed431/2.212 and its source map remain authoritative for bytes. '
 'development432 reuses analyze_public.py/deep_audit.py over immutable development430/captures/002; '
 'flag_suspect_decisions.py screens supplied hashes with1000existing flag cap (293produced). '
 'discard_audit.py joins real actions/counter endpoints, Tarot→clear chains and terminal/earlier rounds. '
 'economic_trace.py exports raw economic witnesses and all66above-target shop exits. '
 'All SQLite reads use mode=ro; no policy/scorer imports or execution.\n\n'
 'Relevant unchanged runtime seams: growth.select_clear chooses one shortest anchor; growth.suggest proves it. '
 'strategy.seeking_blueprint gates full-row Buffoon exploration; late_cash_spend enforces retained floors. '
 'Consumable capacity and stock-exchange admission precede value comparison. Focused copy finishing and ordinary '
 'replacement share bounded shop work. shop_scoring.next_blind excludes Hook and readiness can mislabel the reason.\n')
write(P/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
artifacts={p.relative_to(ROOT).as_posix():file_digest(p)for p in P.rglob('*')if p.is_file()}
record={'completed_utc':datetime.now(timezone.utc).isoformat(),'audit_revision':432,'runtime_revision':431,
 'installed_version':'2.212.0-alpha','policy_digest':installed['policy_digest'],'runtime_and_tests_unchanged':True,
 'loaded_version_analyzed':'2.209.0-alpha','capture':pre['capture'],'events':s['events'],'outcomes':s['outcomes'],
 'unended_runs':0,'archive_errors':0,'linked_policy_actions':2639,'link_failures':0,
 'discard_actions':533,'discarded_cards':2101,'five_card_discards':282,'unused_clear_rounds':38,'unused_discards':98,
 'flags':293,'flags_omitted':0,'prior_preserved_hashes':len(pre['prior_files']),
 'review_cycle_exhausted':True,'policy_or_scorer_replay':False,'new_experiments':False,
 'game_control':False,'save_profile_access':False,'win_rate_claim':False,'artifact_hashes':artifacts}
save(P/'AUDIT_VERIFICATION.json',record)
print(json.dumps({k:record[k]for k in ('audit_revision','installed_version','outcomes','linked_policy_actions','discard_actions','five_card_discards','unused_clear_rounds','unused_discards','prior_preserved_hashes')}))
