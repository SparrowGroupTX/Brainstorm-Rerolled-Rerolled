"""Seal the qualified Acorn candidate and preserve the active installed baseline."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, json, re, subprocess, sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance
def read(p):return json.loads(p.read_text())
def save(p,x):
    with p.open('x',encoding='utf-8') as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(x)
P=read(H/'prework.json');B=P['installed'];C=E/'runs/repair445_candidate1'
F=read(C/'freeze.json');G=read(C/'validation/report.json');installed=Path(B['installed'])
assert all(G[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert policy_hashes(installed.parent)==B['policy_files']
assert test_manifest()==F['test_files']==G['test_files']
assert provenance()==F['validation_provenance']==G['validation_provenance']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in (R/'Brainstorm',installed):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for rel,digest in P['prior_files'].items():
    source=R/rel
    if rel=='tools/advisor_eval/DECISION_REVIEW.md':
        assert P['before_files'][rel]==digest
        source=H/'before'/rel
    assert file_digest(source)==digest,rel
for rel,digest in P['before_files'].items():assert file_digest(H/'before'/rel)==digest,rel
for rel,digest in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==digest
for rel,digest in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==digest
match=re.search(r'(\d+)/(\d+) fixtures passed',(C/'validation/lua.log').read_text())
assert match and match[1]==match[2]=='323'
py=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'))
assert py==494
capture=H/'log_copy/captures/001';summary=read(capture/'summary.json');manifest=read(capture/'manifest.json')
assert not summary['errors'] and file_digest(capture/'events.sqlite3')==summary['database_sha256']
for segment in manifest['segments']:
    assert segment['source_prefix_still_matched']
    assert file_digest(capture/'logs'/segment['name'])==segment['sha256']
ps=subprocess.run(['pwsh','-NoProfile','-Command',
    '@(Get-Process -ErrorAction Stop | Where-Object {$_.ProcessName -ieq "Balatro"} | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
    capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else []
stamp=datetime.now(timezone.utc).isoformat()
checkpoint={'created_utc':stamp,'revision':445,'candidate_version':'2.220.0-alpha',
    'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
    'candidate_freeze':C.relative_to(R).as_posix()+'/freeze.json','full_candidate_gate_passed':True,
    'lua_fixtures':323,'python_tests':494,'runtime_file_count':110,'test_file_count':376,
    'changed_runtime_files':F['changed_from_installed444'],'installed_release':444,'installed_version':'2.219.0-alpha',
    'installed_unchanged':True,'installation_performed':False,'passive_processes':processes,
    'installation_status':'Deferred while Balatro is running'if processes else 'Candidate ready; deployment not performed',
    'config_preserved':True,'native_files_preserved':7,'prior_files_preserved':len(P['prior_files']),
    'mutable_prior_document_preserved_at':'development445/before/tools/advisor_eval/DECISION_REVIEW.md',
    'loaded_2219_prefix':{'capture':capture.relative_to(R).as_posix(),'events':summary['events'],
       'versions':summary['versions'],'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
       'archive_errors':summary['errors'],'complete_marathon':False},
    'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED',
    'review_exhausted':True,'all_discard_cases_fixed':False,'loaded_2220_efficacy':'No evidence'}
save(E/'CANDIDATE_CHECKPOINT_445.json',checkpoint);save(E/'SESSION_RESET_445.json',checkpoint)
candidate=f'''# Candidate 445 / 2.220.0-alpha

The exact combined candidate passes **323 Lua fixtures and 494 Python tests**.
110 runtime dependencies and 376 frozen test files; digest `{F['candidate_policy_digest']}`.
Four runtime files differ from installed 444 / 2.219: public Acorn belief,
Acorn ordering and the two version stamps. See development445/REPORT.md,
TRACE2.json, REVIEW.md and FINAL_VERIFICATION.json for bounded evidence.

Repairs: legal 13-card public hands within existing budgets; canonical Bootstraps
and Turtle Bean continuity across completed play/discard; malformed selection
limits and all supported hidden-card aliases rejected before scoring. The
64-action shortlist is explicitly limited, and every retained world is compared.
No gameplay score caps or resource safeguards were raised or removed.

**Not installed.** Installed 2.219 remains exact, with settings and seven DLLs
unchanged. Current passive process result: `{processes}`.
Latest copied active 2.219 prefix has 6,466 events, two endings (one win/one loss)
and one unfinished run; it is not the completed marathon. Original public logs
remain untouched. There is no loaded 2.220 or rescued-game/win-rate evidence.

Installation follows INSTALLATION_POLICY.md: preserve the newest public logs,
check fresh passive absence, verify this exact candidate/provenance, perform
explicit backed install_slice, then freeze and fully validate installed bytes.
No normal-exit confirmation is needed. All previous experiments remain CLOSED.
'''
write(E/'CANDIDATE_CHECKPOINT_445.md',candidate)
write(E/'SESSION_RESET_445.md','''# Resume 445

Read CANDIDATE_CHECKPOINT_445.md/.json, development445/REPORT.md, TRACE2.json,
REVIEW.md and FINAL_VERIFICATION.json. Candidate 2.220 passed its exact full gate;
installed 444 / 2.219 is unchanged. The active-session prefix in
development445/log_copy/captures/001 confirms loaded 2.219 at its cutoff, with one
unfinished run; do not infer later completion or normal exit.

This delivery repairs two demonstrated Acorn retirement mechanisms using
manufactured controls. No captured snapshot was sent through a policy or scorer.
No game control, saves/profiles, original-source execution or reopened experiment.
Review 445 is exhausted. Preserve every prior artifact, tracked/untracked work,
settings and all DLLs. Fresh absent-process installation follows
INSTALLATION_POLICY.md, including newest-log backup and exact installed gate.
''')
write(E/'NEXT_PRIORITIES_445.md','''# Priorities 445

1. When Balatro is closed, preserve the latest public session and install the
   exact qualified 2.220 candidate using the existing backed release procedure.
   Reuse the full candidate gate only while runtime/tests/helper provenance match.
   Freeze and fully validate installed bytes; do not deploy during active play.
2. On a later user-started loaded session, check whether either repaired Acorn
   rejection recurs. An absence of exposure is not successful validation.
3. Use review443's packets to adjudicate short/unused discards by reason family.
   Demonstrate legal score/resource alternatives; counts alone are not mistakes.
   In particular the four-discard target and Acorn13-card discard planning remain
   unproven. Do not mistake immediate-play availability for discard optimization.
4. Improve settlement coverage and independently qualified alternative witnesses
   before interpreting the screener as a whole-strategy optimizer.

No experiment authorization is created here. All past budgets remain closed.
Stop after the current delivery; a new runtime slice needs prospective scope,
meaningful manufactured acceptance and its own exact combined qualification.
''')
write(E/'ARCHITECTURE_MAP_445.md','''# Public Acorn continuity 445

acorn_belief stable_opaque_ability now qualifies exact Bootstraps/Bean coefficients
through checked_opaque_keys both before scoring and before public advancement.
No new popup signatures exist. Completed play/discard retain the coefficients;
fresh public state supplies Bootstraps dollars. Bean round decay stays outside
this within-round transition. Tracker completion, epoch, population and visibility
rules are unchanged. Unknown/modified forms fail closed, including debuffed rows.

acorn_ordering admits at most13 visible cards and a finite integer selection
limit1..5. All six concealed/redaction flags refuse before scoring. At13 cards,
there are2379 unconstrained subsets. Complete families that fit the ordinary
allowance remain exhaustive; otherwise the existing <=64 visible-action shortlist
is compared across every retained world. Ordering/score caps remain30000/140000.
Incomplete profiles produce no action. Broader Acorn discard planning is unchanged.

tests/advisor_acorn_continuity445.lua combines manufactured independent arithmetic,
finite-family/world accounting and current scorer/Decision/tracker integration.
development445/baseline.lua reproduces the old failures using preserved old
modules. No captured policy execution is involved. TRACE2.json records raw
observations/action/retirement anchors; it makes no counterfactual outcome claim.

Runtime digest and all dependencies/tests/provenance are in repair445_candidate1.
Installed baseline remains444/2.219. Offline review architecture and limitations
remain documented in DECISION_REVIEW.md and ARCHITECTURE_MAP_443.md.
''')
diff=[]
for rel in F['changed_from_installed444']+['tools/advisor_eval/DECISION_REVIEW.md']:
    diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(R/rel).read_text().splitlines(True),
        fromfile='before/'+rel,tofile='current/'+rel))
write(H/'final_changes.diff',''.join(diff))
prefix=f'''VALIDATED CANDIDATE445 /2.220.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_445.md/.json, SESSION_RESET_445.md/.json,
NEXT_PRIORITIES_445.md, ARCHITECTURE_MAP_445.md and development445/REPORT.md,
TRACE2.json, REVIEW.md, FINAL_VERIFICATION.json.323Lua/494Python;110runtime/376tests.
Digest {F['candidate_policy_digest']}.
Fixes public13-card Acorn input and canonical Bootstraps/Bean continuity; existing
caps/complete worlds/privacy preserved. NOT INSTALLED:444/2.219 remains exact.
Loaded2.219 prefix preserved at development445/log_copy/captures/001:6466events,
one win/one loss/one unfinished run; no completed-marathon or win-rate inference.
No captured executions/game control or reopened budgets;445review exhausted.
Installation follows INSTALLATION_POLICY.md after fresh passive absence and
newest public-log preservation. Earlier status below is preserved history.

'''
nav={}
for rel in P['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    path=R/rel;old=path.read_bytes();assert file_digest(path)==P['before_files'][rel]
    path.write_bytes(prefix.encode('utf-8')+old);assert path.read_bytes().endswith(old)
    nav[rel]=file_digest(path)
paths=[E/'CANDIDATE_CHECKPOINT_445.json',E/'CANDIDATE_CHECKPOINT_445.md',E/'SESSION_RESET_445.json',
    E/'SESSION_RESET_445.md',E/'NEXT_PRIORITIES_445.md',E/'ARCHITECTURE_MAP_445.md',
    H/'TRACE2.json',H/'REPORT.md',H/'REVIEW.md',H/'target5.log',H/'final_changes.diff',
    C/'freeze.json',C/'validation/report.json',capture/'manifest.json',capture/'summary.json']
save(H/'FINAL_VERIFICATION.json',{'verified_utc':stamp,**checkpoint,'navigation_hashes':nav,
    'before_files_preserved':len(P['before_files']),
    'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
print(json.dumps({k:checkpoint[k]for k in ('candidate_version','lua_fixtures','python_tests','installed_version',
    'installation_status','passive_processes','candidate_policy_digest','prior_files_preserved')}))
