"""Freeze reviewed Gold acquisition changes; no experiment authority."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version,VERSION_FIELDS
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(v if isinstance(v,bytes) else v.encode())
changed={'Brainstorm/Advisor/decision.lua','Brainstorm/Advisor/snapshot.lua','Brainstorm/Advisor/runtime.lua','Brainstorm/Advisor/player_journal.lua'}
added={'Brainstorm/Advisor/gold_acquisition.lua','Brainstorm/Advisor/gold_tarot_hold.lua'}
if sys.argv[1]=='prepare':
    prior=read(EVAL/'runs/gold343_installed/record.json')['policy'];now=policy_hashes(ROOT)
    assert set(now)==set(prior['policy_files'])|added
    for name,h in prior['policy_files'].items():
        if name not in changed:assert now[name]==h,name
    for name in VERSION_FIELDS:
        p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.144.0-alpha')
    out=EVAL/'runs/gold344_candidate';out.mkdir(exist_ok=False)
    policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
    write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
        'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
        'changed_runtime':{n:{'before':prior['policy_files'].get(n),'after':sha(ROOT/n)} for n in sorted(changed|added)},
        'new_experiments':0,'all_experiment_authority':'closed','game_control':False,'save_reads':False},indent=2)+'\n')
    print(policy['policy_digest'])
elif sys.argv[1]=='context':
    report=EVAL/'runs/gold344_candidate/validation/report.json';r=read(report);integration=read(HERE/'integration.json')
    assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged'] and r['policy_digest']==integration['policy_digest']
    for n,h in integration['changed_runtime'].items():assert sha(ROOT/n)==h['after']
    prior=EVAL/'development343/release_final/context.json';v=read(prior);assert v['release']==343 and v['status']=='CLOSED'
    for k in ('release_validation','prepared_context_preserved','manufactured_work_counts'):v.pop(k,None)
    v.update(release=344,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
      counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},
      preparation_status='passed_candidate_exact_installed_validation_bound_separately',
      summary='Give a complete bounded missing-Joker acquisition family priority before ordinary shop scoring in winning-Ante shops before Small/Big. Compare hold, visible missing buys and each legal completed-original sale then buy using fixed current physical Joker rows, unchanged owned consumables and four common public deck-composition worlds. Supported random-score floors must retain a 25% margin over the next blind and cash reserves. Qualified Magician/Hermit Perkeo copying uses explicit fixed-hold score equivalence, preserving every original card and leaving future identities/prices/value unresolved. Collection attempts and ordinary advice share the existing 50,000-score cap, including unsuccessful work. Passive logs now include compact current-only collection decision reasons. Installed343 objective, routing and actual new-sticker accounting remain intact.',
      outcome_summary='The passive loaded2.142 session confirms the reported Crimson Heart win with $207 and no new Gold stickers (59/150 unchanged). It passed ordinary Crazy Joker for $4 before Ante8 Big and perishable Shoot the Moon for $5 before the boss while carrying only completed Jokers. No counterfactual policy was replayed. New manufactured fixtures demonstrate a completed sale-to-purchase path with five Jokers, $170 and fourteen mixed Negative Tarots; integration tests cover actual snapshot capture, runtime scoring dependencies, budget accounting and compact logging. This is local acquisition behavior, not proof that the recorded run would retain a target and win.',
      limits_summary='New acquisition is limited to winning-Ante pre-Small/Big shops, three offers, six owned Jokers, twenty-two endpoints and four deterministic public-composition samples. It compares fixed current rows and holds all consumables; it does not claim globally optimal consumable/order planning or a terminal win probability. Perkeo nonempty inventory qualification is ordinary/Negative Magician and Hermit only, at most64 cards; other inventories remain explicitly unsupported in this family. Final-shop Crimson Heart/Amber Acorn acquisition, general paid collection rerolls and broad earlier-Ante acquisition remain unfinished. Existing final-shop Gold goal supports Vessel/Leaf/Bell under its previous inventory limits. No live effect of2.144 or rescued run has been verified. Activation waits for normal user restart; settings, all native DLLs, logs and earlier evidence remain preserved.',
      budget_summary='All experiment allowances remain CLOSED. Release344 uses passive read-only analysis, already-preserved source excerpts and manufactured fixtures/regressions with60-second per-suite caps. Zero original-source components, captured-policy replays, searches or complete attempts; no executable archive, save/profile reads, live game control or automation. Historical loss328 counts and1,200 seconds reserved/685.3740000000689 seconds actual are unchanged; unused jobs stay closed.')
    refs={'integration':HERE/'integration.json','root_validation':HERE/'root_component/validation.json',
          'tarot_hold':HERE/'tarot_hold_component/component_receipt.json','snapshot_hook':HERE/'tarot_hold_component/snapshot_hook_receipt_1.json',
          'acquisition':HERE/'acquisition_component/result.json','candidate_validation':report,
          'acquisition_revision2':HERE/'acquisition_component/revision2/result_final.json',
          'journal':HERE/'log_diagnostics_component/component_report.json',
          'passive_audit':EVAL/'development343/log_analysis/summary.json'}
    for folder in ('acquisition_component','log_diagnostics_component'):
        for p in sorted((HERE/folder).glob('*receipt*.json')):refs[folder+'_'+p.stem]=p
    v['diagnostic_evidence']={n:ref(p) for n,p in refs.items()}
    out=HERE/'release_context';out.mkdir(exist_ok=False);write(out/'context.json',json.dumps(v,indent=2)+'\n')
    write(out/'priorities.md','''# Priorities after 344

343 corrects surplus-score tradeoffs, zero-cargo shortcuts and actual sticker
award reporting. 344 adds early-budget acquisition in winning-Ante Small/Big
shops with a fixed-hold policy, including qualified mixed Magician/Hermit pools.
The reported no-progress win is verified; these fixes have manufactured local
evidence and no new terminal validation.

Inspect new passive current-only gold_review diagnostics after a normal restart.
Do not replay old player snapshots or use closed allowances. Remaining gaps:
final-shop Heart/Acorn acquisition, collection-oriented paid rerolls, earlier-Ante
target retention, wider consumable/ordering policies and calibrated terminal
validation. Preserve completion credit separately from score and run wins.

Broader Jokerless, Knife's Edge and Acorn joint resource planning remain.
''')
    write(out/'architecture.md','''# Gold acquisition navigation 344

- Advisor/gold_acquisition.lua: fixed-row/hold-all pre-Small/Big acquisition;
  paid endpoint enumeration, common-world floors, cash and work receipts.
- Advisor/gold_tarot_hold.lua: public source constructor capture and explicit
  Perkeo Magician/Hermit copy equivalence; no invented generated inventory/value.
- Advisor/snapshot.lua and runtime.lua: capture/dependency integration.
- Advisor/decision.lua: objective family precedes ordinary shop scoring;
  all actual work subtracts from the unchanged 50,000-score allowance.
- Advisor/player_journal.lua: bounded current-only diagnostic summary.
- tests/advisor_gold_acquisition*.lua, advisor_gold_tarot_hold*.lua and
  associated journal fixture: manufactured integration/regression evidence.
- GOLD_ACQUISITION_344.md and development344/*_component: exact scope,
  source references, staged files, failed baselines and successful receipts.
- ARCHITECTURE_MAP_343.md: objective, progress, routing and prior navigation.

Navigation grants no experiment authority.
''')
    write(out/'objective.md','Acquire and retain missing Gold Jokers with sufficient supported survival margins, prioritizing real achievement progress over excess score and unused cash.\n\n'+(EVAL/'development343/release_context/objective.md').read_text())
    print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
