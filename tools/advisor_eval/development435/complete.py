"""Close navigation and verify preservation; no evaluation or installation."""
from pathlib import Path
import json,subprocess,sys
from run import HERE,read,save,sha,now,verify,sources
EVAL=HERE.parent;ROOT=EVAL.parents[1];sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from validate_checkpoint import test_manifest
m=verify();sources(m);pre=read(HERE/'prework.json');closed=read(HERE/'CLOSED.json')
assert closed['remaining_authority']==0 and closed['jobs']==53
for rel,h in pre['prior_files'].items():assert sha(ROOT/rel)==h,rel
assert policy_hashes(ROOT)==pre['runtime_files']
installed=Path(pre['installed']);assert policy_hashes(installed.parent)==pre['runtime_files']
assert test_manifest()==pre['test_files']
assert sha(installed/'config.lua')==pre['config_sha256']
assert {p.name:sha(p)for p in installed.glob('*.dll')}==pre['native_files']
for rel,h in pre['before_files'].items():assert sha(HERE/'before'/rel)==h,rel
jobs=read(HERE/'jobs.json')
for key in jobs:
 assert (HERE/'ledger'/f'{key}.started.json').is_file()and(HERE/'ledger'/f'{key}.worker.json').is_file()
 r=read(HERE/'results'/f'{key}.json');assert r['job']==key and sha(HERE/'results'/f'{key}.log')==r['log_sha256']
assert len(list((HERE/'results').glob('*.json')))==53
header='''CLOSED TARGETED EXPERIMENT435 —2026-09-28
Read tools/advisor_eval/SESSION_RESET_435.md/.json, NEXT_PRIORITIES_435.md,
ARCHITECTURE_MAP_435.md and development435/REPORT.md, RESULTS.json, DETAILS.json,
CLOSED.json, FINAL_VERIFICATION.json. Four workers;53 one-use jobs;41.83sec elapsed.
48 continuations:31 modeled clears,10 failures,7 unsupported;20/24 paired endings.
Sly/Trio Goad:8/8 versus7/8. Three completed hand cases: forcing initial5 increases
cards/discard3.375->4.000, but both clear8/12; four gains/four losses. No population
win-rate claim. Owned-Lucky Violet case unresolved; pack diagnostic export failed.
103 manufactured Lua assertions/6 Python controls passed; focused review exhausted.
Installed434/2.214 and production tests/settings/seven DLLs unchanged. No runtime
edit/install, game control, save/profile access, original-game execution or automation.
Newer public journals exist and remain untouched; live process observed passively.
All435 unused capacity permanently CLOSED; no retries/resumption/new experiment.
Earlier installation/release/preservation requirements and records remain below.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;old=p.read_bytes();assert old==(HERE/'before'/rel).read_bytes(),rel
 p.write_bytes(header.encode('utf-8')+old)
record={'at':now(),'revision':435,'scope':'closed targeted offline experiment','installed_revision':434,
 'installed_version':'2.214.0-alpha','installed_policy_digest':m['policy_digest'],'runtime_unchanged':True,
 'report':'development435/REPORT.md','results':'development435/RESULTS.json','details':'development435/DETAILS.json',
 'closed':closed,'remaining_authority':0,'population_win_rate_established':False,'review_exhausted':True}
save(EVAL/'SESSION_RESET_435.json',record)
texts={
 'SESSION_RESET_435.md':'''# Closed435; installed434 unchanged

The authorized four-worker targeted pilot is complete and permanently CLOSED.
Read development435/REPORT.md, RESULTS.json, DETAILS.json, CLOSED.json and
FINAL_VERIFICATION.json.53 jobs started once;41.83sec elapsed/158.78 summed child
wall-seconds; no timeouts/retries.48 continuations produce31 modeled clears,
10 failures,7 unsupported;20 of24 pairs have both endings. One pack diagnostic
failed its export; four admission diagnostics succeeded.

Sly clears8/8 versusTrio7/8 in the Goad pack case. Across three complete hand
cases, forcing the first five raises cards/discard3.375->4.000 but both branches
clear8/12; four worlds improve and four worsen. All41 terminal continuations
spend their remaining discards. Selected states are not population win evidence.
Violet's owned-Lucky stochastic transitions remain unresolved. No full-run or
future shop/reward effects are modeled. See report for resource tradeoffs.

103 manufactured Lua assertions and6 Python controls passed before the frozen
manifest. Existing review is exhausted. Runtime434/2.214,310Lua/458Python release
evidence,110 dependencies/360 tests, config and seven DLLs remain unchanged.
No install, game control, saves/profiles, original game execution or automation.
Newer public journals exist; their run completion was not inferred. No further
experimental capacity remains. Preserve all history and installed434 boundaries.
''',
 'NEXT_PRIORITIES_435.md':'''# Priorities after closed435

Use the paired counterexamples in development435/DETAILS.json and action traces
to design a bounded survival-versus-Yorick-threshold comparison. A blanket first
five loses real modeled clear paths as well as gaining others; an extra first
card does not guarantee greater total later growth. Early Sly/Trio results justify
investigating immediate-survival protection, not globally overriding Joker values.

Before a future captured pilot: qualify owned-Lucky stochastic transitions with
owned Joker effects; export bounded finishing distributions without duplicated
snapshots; retain structured unsupported warnings instead of Lua table addresses.
The failed435 export is preserved and must not be rerun under its closed budget.
Multi-round questions additionally need qualified rewards, Perkeo/stickers and
future shops. No broader simulator or population win rate is established.

Installed434/2.214 remains unchanged; newer user-started public journals were
observed but not analyzed here. Future runtime repairs require exact combined
candidate/installed gates.435 is delivered, review exhausted, budget permanently
closed; no automatic next experiment, monitoring or runtime change.
''',
 'ARCHITECTURE_MAP_435.md':'''# Detached experiment435

development435/prepare.py passively preserves prior work, copies exact434's110
dependencies and extracts five fixed public snapshots. Current runtime wiring
excludes execution/opening/retry/popup hooks; no game callbacks are loaded.
adapter.lua canonicalizes public composition before Decision while keeping each
world's private draw permutation external. It supports only canonical free
Sly/Trio next-Goad startup and qualified hand transitions. First-action alternatives
come from one complete public candidate comparison and are hash/fingerprint bound.

run.py launches four isolated below-normal workers, diagnostic stage then paired
continuations with alternating branch order. Both pair caps are reserved before
starting. Each job has exclusive parent/worker claims and15sec timeout,16actions,
53jobs/795reserved child-seconds/900elapsed maximum. No retries or resumption.
manifest/READY precede all captured evaluations; CLOSED closes all unused capacity.

test_adapter.lua and test_runner.py use manufactured fixtures/structural controls.
analyze.py and detail_results.py only read emitted outputs. All original results
remain immutable, including the failed oversize pack export and7 censored Lucky
branches. Missing final resources are distinguished from supported prefixes;
round rewards and long-horizon outcomes are excluded. See434 map for runtime.
'''}
for name,txt in texts.items():
 with(EVAL/name).open('x',encoding='utf-8')as f:f.write(txt)
for rel in pre['navigation']:
 current=(ROOT/rel).read_bytes();old=(HERE/'before'/rel).read_bytes()
 assert current==old or current.endswith(old),rel
preservation={'at':now(),'runtime_and_installed_unchanged':True,'policy_digest':m['policy_digest'],
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'production_test_files_unchanged':len(pre['test_files']),'config_preserved':True,'native_files_preserved':len(pre['native_files']),
 'frozen_inputs_unchanged':True,'captured_source_unchanged':True,'all_53_claims_results_logs_verified':True,
 'navigation_histories_preserved':True,'remaining_experiment_authority':0,
 'no_game_control':True,'no_runtime_edit_or_install':True,
 'artifact_files':{str(p.relative_to(ROOT)):sha(p)for p in HERE.rglob('*')if p.is_file()and 'before'not in p.relative_to(HERE).parts}}
save(HERE/'FINAL_VERIFICATION.json',preservation)
with(HERE/'git_status_after.txt').open('x',encoding='utf-8')as f:
 f.write(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:v for k,v in preservation.items()if k!='artifact_files'}))
