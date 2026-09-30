"""Verify exact431, preserve history, and record passive release status."""
from pathlib import Path
from datetime import datetime,timezone
from collections import Counter
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
    with Path(p).open('x',encoding='utf-8')as out:json.dump(x,out,indent=2,allow_nan=False);out.write('\n')
def write(p,s):
    with Path(p).open('x',encoding='utf-8')as out:out.write(s)
candidate=EVAL/'runs/repair431_candidate1';f=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json')
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
assert changed=={'Brainstorm/Advisor/growth.lua','Brainstorm/Advisor/acorn_discard.lua',
    'Brainstorm/Advisor/player_journal.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'},changed
changed_tests={rel for rel,h in f['test_files'].items()if pre['test_files'].get(rel)!=h}
assert changed_tests=={'tests/advisor_held_floor431.lua'}
for rel,h in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==h
    if rel not in changed|changed_tests:assert file_digest(ROOT/rel)==h,rel
for rel,h in f['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==h
assert file_digest(HERE/'SCOPE.md')==f['scope_sha256']
lua_log=(candidate/'validation/lua.log').read_text()
lua=re.search(r'(\d+)/(\d+) fixtures passed',lua_log);assert lua and lua[1]==lua[2]=='302'
assert 'Held floor431: 387 checks passed' in lua_log
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'))
assert py==458 and len(f['candidate_policy_files'])==110 and len(f['test_files'])==351
# Read/hash public journals only. Existing completed capture remains exact; no
# source save/profile inspection, game control or duplicated capture is needed.
latest=read(EVAL/'development430/LATEST.json');capture=ROOT/latest['capture']
manifest=read(capture/'manifest.json');summary=read(capture/'summary.json');source=Path(manifest['source'])
assert file_digest(capture/'summary.json')==latest['summary_sha256']
assert file_digest(capture/'events.sqlite3')==summary['database_sha256']
source_files=sorted(source.glob(manifest['session']+'-*.brj'))
assert {p.name for p in source_files}=={x['name']for x in manifest['segments']}
for segment in manifest['segments']:
    assert file_digest(capture/'logs'/segment['name'])==segment['sha256']
    assert file_digest(source/segment['name'])==segment['sha256'],'New journal bytes require fresh preservation'
newest=sorted(source.glob('*.brj'),key=lambda p:p.stat().st_mtime,reverse=True)[0]
assert newest.name.startswith(manifest['session']+'-'),'A newer public session requires inspection'
# Analyze only existing JSON results from the closed evaluation; execute no policy.
pairs=read(EVAL/'development429/DECISION_PAIRS.json')
unchanged=[p for p in pairs if p['group']in ('old_unused','current_reported')and
    not p['action_changed']and p['candidate']['action'].get('kind')=='play']
reasons=Counter((p['candidate'].get('discard_before_clear')or{}).get('reason')for p in unchanged)
assert len(unchanged)==55 and reasons['Replacement draws can reduce or reorder the reserved score.']==14
assert read(EVAL/'development429/CLOSED.json')['remaining_authority']==0
save(HERE/'PASSIVE_REASONS.json',{'source':'development429/DECISION_PAIRS.json',
    'source_sha256':file_digest(EVAL/'development429/DECISION_PAIRS.json'),
    'unchanged_play_states':len(unchanged),'reason_counts':dict(reasons),
    'conditional_guard_cases':[p['id']for p in unchanged if(p['candidate'].get('discard_before_clear')or{}).get('reason')=='Replacement draws can reduce or reorder the reserved score.'],
    'policy_executed':False,'all_fourteen_fixed_claim':False})
ps=subprocess.run(['pwsh','-NoProfile','-Command',
    "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
    capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else []
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
assert branch=='codex/exact-search-speedups'
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':431,'version':'2.212.0-alpha',
    'status':'frozen_validated_not_installed','candidate':candidate.relative_to(ROOT).as_posix(),
    'policy_digest':f['candidate_policy_digest'],'policy_files':f['candidate_policy_files'],
    'changed_runtime_vs_installed':f['changed_runtime_files'],'changed_runtime_vs430':sorted(changed),
    'runtime_file_count':110,'test_file_count':351,'test_files':f['test_files'],
    'validation_counts':{'lua_fixtures':302,'python_tests':458},'new_fixture_assertions':387,
    'baseline_guards_reproduced':2,'review_cycle_exhausted':True,'installed_checkpoint':426,
    'installed_version':base['version'],'installed_digest':base['policy_digest'],
    'installed_runtime_unchanged':True,'settings_and_seven_dlls_preserved':True,
    'prior_preserved_hashes':len(pre['prior_files']),'process_check_successful':True,'processes':processes,
    'normal_exit_inferred':False,'confirmation_required':False,'latest_capture':latest,
    'latest_public_sources_match_preserved_capture':True,'latest_outcomes':summary['outcomes'],
    'unended_run_ids':summary['unended_run_ids'],'candidate_loaded_evidence':False,'win_rate_claim':False,
    'captured_policy_replay431':False,'game_control':False,'save_profile_access':False,
    'original_game_execution':False,'automation_created':False,'historical_allowances':'CLOSED','branch':branch}
save(HERE/'FINAL_VERIFICATION.json',record);save(EVAL/'CANDIDATE_CHECKPOINT_431.json',record)
diff=[]
for rel in sorted(changed|changed_tests):
    old=HERE/'before'/rel
    diff.extend(difflib.unified_diff(old.read_text().splitlines(True)if old.exists()else[],
        (ROOT/rel).read_text().splitlines(True),fromfile='before431/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
process_note='Balatro remains running; installation deferred.'if processes else 'Balatro absent; fresh immediate recheck required before installation.'
prefix=f'''FROZEN CANDIDATE431 -2026-09-27
Combined2.212.0-alpha validated:302 Lua/458 Python,110 dependencies/351 frozen tests.
NOT INSTALLED. Installed/user-loaded426/2.209 unchanged. {process_note}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_431.md/.json, NEXT_PRIORITIES_431.md,
ARCHITECTURE_MAP_431.md and development431/REPORT.md, REVIEW.md, PASSIVE_REASONS.json,
FINAL_VERIFICATION.json. Digest {f['candidate_policy_digest']}.
387 new manufactured checks: canonical Raised Fist/Blackboard omission floors,
copies, adverse draws/order, repeated full-five Decision discards before Tarot,
real Yorick/Burnt endpoints, cache isolation, budget and hidden-input safeguards.
Carries428 enhanced-anchor repair and430 Smiley/Supernova Amber Acorn continuity.
Latest public logs still byte-match development430/captures/002 (6wins/2losses/
2unsupported); those outcomes concern loaded2.209, not this candidate.
No all-discards-fixed or win-rate claim. Larger order anchors and uncertain-score
states remain; Acorn conditional-held product intentionally unqualified.
429 and all historical experiments CLOSED.431 sole review exhausted.
Installation: fresh successful absent-process check, latest preserved journals,
explicit backed install_slice, exact-installed freeze/full gate. No confirmation.
No game control, save/profile access, automation or new captured evaluation.
Earlier history follows.

'''
for rel in pre['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    src=ROOT/rel;src.write_text(prefix+src.read_text(encoding='utf-8'),encoding='utf-8')
write(EVAL/'CANDIDATE_CHECKPOINT_431.md',prefix)
write(EVAL/'NEXT_PRIORITIES_431.md',
    '# Priorities431\n\nRelease validated combined2.212 after a fresh successful passive check finds Balatro absent, '
    'preserving any newer public journals, backed explicit-file installation and exact-installed full validation. '
    'No confirmation question. Inspect actual loaded discard/Acorn continuity after user-started play.\n\n'
    'Remaining discard gaps: larger noncommuting anchors, conditional-held rows outside the narrow qualification, '
    'floors below target, boss/visibility constraints and public Acorn product families. '
    'Closed429 identified55 unchanged plays; this repair targets one14-case blocker class without claiming '
    'all14 captured actions change. No captured431 replay was authorized. World/Fool and full-row Blueprint gaps remain. '
    'Keep all historical experiments closed and431 review exhausted.\n')
write(EVAL/'ARCHITECTURE_MAP_431.md',
    '# Architecture431\n\ngrowth.lua conditional_held_floor builds a private inert scoring row for fully qualified '
    'Raised Fist/Blackboard sources. Copy routes/slots/metadata persist; actual transitions and valuation retain the original row. '
    'Singleton probes and retained post-discard scores use the omission floor with existing arithmetic/order certificates and12-call cap. '
    'acorn_discard.retained explicitly refuses this receipt until every public world product is qualified. '
    'player_journal emits compact held_floor proof metadata. tests/advisor_held_floor431.lua covers the seams.\n\n'
    'Combined freeze repair431_candidate1 carries exact430 acorn_belief changes and428 growth work. '
    'Earlier navigation: ARCHITECTURE_MAP_430/428; closed evaluation429 is unchanged.\n')
write(HERE/'REPORT.md',f'''# Repair431: conditional held-score discard gap

Frozen combined2.212 (`{f['candidate_policy_digest']}`) passed302 Lua fixtures and
458 Python tests.387 new manufactured assertions pass. {process_note}
Installed2.209 remains unchanged.110 runtime dependencies and351 frozen test files
match the full gate; settings, seven DLLs and{len(pre['prior_files'])} prior hashes
are preserved. No loaded2.212 evidence exists.

## Supported cause and repair

Passive analysis of closed429 finds55 unchanged plays in unused-discard groups.
14 were rejected by the Raised Fist/Blackboard replacement-draw guard. This guard
was appropriately cautious about disappearing bonuses but also blocked states
that could clear without those bonuses. The new private score projection omits
every qualified source and its copied contributions. It preserves row position,
compatibility, editions, value and all other metadata, and checks the real updated
post-discard state. A retained clear must still reach target without a favorable
draw. No Joker is actually changed or sold. Actual Yorick/Burnt growth and public
population/inventory/resource protections remain intact.

Fixtures reproduce both old guards with exact430, exercise copied and disabled
routes, both conditionals together, Steel/Red/Glass/editions, every5-of6 replacement
in a manufactured public population, held/scoring order, cache isolation, actual
Yorick threshold/Burnt level endpoints, and three successive five-card discards
before optional Hierophant for each Joker. Bonus-dependent clears, modified or
hidden inputs, paid discards, unsupported blinds and incomplete budgets reject.
The same12-call allowance holds. Review found and repaired one visibility gap;
see REVIEW.md and preserved raw logs. The complete Acorn held-floor product stays
explicitly unsupported rather than reintroducing the bonus in later worlds.

## Amber Acorn and evidence limits

The unchanged430 repair remains included: missing public ability continuity for
Smiley Face and Supernova caused both session unsupported retirements. See
development430/TRACE.json and REPORT.md. Neither retirement proves a loss or a
counterfactual win. The latest original public journals still exactly match
development430/captures/002:30,608 verified events,6wins/2losses/2unsupported, no
unended run IDs. Balatro process state is recorded independently of those outcomes.

This slice is not a complete solution to unused discards. Larger order-sensitive
anchors, unqualified rows, uncertain floors and special boss/world constraints
remain. No431 captured-policy replay, future-draw simulation or loaded-game
win-rate comparison was performed. Closed429's modest1.167->1.333 modeled
discards/round belongs to the earlier2.209/2.210 comparison, not2.212. All historical
experiment allowances remain closed. Next: release when safely absent and obtain
actual user-loaded behavior; do not claim a50% or other population win rate.
''')
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:record[k]for k in ('version','policy_digest','validation_counts','new_fixture_assertions','prior_preserved_hashes','processes')},indent=2))
