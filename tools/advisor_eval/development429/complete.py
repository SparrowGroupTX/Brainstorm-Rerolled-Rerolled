"""Publish429 evidence and navigation after the one-use evaluation closes."""
from pathlib import Path
from datetime import datetime,timezone
from collections import Counter
import json,subprocess,sys,shutil

HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL));sys.path.insert(0,str(HERE))
from benchmark import policy_hashes,digest,file_digest
import run

def save(p,x):
    with Path(p).open('x',encoding='utf-8') as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,s):
    with Path(p).open('x',encoding='utf-8') as f:f.write(s)
def fmt(n):return 'unavailable' if n is None else f'{n:.3f}'

data=run.read(HERE/'RESULTS.json');m=run.verify();run.verify_sources(m)
assert run.read(HERE/'READY.json')['manifest_sha256']==run.sha(HERE/'manifest.json')
assert run.read(HERE/'EXECUTION_STARTED.json')['manifest_sha256']==run.sha(HERE/'manifest.json')
closed=run.read(HERE/'CLOSED.json');assert closed['allowance_closed'] and closed['remaining_authority']==0
prior=run.read(HERE/'PRESERVATION.json')
for p,h in prior['prior_files'].items():assert file_digest(p)==h,p
base=run.read(EVAL/'SESSION_RESET_426.json');installed=Path(base['installed'])
assert policy_hashes(installed.parent)==base['policy_files']==prior['installed_files']
candidate=run.read(EVAL/'runs/repair428_candidate1/freeze.json')
assert policy_hashes(ROOT)==candidate['candidate_policy_files']
before428=run.read(EVAL/'development428/prework.json')
assert file_digest(installed/'config.lua')==before428['config_sha256']
for root in (installed,ROOT/'Brainstorm'):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==before428['native_files']
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
assert branch=='codex/exact-search-speedups'
proc=subprocess.run(['pwsh','-NoProfile','-Command',
    "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
    capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(proc.stdout)if proc.stdout.strip()else []
rows={p.stem:run.read(p)for p in (HERE/'results').glob('*.json')}
assert len(rows)==302
for key,r in rows.items():
    if r.get('log_sha256'):assert file_digest(HERE/'results'/f'{key}.log')==r['log_sha256']
    if r['status']=='complete':assert r['result']['input_unchanged']
    if r['status']!='not_started':
        assert run.read(HERE/'ledger'/f'{key}.started.json')['manifest_sha256']==run.sha(HERE/'manifest.json')
abstentions={role:dict(Counter(r['result']['decision'].get('title','unspecified')for r in rows.values()
    if r['mode']=='decision' and r['policy']==role and r['status']=='complete' and not r['result']['decision'].get('action')))for role in ('baseline','candidate')}
invalid={role:[key for key,r in rows.items()if r['mode']=='decision' and r['policy']==role and r['status']=='complete'
    and r['result'].get('legality',{}).get('status')=='invalid']for role in ('baseline','candidate')}
assert not any(invalid.values()),invalid
verification={'created_utc':datetime.now(timezone.utc).isoformat(),'branch':branch,
    'manifest_sha256':run.sha(HERE/'manifest.json'),'source_and_frozen_files_unchanged':True,
    'prior_preserved_files':len(prior['prior_files']),'all_prior_hashes_match':True,
    'candidate_digest':candidate['candidate_policy_digest'],'installed_digest':base['policy_digest'],
    'candidate_runtime_unchanged':True,'installed_runtime_unchanged':True,'settings_and_dlls_unchanged':True,
    'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,
    'runtime_release':False,'candidate_installed':False,'candidate_loaded_evidence':False,
    'jobs':len(rows),'abstentions':abstentions,'invalid_decision_selections':invalid,
    'closed':closed,'win_rate_claim':False,'full_run_simulations':0,'new_authority_remaining':0,
    'historical_allowances_reopened':False,'review_exhausted':True,
    'game_control':False,'saves_or_profiles_accessed':False,'automation_created':False}
save(HERE/'FINAL_VERIFICATION.json',verification)

allm=data['decision']['all'];roundm=data['continuation']['primary_complete_two_world_rounds']
decision_lines=[]
for group in ('old_unused','old_short_control','old_full_control','current_reported','all'):
    v=data['decision'][group];b=v['baseline'];a=v['candidate']
    decision_lines.append(f"| {group} | {v['paired_complete']}/{v['registered']} | {b['discard_actions']} -> {a['discard_actions']} | {fmt(b['cards_per_discard'])} -> {fmt(a['cards_per_discard'])} | {b['five_card_discards']} -> {a['five_card_discards']} |")
b=roundm['baseline'];a=roundm['candidate']
report=f'''# Evaluation429 results:2.209 versus frozen2.210

This is a completed offline counterfactual comparison, using the exact frozen
policies. It made no runtime changes. Candidate2.210 remains uninstalled;
installed2.209 is unchanged. No loaded-game win-rate improvement is established.

## Modeled round metrics

Primary coverage: **{roundm['distinct_rounds']}/12 distinct rounds**, each with both
registered hypothetical worlds completed by both policies. These are selected
suspect checkpoints with a shared observed prefix, not fresh complete runs or
a representative sample of all rounds. Two worlds from one round are correlated.

| Metric |2.209 baseline|2.210 candidate|
|---|---:|---:|
| Discards per round, including shared observed prefix |{fmt(b['discards_per_round'])}|{fmt(a['discards_per_round'])}|
| Cards per discard, including shared observed prefix |{fmt(b['cards_per_discard'])}|{fmt(a['cards_per_discard'])}|
| Cards discarded per round |{fmt(b['cards_discarded_per_round'])}|{fmt(a['cards_discarded_per_round'])}|
| Discards remaining at supported clear |{fmt(b['mean_remaining_discards_at_clear'])}|{fmt(a['mean_remaining_discards_at_clear'])}|
| Continuation full-five discards, across included worlds |{b['continuation_five_card_discards']}|{a['continuation_five_card_discards']}|

All registered continuation statuses (24 branches per policy):
`{json.dumps(data['continuation']['statuses'],sort_keys=True)}`.
The results retain every censored/unsupported/timeout/unstarted branch. The table
conditions on complete paired supported clears; it is not an unconditional
success estimate. Prefix discard counts all matched public counters. Prefix card
totals derive from request histories; no new independent settlement audit was
performed for this experiment. Earlier audit427 preserved linked settlements.

## Immediate paired decisions

| Selection |Complete pairs|Discard actions, before -> after|Cards/discard, before -> after|Full-five actions, before -> after|
|---|---:|---:|---:|---:|
{chr(10).join(decision_lines)}

Action-kind transitions: `{json.dumps(allm['action_transitions'],sort_keys=True)}`.
No-advice abstentions: `{json.dumps(abstentions,sort_keys=True)}`. A completed
worker means evaluation returned; it does not imply a legal action was available.
All emitted play/discard selections passed the adapter's selection audit.
Changed exact action IDs: `{json.dumps(allm['changed_ids'])}`.

Older snapshots were recorded under2.208; both2.209 and2.210 are counterfactual
policies on those unchanged inputs. Baseline exact action matches to recorded
actions: {allm['baseline_matches_recorded']}/{allm['paired_complete']}. Public
projection can remove concealed information and runtime context; this is not a
bit-identical reconstruction of historical live execution.

## Qualification and limits

Manifest `{run.sha(HERE/'manifest.json')}` was finalized before any captured
evaluation. The single serial below-normal-priority worker processed302
registered jobs in {closed['seconds']:.1f} seconds: `{json.dumps(closed['counts'])}`.
The allowance is closed, including unused capacity. No retry or replacement.
The sole review cycle is exhausted. Frozen files, source archives, prior work,
installed runtime, settings and DLLs passed final preservation checks.

Invented adapter checks passed; their raw failures and corrections are preserved.
The final invented input is a parity control, not an improvement claim. The
candidate's existing exact full validation remains300 Lua fixtures/458 Python
tests; this tooling-only evaluation did not modify those policy bytes.

Future draws and rank/suit sorting are explicitly hypothetical. Private draw
order was withheld from the policy. Unsupported actions, unknown new draw
identities and uncertain random scoring transitions are censored. Immediate
supported score floors establish modeled round clears only; rewards and later
rounds were not simulated. The separate full-run simulator does not call this
advisor, so using it here would not answer whether this policy improves runs.

Detailed evidence: RESULTS.json, DECISION_PAIRS.json, ROUND_PAIRS.json, results/,
ledger/, manifest.json, PLAN.md, REVIEW.md and FINAL_VERIFICATION.json. No original
game execution, live game control, saves/profile access, training or automation.
'''
write(HERE/'REPORT.md',report)
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
     'tools/advisor_eval/README.md','tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md']
prefix=f'''EVALUATION429 COMPLETE -2026-09-27
Fresh user-authorized offline2.209/2.210 counterfactual comparison is CLOSED.
Read tools/advisor_eval/development429/REPORT.md, RESULTS.json and
FINAL_VERIFICATION.json; PLAN.md/manifest.json bind the one-use302-job allowance.
All historical allowances remain closed; no automatic reruns or follow-on jobs.
Primary paired coverage:{roundm['distinct_rounds']}/12 rounds, two hypothetical worlds each.
Discards/round:{fmt(b['discards_per_round'])}->{fmt(a['discards_per_round'])};
cards/discard:{fmt(b['cards_per_discard'])}->{fmt(a['cards_per_discard'])}.
Selected checkpoints plus shared observed prefixes; no population win-rate claim.
Candidate428/2.210 remains validated and UNINSTALLED; runtime bytes unchanged.
Installed426/2.209 unchanged. See CANDIDATE_CHECKPOINT_428 and INSTALLATION_POLICY.
Review429 exhausted. Earlier428 delivery and full mandatory rules follow.

'''
backup=HERE/'navigation_before';backup.mkdir()
for rel in nav:
    source=ROOT/rel;destination=backup/rel;destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,destination);source.write_text(prefix+source.read_text(encoding='utf-8'),encoding='utf-8')
save(EVAL/'EVALUATION_CHECKPOINT_429.json',verification)
write(EVAL/'EVALUATION_CHECKPOINT_429.md',prefix)
write(EVAL/'NEXT_PRIORITIES_429.md',
    '# Priorities after evaluation429\n\nRead development429/REPORT.md and RESULTS.json for actual measured changes and coverage. '
    'The experiment is closed; no reruns or follow-on experiments. Candidate428/2.210 remains validated and uninstalled. '
    'Runtime follow-ups remain those in NEXT_PRIORITIES_428.md, interpreted in light of429 results. '
    'No all-fixed or win-rate claim; preserve live logs and release boundaries.\n')
write(EVAL/'ARCHITECTURE_MAP_429.md',
    '# Evaluation429 map\n\nDevelopment429 contains the one-use offline runner, current frozen wiring and private-world continuation driver; '
    'analyze.py aggregates without invoking policy. PLAN/manifest/READY precede EXECUTION_STARTED; ledger/results/CLOSED preserve all jobs. '
    'DECISION_PAIRS/ROUND_PAIRS/RESULTS/REPORT/FINAL_VERIFICATION are descriptive outputs. '
    'Runtime architecture and freeze remain ARCHITECTURE_MAP_428.md and repair428_candidate1. No full-run advisor simulator was qualified.\n')
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({'report':str(HERE/'REPORT.md'),'rounds':roundm,'abstentions':abstentions,'preservation':True,'processes':processes},indent=2))
