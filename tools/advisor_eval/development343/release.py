"""Freeze/document reviewed Gold objective fixes; never authorize experiments."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, sys
HERE=Path(__file__).resolve().parent; EVAL=HERE.parent; ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version, VERSION_FIELDS
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p): return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f: f.write(data if isinstance(data,bytes) else data.encode('utf-8'))
changed={'Brainstorm/Advisor/gold_goal.lua','Brainstorm/Advisor/perkeo_inventory.lua',
         'Brainstorm/Advisor/blind_routing.lua','Brainstorm/Advisor/auto_run.lua',
         'Brainstorm/Core/auto_run_product.lua'}
if sys.argv[1]=='prepare':
    prior=read(EVAL/'runs/presentation342_installed/record.json')['policy']
    now=policy_hashes(ROOT); assert now.keys()==prior['policy_files'].keys()
    for name,h in prior['policy_files'].items():
        if name not in changed: assert now[name]==h,name
    for name in VERSION_FIELDS:
        p=ROOT/'Brainstorm'/name
        write(HERE/'before'/'Brainstorm'/name,p.read_bytes())
        stamp_version(p,name,'2.143.0-alpha')
    out=EVAL/'runs/gold343_candidate'; out.mkdir(exist_ok=False)
    policy=freeze_product(ROOT,out/'policy')
    write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
    value={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
           'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
           'changed_runtime':{name:{'before':prior['policy_files'][name],'after':sha(ROOT/name)} for name in sorted(changed)},
           'new_experiments':0,'all_experiment_authority':'closed','game_control':False,'save_reads':False}
    write(HERE/'integration.json',json.dumps(value,indent=2)+'\n'); print(policy['policy_digest'])
elif sys.argv[1]=='context':
    report=EVAL/'runs/gold343_candidate/validation/report.json'; r=read(report)
    assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
    integration=read(HERE/'integration.json'); assert r['policy_digest']==integration['policy_digest']
    for name,h in integration['changed_runtime'].items(): assert sha(ROOT/name)==h['after']
    prior=EVAL/'development342/release_final/context.json'; value=read(prior)
    assert value['release']==342 and value['status']=='CLOSED'
    for key in ('release_validation','prepared_context_preserved','manufactured_work_counts'): value.pop(key,None)
    value.update(release=343,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
        counts_scope='historical_closed_cycle',release_counts={k:0 for k in value['counts']},
        preparation_status='passed_candidate_exact_installed_validation_bound_separately',
        summary='Correct the Gold objective to permit trading surplus sampled score for strictly more distinct missing Jokers while retaining the existing 125% opening margin, whole-inventory, cash, legality, complete-family and budget guards. Perkeo endpoints still protect their own complete held/use policy. Every winning-Ante shortcut now requires confirmed missing-Joker cargo when the objective is enabled. Auto-run separately reports confirmed new Gold awards from verified original terminal callback counters; wins with unknown award evidence stay unknown.',
        outcome_summary='Passive loaded-2.142 session session-20260916T031815Z-1 contains the reported Crimson Heart win: 1,503,126/400,000, $170 at final shop exit and $207 at terminal. All five held Jokers already had Gold; progress stayed 59/150. The run took 248 automatic actions, zero rerolls and 22 shop exits, 14 with a visible missing offer. Ante8 pre-Big left ordinary Crazy Joker $4 and perishable/rental Acrobat $1; final shop left perishable Shoot the Moon $5. No counterfactual policy was replayed. Manufactured fixtures reproduce the overly strict score objective and non-Bell zero-cargo shortcut; corrected comparisons permit supported progress while preserving their stated margins. This does not prove the recorded offers could be acquired and retained through a win.',
        limits_summary='The existing Gold goal still applies only to the final pre-boss shop for Vessel, Leaf and Bell, one buy/one original sale. Its Perkeo inventory scope remains empty or bounded homogeneous Planets. The reported run ended at Crimson Heart with 13 Negative Magicians and one Negative Hermit before two exit copies; this slice alone does not cover that mixed-inventory acquisition problem. Follow-up work is separately staged for a smaller fixed-hold acquisition comparison before ordinary shop computation, without expanding score caps. Passive advice lacks detailed Gold diagnostics, so internal gate attribution is source-code inference. No new win rate, rescued run or live benefit is established. Settings, logs, native files and previous evidence are preserved; activation waits for a normal user restart.',
        budget_summary='All experiment allowances remain CLOSED. Release343 uses existing passive logs, source/code inspection and manufactured fixtures/regression only, bounded at60 seconds per suite. Zero new original-source components, captured-policy replays, searches or complete attempts; no executable archive, save/profile files, live game control or automation. Historical loss328 counts/outcomes and 1,200 seconds reserved/685.3740000000689 seconds actual remain unchanged; unused jobs stay closed.')
    value['diagnostic_evidence']={name:ref(p) for name,p in {
        'integration':HERE/'integration.json','passive_audit':HERE/'log_analysis/summary.json',
        'objective':HERE/'objective_component/result.json','routing':HERE/'routing_component/component_report.json',
        'progress':HERE/'progress_component/component_report.json','candidate_validation':report}.items()}
    out=HERE/'release_context';out.mkdir(exist_ok=False)
    write(out/'context.json',json.dumps(value,indent=2)+'\n')
    write(out/'priorities.md','''# Priorities after343

The passive zero-sticker win confirms that survival alone is the wrong objective.
343 allows a supported surplus-score trade for more missing cargo, preserves
final-Ante shops when no target is held, and reports confirmed new Gold awards
separately from wins. It does not yet cover the logged mixed Tarot pool or
Crimson Heart final shop. Do not describe this as a rescued acquisition.

Next: a bounded fixed-hold acquisition comparison before ordinary shop work,
initially late non-boss shops, with explicit unused Tarot-copy score equivalence,
complete paid alternatives, common worlds and the same aggregate50000 shop cap.
Keep future copied identity/value unresolved. Read passive logs after the user
normally restarts; no replay/search/source/terminal authority is open.

Broader Jokerless, Knife's Edge, Acorn joint resource planning and calibrated
achievement completion remain unfinished. All prior evidence stays intact.
''')
    write(out/'architecture.md','''# Gold objective navigation343

- Advisor/gold_goal.lua: strict missing-count gain with sufficient sampled score;
  real score loss remains in receipts rather than disqualifying all purchases.
- Advisor/perkeo_inventory.lua: optional validated protected-reference indices;
  Gold protects own use family, other callers default to every reference.
- Advisor/blind_routing.lua: all winning-Ante skips require known missing cargo.
- Advisor/auto_run.lua and Core/auto_run_product.lua: terminal-evidence-derived
  new Gold progress separate from run wins, explicit unknown evidence.
- tests/advisor_gold_goal.lua, advisor_bell_opening.lua,
  advisor_perkeo_inventory.lua, advisor_gold_planet_policy.lua,
  advisor_blind_routing.lua, advisor_auto_run.lua, advisor_auto_run_product.lua:
  manufactured objective, protected-family, routing and progress regressions.
- GOLD_OBJECTIVE_343.md and development343/*_component: before bytes, failed
  baselines, successful fixtures and scope receipts.
- ARCHITECTURE_MAP_342.md: preserved presentation/terminal fixes and earlier map.

Navigation grants no experiment authority.
''')
    write(out/'objective.md','Prioritize real missing Gold-sticker progress over empty wins, excess score and unused cash, with bounded public-state comparisons and explicit uncertainty.\n\n'+(EVAL/'development342/release_context/objective.md').read_text(encoding='utf-8'))
    print(json.dumps(ref(out/'context.json')))
else: raise SystemExit('Expected prepare or context')
