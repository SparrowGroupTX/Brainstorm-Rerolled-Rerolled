"""Verify the combined candidate, preservation and current passive status."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
    with Path(p).open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,s):
    with Path(p).open('x',encoding='utf-8')as f:f.write(s)
candidate=EVAL/'runs/repair430_candidate1';f=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json')
pre=read(HERE/'prework.json');base=read(EVAL/'SESSION_RESET_426.json');installed=Path(base['installed'])
assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==f['candidate_policy_files']==gate['policy_files']
assert test_manifest()==f['test_files']==gate['test_files']
assert provenance()==f['validation_provenance']==gate['validation_provenance']==pre['provenance']
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (installed,ROOT/'Brainstorm'):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==pre['native_files']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
changed={rel for rel,h in f['candidate_policy_files'].items()if pre['runtime_files'].get(rel)!=h}
assert changed=={'Brainstorm/Advisor/acorn_belief.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'},changed
changed_tests={rel for rel,h in f['test_files'].items()if pre['test_files'].get(rel)!=h}
assert changed_tests=={'tests/advisor_acorn_continuity430.lua'}
for rel,h in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==h
    if rel not in changed|changed_tests:assert file_digest(ROOT/rel)==h,rel
for rel,h in f['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==h
assert file_digest(HERE/'SCOPE.md')==f['scope_sha256']
for capture in sorted((HERE/'captures').iterdir()):
    m=read(capture/'manifest.json');s=read(capture/'summary.json')
    assert all(e['classification']=='incomplete_live_tail'for e in s['errors'])
    for segment in m['segments']:assert file_digest(capture/'logs'/segment['name'])==segment['sha256']
    assert file_digest(capture/'events.sqlite3')==s['database_sha256']
latest=read(HERE/'LATEST.json');capture=ROOT/latest['capture'];summary=read(capture/'summary.json')
assert file_digest(capture/'summary.json')==latest['summary_sha256']
lua=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text())
assert lua and lua[1]==lua[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'))
assert int(lua[1])==301 and py==458
assert len(f['candidate_policy_files'])==110 and len(f['test_files'])==350
ps=subprocess.run(['pwsh','-NoProfile','-Command',
    "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
    capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else []
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
assert branch=='codex/exact-search-speedups'
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':430,'version':'2.211.0-alpha',
    'status':'frozen_validated_not_installed','candidate':candidate.relative_to(ROOT).as_posix(),
    'policy_digest':f['candidate_policy_digest'],'policy_files':f['candidate_policy_files'],'runtime_file_count':110,
    'changed_runtime_vs_installed':f['changed_runtime_files'],'changed_runtime_vs428':sorted(changed),
    'test_files':f['test_files'],'test_file_count':350,'validation_counts':{'lua_fixtures':301,'python_tests':458},
    'new_fixture_assertions':3227,'baseline_unsupported_causes_reproduced':2,'review_cycle_exhausted':True,
    'installed_checkpoint':426,'installed_version':base['version'],'installed_digest':base['policy_digest'],
    'installed_runtime_unchanged':True,'settings_and_seven_dlls_preserved':True,'prior_preserved_hashes':len(pre['prior_files']),
    'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,'normal_exit_confirmation_required':False,
    'latest_capture':latest,'latest_outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
    'candidate_loaded_evidence':False,'win_rate_claim':False,'captured_policy_replay430':False,
    'game_control':False,'save_profile_access':False,'original_game_execution':False,'automation_created':False,
    'experiment429':'CLOSED; unchanged results retained','historical_allowances':'CLOSED','branch':branch}
save(HERE/'FINAL_VERIFICATION.json',record);save(EVAL/'CANDIDATE_CHECKPOINT_430.json',record)
diff=[]
for rel in sorted(changed|changed_tests):
    old=HERE/'before'/rel
    diff.extend(difflib.unified_diff(old.read_text().splitlines(True)if old.exists()else[],
        (ROOT/rel).read_text().splitlines(True),fromfile='before430/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
process_note='Balatro remains running; installation is deferred.'if processes else 'Balatro is absent; installation is authorized after a fresh immediate recheck and journal preservation.'
report=f'''# Repair430: both Amber Acorn unsupported stops repaired

Frozen combined2.211 candidate `{f['candidate_policy_digest']}` passed **301 Lua
fixtures and458 Python tests**.110 runtime dependencies and350 test files match
the exact freeze. Candidate includes the pending428 discard repair. It is not
installed; installed2.209 is unchanged. {process_note}

## Confirmed causes

Both reported runs reached Ante8 Amber Acorn and retired immediately after the
first hand because the public Joker ability model invalidated itself.

| Run | Cause | Advice/retirement | Resources remaining |
|---|---|---|---|
|7|Smiley Face missing from ability continuity whitelist|23370/23373|3 hands,3 discards;4,860/400,000 chips|
|8|Supernova missing from ability continuity whitelist|26046/26049|4 hands,3 discards;51,552/400,000 chips|

The initial120 possible Joker orders were intact. Public scoring observations
reduced them to18 and10 respectively. The next failure occurred in
`advance_public`, whose message was 'This Joker has unqualified changes during
public actions.' That removed the valid-ability qualification; Decision returned
no supported action and the product's existing retirement path ran. Neither
retirement was an actual terminal loss. The remaining resources do not prove
either run would have won. Full anchors are in TRACE.json and stop_trace.json;
immutable raw public events are in captures/001 and stop_events.json.

## Repair and evidence

Canonical Smiley Face and Supernova retain their public ability state across
plays/discards. Smiley's face-card coefficient is fixed; Supernova reads the
fresh public played count for the selected hand category. Neither is assigned
an identity from guessed popup amounts, and neither gets a stored score counter.
Wrong names, coefficients, effects, generic modifiers and editions are rejected
before scoring and at advancement, including debuffed/copied targets.

The new manufactured fixture passes3227 assertions: both affected mixed rows,
every24-order copied growth comparison, real score transitions, fresh category
history, malformed forms, hidden-payload traps and real observer-to-Decision
play/discard/play continuity with exactly-once settlement. The previous exact428
module reproduces both unsupported causes. Raw fixture failures/corrections and
the completed sole review are retained in targeted logs and REVIEW.md.

Latest preserved public prefix: {latest['capture']}, {summary['events']} verified
events; outcomes `{json.dumps(summary['outcomes'])}`; unended run IDs
`{json.dumps(summary['unended_run_ids'])}`. Preserve that distinction from game
process state. Original logs, settings, native DLLs and all{len(pre['prior_files'])}
prior file hashes remain intact. No runtime deployment, live control, source
game execution, save/profile access or new simulation occurred in430.

## Discard counterfactual result from closed429

The independent2.209/2.210 comparison completed all302 jobs in419.3seconds,
with no worker error or timeout. On12 selected modeled rounds with two shared
hypothetical futures each, discards/round rose1.167->1.333 and cards/discard
3.000->3.094. Only one of12 rounds changed; remaining discards at clear still
averaged1.75. Eight of127 immediate paired decisions changed play->discard;
seven pairs abstained because public snapshots concealed cards. Short-discard
controls were unchanged. These results are modest and do not solve the broader
discard issue or establish a win rate. See development429/REPORT.md/RESULTS.json.
No new captured evaluation was performed on2.211;429 and every historical
experiment allowance remain permanently closed.

Next: validate loaded2.211 continuity through actual Amber Acorn encounters once
the user installs/loads it. Remaining priorities include Raised Fist/Blackboard
retained floors, larger order-dependent anchors, full-slot World/Fool replacement,
and the previously recorded full-row Blueprint admission gap. No all-fixed claim.
'''
write(HERE/'REPORT.md',report)
prefix=f'''FROZEN CANDIDATE430 -2026-09-27
Combined2.211.0-alpha validated:301 Lua/458 Python,110 dependencies/350 frozen tests.
NOT INSTALLED. Installed/user-loaded426/2.209 unchanged. {process_note}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_430.md/.json, NEXT_PRIORITIES_430.md,
ARCHITECTURE_MAP_430.md and development430/REPORT.md, TRACE.json, REVIEW.md,
FINAL_VERIFICATION.json. Digest {f['candidate_policy_digest']}.
Both reported Amber Acorn retirements traced to missing Smiley/Supernova public
ability continuity.3227 manufactured assertions; exact428 reproduces both causes.
Includes pending428 discard repair; no loaded2.211 win/continuity claim.
Latest public journals preserved in {latest['capture']}; originals untouched.
429 comparison CLOSED:12 modeled rounds, discards/round1.167->1.333,
cards/discard3.000->3.094; only1/12rounds changed. Modest improvement, not solved.
No new experiment authority; historical budgets closed;430 review exhausted.
Installation follows INSTALLATION_POLICY: fresh absent process, newest logs,
explicit backed install_slice and exact-installed full gate; no confirmation.
No game control, saves/profile access or automatic monitoring. Earlier history follows.

'''
backup=HERE/'navigation_before';backup.mkdir()
for rel in pre['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    src=ROOT/rel;dst=backup/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    src.write_text(prefix+src.read_text(encoding='utf-8'),encoding='utf-8')
write(EVAL/'CANDIDATE_CHECKPOINT_430.md',prefix)
write(EVAL/'NEXT_PRIORITIES_430.md',
    '# Priorities430\n\nRelease validated combined2.211 when a fresh successful passive check confirms Balatro absent, '
    'after preserving latest public logs. No confirmation question. Installed2.209 remains unchanged while running. '
    'After loading, inspect Amber Acorn public belief state after successive plays/discards; never infer wins from unsupported retirement avoidance.\n\n'
    'Closed429 shows only modest discard improvement (one of12 rounds). Next runtime work should target the established '
    'Raised Fist/Blackboard retained-floor and larger-anchor gaps, then full-slot World/Fool replacement and full-row Blueprint admission. '
    'Do not reopen429 or historical experiments. Review430 is exhausted. Read REPORT/TRACE/FINAL_VERIFICATION.\n')
write(EVAL/'ARCHITECTURE_MAP_430.md',
    '# Architecture430\n\nacorn_public.lua retains only pre-concealment public inventory and observed popups/actions; '
    'acorn_belief.lua qualifies canonical ability continuity. New checked_opaque_keys entries for Smiley/Supernova '
    'guard before scoring and advancement while keeping popup matching opaque. Supernova reads fresh snapshot hands.played in scoring.lua. '
    'No observer/execution/retirement path changed. Tests/advisor_acorn_continuity430.lua exercises the real observer, belief, scorer and Decision.\n\n'
    'Combined freeze is repair430_candidate1; it includes428 growth/player_journal changes. Source navigation remains ARCHITECTURE_MAP_428. '
    'Closed offline evaluation wiring/results are documented in ARCHITECTURE_MAP_429.\n')
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:record[k]for k in ('version','policy_digest','validation_counts','prior_preserved_hashes','processes','latest_outcomes','unended_run_ids')},indent=2))
