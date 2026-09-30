"""Freeze reviewed bytes and record passive evidence; never run a game."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,sys
HERE=Path(__file__).resolve().parent
EVAL=HERE.parent
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version,VERSION_FIELDS
CHANGED=['Brainstorm/Advisor/joker_retirement.lua','Brainstorm/Core/auto_run_product.lua']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(value if isinstance(value,bytes) else value.encode('utf-8'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
if sys.argv[1]=='prepare':
    prior=read(EVAL/'runs/teacher356_installed/record.json')['policy']
    current=policy_hashes(ROOT)
    assert current.keys()==prior['policy_files'].keys()
    for name,expected in prior['policy_files'].items():
        if name not in CHANGED:assert current[name]==expected,name
    for name in VERSION_FIELDS:
        p=ROOT/'Brainstorm'/name
        write(HERE/'before/Brainstorm'/name,p.read_bytes())
        stamp_version(p,name,'2.157.0-alpha')
    out=EVAL/'runs/teacher357_candidate';out.mkdir(exist_ok=False)
    policy=freeze_product(ROOT,out/'policy')
    write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
    write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
        'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
        'changed_runtime':{n:{'before':prior['policy_files'][n],'after':policy['policy_files'][n]}for n in CHANGED},
        'game_control':False,'save_reads':False,'new_experiments':0},indent=2)+'\n')
    print(policy['policy_digest'])
elif sys.argv[1]=='context':
    candidate=read(EVAL/'runs/teacher357_candidate/validation/report.json')
    assert candidate['passed'] and candidate['policy_unchanged'] and candidate['tests_unchanged']
    context={'schema':1,'kind':'checkpoint_experiment_context','status':'CLOSED','release':357,
        'created_utc':datetime.now(timezone.utc).isoformat(),
        'summary':'Repair asynchronous auto-run shop settlement and restore exact expired-rental disposal for win-first teacher mode, based on passive product logs.',
        'outcome_summary':'Final loaded2.156 product journals record seven starts: two verified Ante8 wins, four losses, and one unfinished run explicitly stopped by the user. Both wins earned zero new Gold. These are selected development openings, not a representative or unseen cohort. No2.157 terminal outcome, rescued run, improved win odds or training gain is demonstrated. No verified complete Jokerless win is established.',
        'limits_summary':'Logged demonstrations are heuristic and not expert labels. Duplicate purchase and stale cash contaminate affected downstream decisions. Perkeo template depletion, surplus-copy use, future-boss/discard planning and shop investment remain strategic gaps. No game/save/profile control, captured policy evaluation or training occurred. Installation requires normal restart to activate.',
        'budget_summary':'Only passive frozen public-journal/source review and routine manufactured fixtures/regressions ran in development. Zero new source/search/captured-policy/simulation/GPU workers. Historical allowances remain closed. The separately user-started ten-run product session stopped after seven starts; unused starts are not hidden experiment authority. Current logs/settings/saves/native DLLs are preserved.',
        'counts':{k:0 for k in ('source_components','captured_pair_jobs','captured_policy_evaluations','search_workers','complete_attempts')},
        'complete_attempt_outcomes':{k:0 for k in ('win','loss','error','timeout','unsupported','censored','running','not_started')},
        'verified_complete_win':False,'unused_capacity':'closed',
        'passive_product_evidence':{'loaded_version':'2.156.0-alpha','starts':7,'wins':2,'losses':4,'unfinished':1,'new_gold':0,'manifest':ref(HERE/'logs2/manifest.json')},
        'evidence':{k:ref(HERE/name)for k,name in {'authority':'AUTHORITY.md','outcomes':'logs2/summary.json','budget':'BUDGET.json','limits':'AUTHORITY.md'}.items()}}
    write(HERE/'context.json',json.dumps(context,indent=2)+'\n');print(json.dumps(ref(HERE/'context.json')))
else:raise SystemExit('Expected prepare or context')
