"""Seal exact qualified candidate and copied public evidence; no installation."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,difflib,subprocess,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,x):
 with p.open('x',encoding='utf-8')as f:f.write(x)
P=read(H/'prework.json');B=P['installed'];C=E/'runs/repair448_candidate1'
F=read(C/'freeze.json');G=read(C/'validation/report.json')
assert all(G[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert test_manifest()==F['test_files']==G['test_files']
assert provenance()==P['provenance']==F['validation_provenance']==G['validation_provenance']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
installed=Path(B['installed']);assert policy_hashes(installed.parent)==B['policy_files']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in(R/'Brainstorm',installed):
 assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
for rel,h in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==h,rel
for rel,h in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==h,rel
match=re.search(r'(\d+)/(\d+) fixtures passed',(C/'validation/lua.log').read_text());assert match and match[1]==match[2]=='327'
py=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'));assert py==494
capture=H/'captures/001';summary=read(capture/'summary.json');manifest=read(capture/'manifest.json')
assert not summary['errors']and file_digest(capture/'events.sqlite3')==summary['database_sha256']
for s in manifest['segments']:assert s['source_prefix_still_matched']and file_digest(capture/'logs'/s['name'])==s['sha256']
for name,h in read(H/'review/COMPLETE.json')['files'].items():assert file_digest(H/'review'/name)==h,name
review=read(H/'REVIEW_STATUS.json');assert review['focused_recheck_complete']and not review['unresolved_blockers']
ps=subprocess.run(['pwsh','-NoProfile','-Command',
 '@(Get-Process -ErrorAction Stop | Where-Object {$_.ProcessName -ieq "Balatro"} | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
 capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=R,capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW).stdout.strip()
assert branch=='codex/exact-search-speedups'
stamp=datetime.now(timezone.utc).isoformat();metrics=read(H/'METRICS.json');screen=read(H/'review/report.json')
checkpoint={'created_utc':stamp,'revision':448,'candidate_version':'2.223.0-alpha',
 'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'candidate_freeze':C.relative_to(R).as_posix()+'/freeze.json','full_candidate_gate_passed':True,
 'lua_fixtures':327,'python_tests':494,'new_manufactured_assertions':136,'baseline_negative_assertions':5,
 'runtime_file_count':110,'test_file_count':380,'changed_runtime_files':F['changed_from_installed446'],
 'installed_release':446,'installed_version':'2.221.0-alpha','installed_unchanged':True,'installation_performed':False,
 'installation_status':'Deferred while Balatro is running'if processes else'Candidate ready; deployment not performed',
 'passive_processes':processes,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(P['prior_files']),'prework_files_preserved':len(P['before_files']),
 'copied_public_prefix':{'capture':capture.relative_to(R).as_posix(),'cutoff_utc':summary['created_utc'],
  'events':summary['events'],'segments':len(summary['segments']),'bytes':sum(s['bytes']for s in summary['segments']),
  'versions':summary['versions'],'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
  'archive_errors':summary['errors'],'complete_marathon':False,'profile':'perkeo_yorick_win_v1'},
 'confirmed_discards':347,'confirmed_cards_discarded':1417,'qualified_clears':116,'unused_discard_clears':15,
 'unused_discards':31,'round_average_cards':metrics['average_cards'],'round_average_denominator':117,
 'by_available_discards':metrics['by_available_discards'],'screen_coverage':screen['coverage'],
 'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED','review_exhausted':True,
 'all_discard_cases_fixed':False,'loaded_2223_efficacy':'No evidence','includes_pending447':True}
save(E/'CANDIDATE_CHECKPOINT_448.json',checkpoint);save(E/'SESSION_RESET_448.json',checkpoint)
write(E/'CANDIDATE_CHECKPOINT_448.md',f'''# Candidate448 / 2.223.0-alpha

Candidate1 passes327 Lua fixtures/494 Python tests;110 runtime dependencies and380
frozen test files. New fixture136 assertions; original-module negative control5.
Digest `{F['candidate_policy_digest']}`.

Fixes a canonical expired Riff-raff blocking all shop comparisons and a supported
sale-to-Brainstorm route. Includes pending447 Astronomer/Photograph retained-discard
coverage. Four files differ from installed446: growth.lua, shop_scoring.lua and
two version stamps. All prior work, settings and seven native DLLs preserved.

NOT INSTALLED. Installed446/2.221 remains exact. Passive processes: `{processes}`.
Current loaded2.221 public prefix safely copied:18,890 events/17segments, four
wins/one loss/one unfinished run, no archive errors. Full trace/metrics/report:
development448/REPORT.md, TRACE.json, METRICS.json, UNUSED_CLEAR_TRACE.json,
ALL_FLAGS.json, REVIEW.md and FINAL_VERIFICATION.json. This is not a full marathon.

Three-discard rounds10.85 cards versus12 target; four-discard rounds16.83 versus16.
Fifteen clears leave31 discards. Idol/order, Castle/hidden floors, Invisible and
early-Yorick copy-value cases remain open. No all-fixed, historical rescue or
population win-rate claim. Historical experiments/review448 are CLOSED. Release
requires INSTALLATION_POLICY.md: fresh passive absence, latest logs preserved,
backed explicit-file deployment and full exact-installed gate. No closure question.
''')
write(E/'SESSION_RESET_448.md','''# Resume448

Read CANDIDATE_CHECKPOINT_448.md/.json, NEXT_PRIORITIES_448.md,
ARCHITECTURE_MAP_448.md and development448/REPORT.md, TRACE.json, METRICS.json,
UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json, REVIEW.md and FINAL_VERIFICATION.json.

2.223 candidate1 is exact and passes327Lua/494Python. Installed446/2.221 unchanged.
447/2.222 remains immutable history and is included in448's combined bytes.
The newest copied prefix is development448/captures/001, session193840Z-1,
18,890events at20:33:08Z: four wins/one loss/one unended sixth run at Ante6 pack.
Loaded2.221/win-first Gold Stake is confirmed; later completion is unknown.

One narrow runtime repair bypasses shop startup refusal for canonical already
debuffed expired Riff-raff only. Physical slot/edition/rent remain and complete
survival/funding comparisons are required. No active generator model was added.
Most current unused discards involve four/five-card Idol sorting proofs, not the
earlier447 families. All15 cases remain documented; do not claim them fixed.

Historical experiment budgets and448 review are exhausted. No game control,
saves/profiles, captured policy/scorer execution, simulation or automation.
Next work requires a prospective coherent scope and exact combined qualification.
Installation follows INSTALLATION_POLICY.md when fresh passive absence and newest
public-log preservation permit it; normal-exit confirmation is not required.
''')
write(E/'NEXT_PRIORITIES_448.md','''# Priorities448

1. Deploy qualified repair448_candidate1 /2.223 when Balatro is passively confirmed
   absent, after newest public journals are preserved. It includes447; do not
   install superseded2.222 alone. Back explicit files and qualify installed bytes.
2. Main discard lead: four/five-card The Idol anchors repeatedly fail the existing
   scoring-order proof (ten of15 unused clears); one Chad row shares the reason.
   Prove a complete supported family with resource/order negatives under12 calls.
   Do not merely enlarge budgets, omit adverse permutations or discard protected
   resources. Castle/Idol visible-floor and uncertain-clear cases are separate.
3. Extend offline offer screening to flag unsupported replacement families with
   a clearly expired sellable incumbent. The full-row suppression missed run4's
   Brainstorm; raw causal traces exposed it. Unsupported is not automatic regret.
4. Revisit early Yorickx1/empty Perkeo future copy priority and Invisible replacement
   value with explicit survival/reserve/horizon endpoints. Current2.221 run3/4
   Invisible skips are hypotheses, not demonstrated losses.
5. Preserve the complete current marathon when available. This cutoff is six
   starts/five endings only. Recompute declared denominators; distinguish missing
   joins, terminal losses and censored runs. Monitor loaded repair exposure only
   when later user-started public evidence exists; no efficacy claim yet.

All prior experiments and448 review are CLOSED. No simulation/captured execution
budget or new automation is created by these priorities.
''')
write(E/'ARCHITECTURE_MAP_448.md','''# Expired Riff-raff shop admission448

Focused copy acquisition declares direct and one-sale/one-buy endpoints. A full
row requires a replacement comparison; unsupported incumbent preparation can
block even removal of the unsupported Joker. Previously Shop.prepare checked
skip_rows before deriving the projected permanent-debuff flag.

exhausted_riff narrowly recognizes canonical public debuffed perishable Riff-raff
at numeric tally0 with known neutral coefficients and typed metadata. It only
bypasses skip_rows; normal cloned row, physical slot, editions, rent, sale value,
derived Abstract/Swashbuckler values and copy routing remain. Temporary debuff,
hidden/unknown identity, active/malformed expiry and modified callbacks refuse.
No Certificate or supported blind-start behavior changes. Comparison caps and
complete common worlds, survival, liquidity and inventory constraints remain.

Manufactured Decision sells expired Riff-raff and buys Brainstorm after the fresh
actual sale transition. Independent inert-row and48-point copy-stop checks guard
against dropping a physical slot or skipping through the expired copied target.
One-call comparison cannot publish a partial result; ordinary harmless expired
cleanup is distinct from a certified funded rental purchase.

Public audit copies bounded live prefixes twice, verifies frame/sequence chains,
and performs descriptive joins only. Full-row offer suppression still misses
unsupported replacement families.184 compact flags are retained;128 packets leave
72 flags without structural alternatives. No captured policy/scorer execution.
''')
diff=[]
changed=[rel for rel,h in F['candidate_policy_files'].items()if h!=P['before_files'].get(rel)]
assert set(changed)=={'Brainstorm/Advisor/shop_scoring.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'}
for rel in changed:
 diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(R/rel).read_text().splitlines(True),
  fromfile='candidate447/'+rel,tofile='candidate448/'+rel))
write(H/'final_changes.diff',''.join(diff))
prefix=f'''VALIDATED CANDIDATE448 /2.223.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_448.md/.json, SESSION_RESET_448.md/.json,
NEXT_PRIORITIES_448.md, ARCHITECTURE_MAP_448.md and development448/REPORT.md,
TRACE.json, METRICS.json, UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json, REVIEW.md,
FINAL_VERIFICATION.json.327Lua/494Python;110runtime/380tests; digest
{F['candidate_policy_digest']}.
Canonical expired Riff-raff shop-admission repair, including pending447 discard
coverage. NOT INSTALLED:446/2.221 exact. Current loaded2.221 prefix preserved:
18,890events/17segments;4wins/1loss/1unendedrun. Three-discard rounds10.85vs12;
four-discard16.83vs16;15clears leave31discards. Idol/order proof gaps remain.
No all-fixed or population win-rate claim.448 review/historical experiments CLOSED.
No game control/captured execution. INSTALLATION_POLICY.md governs release after
fresh passive absence and newest-log preservation. Earlier records are history.

'''
nav={}
for rel in P['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 path=R/rel;old=path.read_bytes();assert file_digest(path)==P['before_files'][rel]
 path.write_bytes(prefix.encode('utf-8')+old);assert path.read_bytes().endswith(old);nav[rel]=file_digest(path)
paths=[E/(name+'_448'+ext)for name in('CANDIDATE_CHECKPOINT','SESSION_RESET')for ext in('.json','.md')]
paths += [E/'NEXT_PRIORITIES_448.md',E/'ARCHITECTURE_MAP_448.md',C/'freeze.json',C/'validation/report.json']
paths += [p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
save(H/'FINAL_VERIFICATION.json',{'verified_utc':stamp,**checkpoint,'navigation_hashes':nav,
 'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
print(json.dumps({k:checkpoint[k]for k in('candidate_version','candidate_policy_digest','lua_fixtures','python_tests',
 'installation_status','passive_processes','prior_files_preserved')}))
