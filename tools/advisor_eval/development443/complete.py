"""Seal tooling delivery and passive backup; preserve the blocked runtime candidate."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,subprocess,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,t):
 with p.open('x',encoding='utf-8')as f:f.write(t)
V=H/sys.argv[1];Q=H/sys.argv[2];P=read(H/'prework.json');F=read(V/'freeze.json');G=read(V/'report.json');B=P['installed']
assert G['passed']and G['exact_inputs_unchanged']
assert policy_hashes(R)==P['runtime_files']==F['runtime_unchanged']
assert test_manifest()==F['tests']and provenance()==F['provenance']
for rel,hash_ in F['tool_files'].items():assert file_digest(R/rel)==file_digest(V/'sources'/rel)==hash_,rel
for rel,hash_ in F['tests'].items():assert file_digest(V/'sources'/rel)==hash_,rel
for rel,hash_ in P['prior_files'].items():assert file_digest(R/rel)==hash_,rel
for rel,hash_ in P['before_files'].items():assert file_digest(H/'before'/rel)==hash_,rel
installed=Path(B['installed']);assert policy_hashes(installed.parent)==B['policy_files']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in(R/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
q=read(Q/'report.json');done=read(Q/'COMPLETE.json')
for rel,hash_ in done['files'].items():assert file_digest(Q/rel)==hash_,rel
for name,hash_ in q['tool_hashes'].items():assert file_digest(E/name)==hash_,name
capture=H/'log_copy/captures/001';backup=read(H/'log_copy/VERIFIED.json');manifest=read(capture/'manifest.json')
assert q['manifest_sha256']==file_digest(capture/'manifest.json')
for item in manifest['segments']:
 p=capture/'logs'/item['name'];assert file_digest(p)==item['sha256']and p.stat().st_size==item['bytes']
assert file_digest(capture/'events.sqlite3')==read(capture/'summary.json')['database_sha256']
assert 'Focused recheck complete' in(H/'REVIEW.md').read_text()
counts=[int(re.search(r'Ran (\d+) tests',(V/f'python{i}.log').read_text())[1])for i in range(3)]
process=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(process.stdout)if process.stdout.strip()else[]
now=datetime.now(timezone.utc).isoformat()
receipt={'created_utc':now,'revision':443,'kind':'offline_tooling_and_public_log_backup','tooling_validated':True,'validation':str(V.relative_to(R)),'python_tests':sum(counts),'tool_files':F['tool_files'],'current_runtime_candidate':'442/2.219.0-alpha','runtime_candidate_unchanged':True,'runtime_candidate_release_ready':False,'runtime_candidate_blocker':'Full Lua regression60-second timeout remains unresolved. Tooling validation does not qualify runtime.','installed_release':440,'installed_version':B['version'],'installed_unchanged':True,'installation_performed':False,'config_preserved':True,'native_files_preserved':7,'prior_artifacts_preserved':len(P['prior_files']),'backup':backup,'review_report':str(Q.relative_to(R)),'coverage':q['coverage'],'structural_subsets':q['subset_candidates_enumerated'],'captured_policy_or_scorer_executed':False,'new_experiment':False,'all_historical_experiments':'CLOSED','review_exhausted':True,'game_control':False,'save_profile_access':False,'normal_exit_inferred':False,'passive_processes':processes}
save(E/'TOOLING_CHECKPOINT_443.json',receipt);save(E/'SESSION_RESET_443.json',receipt)
c=q['coverage']
report=f'''#443: offline evidence and alternatives system

Delivered review_decisions.py, an optional detached observer in the existing
verified journal screener, manufactured controls, and DECISION_REVIEW.md.
Exact tooling validation passes{sum(counts)} Python tests. No Lua runtime edits,
captured policy/scorer execution, simulated worlds, original-source execution,
save/profile access or game control. This is an offline tool, not an automatic
gameplay patch. Existing2.219 remains unqualified and uninstalled;2.218 stays exact.

Two hash-verified archive passes allow an exact deterministic bottom-k sample of
eligible decisions with NO legacy rule hit, including hits omitted by output caps
or confirmed later. Observers get detached evidence once per request. A late input
or tool-source integrity failure prevents a trusted report. Reports bind the source
manifest, tool hashes and outputs; COMPLETE.json is required for trusted output.

Packets separate receipt inconsistency, recorded-alternative signal and hypothesis
from severity. Each has public observation/advice/request/effect anchors, chosen
action, recorded exceptions, first unresolved evidence stage, candidate proposals,
competing explanations and a specific next test. A receipt contradiction is a
recording/pipeline inconsistency, never automatic proof of strategic regret.
Recorded reason groups cover all eligible findings, with explicit caps, examples
and counts; they do not assert a common root cause. An editable adjudication ledger
requires a falsifier, independent expectation, controls, holdouts and loaded follow-up.

The discard solver exhaustively enumerates public STRUCTURAL selections when IDs,
forced-card constraints and limits are known and combination budgets permit it.
It computes maximum batch size while retaining the actual chosen-play cards, and
puts such proposals first for review. It annotates enhancements, seals and Death
source concerns without pruning them. Unknown redacted forced constraints, oversized
hands and exhausted enumeration budgets fail closed. Retaining cards is not a
winning-score proof: sorting, held effects, future draws and resource costs remain
unverified. It never calls a game-optimal or safe alternative from this evidence.

Limits:128packets/32samples,256retained legacy flags,32contradiction examples,
128reason groups,12held cards,2048subsets/packet,32768/report,64MiB outputs.
Coverage remains limited to existing supported settlement joins: non-clearing
plays, consumable actions, pack openings and other unqualified classes are explicit
blind spots. These are next capabilities, not silently counted successful checks.

Latest user's marathon copied and verified in log_copy/captures/001:
25segments/63539429bytes/25523events,10starts/10endings,4wins/4losses/2unsupported,
no archive errors or unended runs. Loaded version2.218. Both unsupported outcomes
record Public Joker advice unavailable, with Amber Acorn-related context; causal
repair remains unresolved. These are observed cohort counts, not a stable win-rate.
Backup completed and installation blocker reported immediately before resuming work.

Final smoke report:{Q.relative_to(R).as_posix()}.
{c['eligible_settled_decisions']} eligible settled decisions;
{c['legacy_flagged_decisions']} legacy-flagged/{c['legacy_unflagged_population']} unflagged;
{c['packets_retained']} packets including{c['sample_retained']} unflagged samples;
{q['subset_candidates_enumerated']} structural subsets. Legacy rule counts:
{json.dumps(c['raw_rule_hits'])}. New receipt findings:
{json.dumps(c['all_eligible_finding_counts'])}.
{c['legacy_flagged_decisions_without_packet']} flagged decisions omitted by packet
capacity; full counts/reason groups retained. No machine-checkable receipt
contradiction in this supplied cohort does NOT establish correct strategy.

Preliminary reports under copied_review1 and latest_review predate the focused
review's consumable-sale settlement correction. Their eligibility/sample counts
are superseded and must not be used as final coverage evidence. The corrected
observer accepts Joker sales only; unmodified or removed consumable inventory
cannot masquerade as that settled effect. All preliminary smoke/freeze/failure
logs remain intact. Do not pool releases or call flag-count changes causal gains.

All{len(P['prior_files'])} prior artifact hashes, before copies, pending runtime,
installed runtime, settings and7DLLs verify unchanged. New tests/tool provenance
means any future runtime release needs a new exact combined validation context;
the old candidate freeze is preserved historical evidence, not a current full pass.
Review443 is exhausted. No experiment allowance was consumed or reopened.
'''
write(H/'REPORT.md',report);write(E/'TOOLING_CHECKPOINT_443.md',report)
write(E/'SESSION_RESET_443.md','''# Resume443

Read TOOLING_CHECKPOINT_443.md/.json and development443/REPORT.md, REVIEW.md,
FINAL_VERIFICATION.json. Use DECISION_REVIEW.md for the offline tool. Latest
marathon is safely preserved under development443/log_copy/captures/001;10ends,
4wins/4losses/2unsupported, loaded2.218, no archive errors. Runtime remains
installed440/2.218; candidate442/2.219 unchanged but NOT release-ready due to
full Lua timeout. User asked installation; blocker was reported, no install done.
Keep installation policy and all preservation boundaries. Do not rerun or renew
closed experiments.443 was tooling-only; no captured scoring/simulation. Review
allocation exhausted. Future runtime release needs exact current dependencies,
tests and helper provenance, not just equal runtime bytes. Preserve all reports.
''')
write(E/'NEXT_PRIORITIES_443.md','''# Priorities443

1. Resolve the frozen2.219 full Lua timing blocker using a concrete bounded timing
   diagnosis, preserve safeguards, then exact full qualification before installation.
2. Adjudicate representative latest-review packets and recorded reason groups;
   require a demonstrated alternative, not a proxy count. Preserve unsupported
   and omitted cases. Use the adjudication ledger for falsifiers and controls.
3. Trace the latest two Public Joker advice unavailable retirements through public
   Acorn belief/advice/settlement. They are unsupported outcomes, not terminal losses.
4. Add independently qualified score/resource witnesses and bounded alternative
   continuation comparisons. Current enumeration proves only selection feasibility.
5. Expand settlement coverage for non-clearing plays and consumable/pack actions
   with manufactured attribution controls before claiming broader blind-spot coverage.

No new experiment or second repair slice is automatically authorized by this list.
No request to control the game or read saves. Source archives remain immutable.
''')
write(E/'ARCHITECTURE_MAP_443.md','''# Offline decision review443

flag_suspect_decisions.analyze verifies copied BRJ2 hashes/links. Optional on_flag
sees every rule hit before ranking; on_settled gets detached evidence once per
request, under the existing restricted settlement recognizer. snapshot_view keeps
a separate physical-selection projection; unknown concealed constraints stay unknown.

review_decisions uses two verified passes: all rule-hit identities and bounded
receipt inconsistency examples first, exact legacy-unflagged bottom-k second.
Packet selection reserves blind-spot samples, prioritizes receipt inconsistencies
then heuristic priority. Reason groups count across all eligible settlements.
discard_alternatives enumerates complete structural subsets under precomputed caps;
physical chosen-play retention orders proposals but does not certify score/survival.
recorded_alternatives binds pack rows to visible IDs/keys without treating merit as
dominance. issues distinguishes internal receipt contradictions from qualitative
signals. Stage labels locate evidence gaps, not proven causes. Tool hashes are
checked before/after analysis; COMPLETE.json binds successfully published files.

Artifacts: report.json, REPORT.md, adjudication.json, challenge_queue.json.
CLI is documented in DECISION_REVIEW.md. Runtime modules remain unchanged; all
simulated/captured-policy experiment leases stay closed. The pending442 runtime
still needs a passing exact full gate before any installation.
''')
prefix=f'''OFFLINE TOOLING443 /LATEST MARATHON PRESERVED —{now[:10]}
Read tools/advisor_eval/TOOLING_CHECKPOINT_443.md/.json, SESSION_RESET_443.md/.json,
NEXT_PRIORITIES_443.md, ARCHITECTURE_MAP_443.md, DECISION_REVIEW.md and
development443/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json.
{sum(counts)}Python tests pass; no runtime change or installation. Installed440/2.218
unchanged; candidate442/2.219 remains BLOCKED by full Lua60s timeout.
Latest copied session: development443/log_copy/captures/001,25523events,
10endings:4wins/4losses/2unsupported, loaded2.218; no archive errors/unended runs.
Offline tool yields evidence packets, bounded structural discard alternatives,
reason groups and independent unflagged samples; no optimal-strategy/win claim.
No captured scoring/simulation or reopened budgets.443 review exhausted.
Existing runtime freeze/provenance histories preserved; future release needs
current exact qualification. Earlier records below remain historical.

'''
for rel in P['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=R/rel;assert file_digest(p)==P['before_files'][rel],rel
 old=p.read_bytes();p.write_bytes(prefix.encode()+old);assert p.read_bytes().endswith(old)
paths=[H/n for n in('REPORT.md','REVIEW.md','SCOPE.md')]+[V/'freeze.json',V/'report.json',Q/'COMPLETE.json',H/'log_copy/VERIFIED.json',E/'DECISION_REVIEW.md']
receipt['artifact_hashes']={p.relative_to(R).as_posix():file_digest(p)for p in paths}
save(H/'FINAL_VERIFICATION.json',receipt)
write(H/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=R,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:receipt[k]for k in('tooling_validated','python_tests','runtime_candidate_unchanged','installed_unchanged','installation_performed','prior_artifacts_preserved')}))
