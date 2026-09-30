"""Seal the qualified candidate and current live prefix; never deploy or control."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,re,difflib,subprocess
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes,digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,v):
    with p.open('x',encoding='utf-8')as f:json.dump(v,f,indent=2,allow_nan=False);f.write('\n')
def write(p,v):
    with p.open('x',encoding='utf-8')as f:f.write(v)
def processes():
    r=subprocess.run(['pwsh','-NoProfile','-Command',
        "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
        capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
    return json.loads(r.stdout)if r.stdout.strip()else[]
P=read(H/'prework.json');B=P['installed'];C=E/'runs/repair451_candidate1'
F=read(C/'freeze.json');G=read(C/'validation/report.json')
assert all(G[k]for k in('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert digest(F['candidate_policy_files'])==F['candidate_policy_digest']==G['policy_digest']
assert test_manifest()==F['test_files']==G['test_files']
assert provenance()==F['validation_provenance']==G['validation_provenance']==P['provenance']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
for rel,h in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==h,rel
for rel,h in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==h,rel
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
assert file_digest(Path(B['installed'])/'config.lua')==P['config_sha256']
for root in(R/'Brainstorm',Path(B['installed'])):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
lua=(C/'validation/lua.log').read_text(encoding='utf-8')
assert re.search(r'330/330 fixtures passed',lua)
python_tests=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'))
assert python_tests==494 and len(F['test_files'])==383 and len(F['candidate_policy_files'])==110
assert '307 manufactured assertions passed'in(H/'target4.log').read_text()
assert 'Baseline451: 3 checks'in(H/'baseline_final.log').read_text()
L=read(H/'LATEST.json');capture=R/L['capture'];S=read(capture/'summary.json');M=read(capture/'manifest.json')
assert file_digest(capture/'summary.json')==L['summary_sha256']
assert file_digest(capture/'events.sqlite3')==S['database_sha256']
for row in M['segments']:assert file_digest(capture/'logs'/row['name'])==row['sha256']and row['source_prefix_still_matched']
assert S['events']==7539 and not S['errors']and S['versions']=={'Brainstorm v2.225.0-alpha':6726}
assert S['outcomes']=={'win':2}and len(S['unended_run_ids'])==1
assert M['processes_after']and S['runtime_digest']==B['policy_digest']
stamp=datetime.now(timezone.utc).isoformat();ps=processes()
K={'revision':451,'created_utc':stamp,'version':'2.226.0-alpha','candidate_version':'2.226.0-alpha',
 'candidate':str(C),'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'changed_from_installed450':F['changed_from_installed450'],'full_candidate_gate_passed':True,
 'validation_counts':{'lua_fixtures':330,'python_tests':494},'lua_fixtures':330,'python_tests':494,
 'new_manufactured_assertions':307,'baseline_checks':3,'runtime_files':110,'test_files':383,
 'installed_release':450,'installed_version':'2.225.0-alpha','installed_unchanged':True,'installation_performed':False,
 'candidate1_qualified':True,'review_exhausted':True,'prior_files_preserved':len(P['prior_files']),
 'config_preserved':True,'native_files_preserved':7,'public_capture':L['capture'],'public_capture_mode':'live_prefix',
 'public_events':S['events'],'public_starts':len(S['starts']),'public_endings':len(S['endings']),
 'public_outcomes':S['outcomes'],'public_unended_runs':len(S['unended_run_ids']),'public_archive_errors':S['errors'],
 'public_segments':len(M['segments']),'public_bytes':sum(x['bytes']for x in M['segments']),
 'loaded_version':'2.225.0-alpha','candidate_activation':'Not installed or loaded',
 'all_discard_cases_fixed':False,'passive_processes':ps,'normal_exit_inferred':False,
 'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED'}
for name in('CANDIDATE_CHECKPOINT_451','SESSION_RESET_451'):save(E/(name+'.json'),K)
description=f'''# Candidate451 /2.226.0-alpha

Full exact candidate gate passes330 Lua fixtures/494 Python tests;110 runtime
dependencies/383 frozen test files. Digest `{K['candidate_policy_digest']}`.
Three runtime changes: no-discard two-hand Planet comparison and version markers.
307 new manufactured assertions and3 final archived-baseline checks. Review451
assessment/recheck exhausted, no material blocker. No captured execution or
historical rescue. Four sampled composition worlds are not calibrated win odds.

Installed450/2.225 remains unchanged while the user plays. No installation or
exact-installed451 gate has occurred. Later release requires fresh public-journal
preservation, successful passive process absence and backed install_slice plus
exact-installed full validation under INSTALLATION_POLICY.md. No closure question.

The new mode compares incumbent/greedy hold with one of up to two eligible Planets
then the same incumbent first play; complete final current-order play families,
whole inventory/Negative/Observatory, Perkeo source loss and action costs apply.
Two hands/zero discards/eight held cards;12,000 specialist/140,000 aggregate caps.
General retention/discard policy and earlier remaining-discard mode are unchanged.

Public live prefix safely copied: {K['public_segments']} segments/{K['public_bytes']:,} bytes,
7,539 verified events, {K['public_starts']} starts/two endings, two wins/one unended run,
zero archive errors. Loaded2.225 is confirmed. This is not a complete session;
no future outcome or2.226 effect is inferred. Game running at capture.

Read development451/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json, SCOPE.md,
NEXT_PRIORITIES_451.md and ARCHITECTURE_MAP_451.md. Juggler/Bootstraps admission,
other unused-discard cases and broader multi-action planning remain unresolved.
Historical experiments CLOSED; preserve all tracked/untracked work and stop after
this coherent delivery. No all-fixed, global optimum or population win-rate claim.
'''
write(E/'CANDIDATE_CHECKPOINT_451.md',description)
write(E/'SESSION_RESET_451.md',description+'\nFrozen candidate: runs/repair451_candidate1. Installed checkpoint450 remains authoritative for live files.\n')
diff=[]
for rel in F['changed_from_installed450']:
    diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(R/rel).read_text().splitlines(True),
        fromfile='installed450/'+rel,tofile='candidate451/'+rel))
write(H/'final_changes.diff',''.join(diff))
prefix=f'''CANDIDATE REVISION451 /2.226.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_451.md/.json, SESSION_RESET_451.md/.json,
NEXT_PRIORITIES_451.md, ARCHITECTURE_MAP_451.md and development451/REPORT.md,
REVIEW.md, FINAL_VERIFICATION.json. Full candidate gate330Lua/494Python;
110runtime/383tests. Digest {K['candidate_policy_digest']}.
No-discard two-hand last-Planet comparison; complete paired worlds, actual use,
Negative/Observatory/Perkeo inventory costs and unchanged budgets.307 new checks.
Installed450/2.225 remains unchanged while user plays; loaded2.225 now confirmed.
Current public live prefix copied:7,539events,two wins,one unended run,zeroerrors.
No2.226 installation/activation or historical rescue/win-rate improvement claimed.
Other unused-discard cases remain. Historical experiments/review451 CLOSED.
Fresh preservation/passive absence required before later release; no game control.
Earlier records follow as preserved history.

'''
nav={}
for rel in P['navigation']:
    p=R/rel;assert file_digest(p)==P['before_files'][rel],rel
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    old=p.read_bytes();p.write_bytes(prefix.encode('utf-8')+old)
    assert p.read_bytes().endswith(old);nav[rel]=file_digest(p)
paths=[p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
paths+=[E/(n+ext)for n in('CANDIDATE_CHECKPOINT_451','SESSION_RESET_451')for ext in('.md','.json')]
paths+=[E/'NEXT_PRIORITIES_451.md',E/'ARCHITECTURE_MAP_451.md',C/'freeze.json']
paths+=list((C/'validation').glob('*'))
save(H/'FINAL_VERIFICATION.json',{**K,'navigation_hashes':nav,
    'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
print(json.dumps({k:K[k]for k in('version','candidate_policy_digest','validation_counts','public_starts',
 'public_segments','public_bytes','installed_unchanged','prior_files_preserved','passive_processes')}))
