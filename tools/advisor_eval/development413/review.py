"""Record bounded initial findings from the preserved412 public archive only."""
from pathlib import Path
from collections import Counter
import hashlib,json,sqlite3,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1];SOURCE=EVAL/'development412'
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
screen=json.loads((HERE/'screen/report.json').read_text());summary=json.loads((HERE/'analysis/summary.json').read_text())
opps=json.loads((HERE/'analysis/copy_opportunities.json').read_text())
db=sqlite3.connect((SOURCE/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
anchors=[]
for row in db.execute('SELECT seq,segment,ordinal,raw_sha,data FROM events WHERE seq IN (10730,10736,21648,21652,21655,21659,21662,21665,21670) ORDER BY seq'):
    anchors.append({'sequence':row[0],'segment':row[1],'ordinal':row[2],'event_sha256':row[3],'event':json.loads(row[4])})
db.close()
result={'scope':'Initial archived2.196 review, not full adjudication or runtime repair',
 'source_manifest_sha256':file_digest(SOURCE/'capture/manifest.json'),
 'rule_version':screen['rule_version'],'flags':screen['flags_by_rule'],'flags_omitted':screen['flags_omitted'],
 'physically_linked_clear_denominator':screen['counts']['confirmed_round_clears_linked_to_play'],
 'copy_offers':dict(Counter(o['card']['key'] for o in opps)),
 'copy_acquired_by_physical_id':dict(Counter(o['card']['key'] for o in opps if o['first_owned_sequence'] is not None)),
 'request_linkage':{k:v for k,v in summary.items() if k.startswith('missing_') or k in ('actions','actions_with_policy_action')},
 'findings':[
  {'id':'413-A','status':'observed_sale_reversal_with_source_supported_fallback_risk',
   'run':10,'requests':[21655,21665],
   'observation':'Brainstorm card:2367 sold for $1 while promising Misprint card:2455; fresh action buys Popcorn card:2454 instead. Physical observations21659/21670 confirm removal and acquisition.',
   'prior_receipt':'Brainstorm→Misprint ratio0.317611501388662, reason survival_dominated; complete replacement family false, budget_incomplete. Final sale advice says strategic-rating fallback.',
   'source':'decision.lua truncated-context branch calls advise(nil), abandoning scored candidate rejection; only shop_sequence plans receive the408 continuation contract. Ordinary replacement_sale_advice has action.followup but no shop_sequence.',
   'limitation':'No captured-policy replay or counterfactual win claim. Random mean is not a guaranteed score. Source path remains in2.198; no repair in this read-only review.'},
  {'id':'413-B','status':'missed_copy_opportunity_requires_adjudication','run':5,'request':10736,
   'observation':'Rental Brainstorm card:1349 costs$1 with$7 cash, four occupied slots and two owned rentals. Passed; complete direct receipt reports ratio1.6341789052069426, mean612, cash_after6, no_supported_copy_priority.',
   'context':'Yorick is X1 with six discards until growth. Adding a third rental requires existing reserve9; after purchase cash6. A sale of a weak existing rental might change the reserve/slot comparison.',
   'source_question':'Focused replacement sale_needed considers sticker affordability/slot capacity, not whether a sale would make upkeep reserve feasible. Must use an independent manufactured fixture before calling this a repair.',
   'limitation':'Reserve explains one sufficient veto. Does not establish all alternative finishes or whether the buy would save the run; screen suppressed this offer under rental reserve.'}],
 'anchors':anchors,'runtime_modified':False,'policy_executed':False,'active_journals_read':False}
with (HERE/'findings.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2);f.write('\n')
report='''# Initial archived marathon review413

2.198 revision412 is installed and both release gates passed. This review uses
only its saved predecessor-session logs, public loaded label2.196. No active
journals, runtime edits, policy/scorer replay, game control or new experiment.

The copied ten-start session has4 recorded wins/6 losses and no missing ending.
This initial pass is not a complete strategy or causal audit. All1,958 policy
requests link to advice/observations/callbacks/settlement markers; physical
settlement must still be checked per finding. Markers alone are insufficient.

The bounded screener retained all300 flags:80 unused-discard clears,219 short
discards and one sale-plan reversal. Its linked-clear denominator is158. These
are2.196 observations and qualitative review candidates, not measured2.198 behavior
or proof that all flagged choices were bad.16 of17 Joker-pack choices had comparable
receipts; zero pack-reversal flags is not complete coverage. There were29 opened
Buffoons across48 observed offers and60 Death-use requests, pending adjudication.

Priority finding413-A: run10 Ante6 sells rental Brainstorm at21655 while proposing
Misprint, then buys Popcorn at21665. Physical observations21659/21670 confirm both
changes. The sale advice already contains a0.318 mean-ratio rejection for the
Brainstorm→Misprint endpoint, but the comparison family exhausts its budget and
decision.lua falls back to advise(nil). That fallback can erase the rejection.
The ordinary sale has action.followup but no408 shop_sequence continuation lease.
This source path remains in2.198. No proof links it causally to the later Acorn
loss, and no new runtime repair was attempted after installation.

Priority question413-B: all three observed Blueprints and three of four observed
Brainstorms were acquired by physical ID. The missed rental Brainstorm at10736
cost$1 with$7 available, but two owned rentals made its resulting$6 smaller than
the$9 reserve. Yorick was still X1, six discards from growth. The direct comparison
was complete and estimated a1.634 mean ratio, but did not grant copy priority.
The screener suppressed this pass under the reserve rule. Investigate whether
selling a weak rental could make the purchase viable even though its sticker
price and vacant slot were already affordable. Current focused sale_needed does
not enumerate a sale solely to repair an upkeep reserve. This is a candidate
mechanism, not yet a manufactured proof or a claim that buying saves the run.

Exact event anchors and extracted public events: findings.json. Full descriptive
joins: analysis/. Heuristic queue/coverage/adjudication placeholders: screen/.
Next work should reproduce413-A on invented data, trace every irreversible shop
fallback and continuation, and separately adjudicate413-B and discard families.
Preserve the newly running session and wait for its completion before inspection.
'''
with (HERE/'REPORT.md').open('x',encoding='utf-8') as f:f.write(report)
installed=json.loads((EVAL/'SESSION_RESET_412.json').read_text())
assert policy_hashes(ROOT)==policy_hashes(Path(installed['installed']).parent)==installed['policy_files']
prior=json.loads((SOURCE/'FINAL_VERIFICATION.json').read_text())
for rel,sha in prior['artifact_hashes'].items():assert file_digest(ROOT/rel)==sha,rel
files=[p for p in HERE.rglob('*') if p.is_file()]
with (HERE/'VERIFICATION.json').open('x',encoding='utf-8') as f:
 json.dump({'installed412_runtime_unchanged':True,'release412_artifacts_unchanged':True,
  'source_manifest_sha256':result['source_manifest_sha256'],'active_journals_read':False,
  'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in files}},f,indent=2);f.write('\n')
print(json.dumps({'initial_review_complete':True,'flags':screen['flags_by_rule'],'installed_unchanged':True,'source_unchanged':True}))
