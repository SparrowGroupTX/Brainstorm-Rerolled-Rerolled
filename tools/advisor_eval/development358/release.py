"""Freeze surplus-development repair; no captured policy or gameplay execution."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,sys
HERE=Path(__file__).resolve().parent
EVAL=HERE.parent
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version,VERSION_FIELDS
CHANGED=['Brainstorm/Advisor/consumables.lua','Brainstorm/Advisor/strategy.lua']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb')as f:f.write(value if isinstance(value,bytes)else value.encode('utf-8'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
if sys.argv[1]=='prepare':
    prior=read(EVAL/'runs/teacher357_installed/record.json')['policy'];current=policy_hashes(ROOT)
    assert current.keys()==prior['policy_files'].keys()
    for name,expected in prior['policy_files'].items():
        if name not in CHANGED:assert current[name]==expected,name
    for name in VERSION_FIELDS:
        p=ROOT/'Brainstorm'/name;write(HERE/'before/Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.158.0-alpha')
    out=EVAL/'runs/teacher358_candidate';out.mkdir(exist_ok=False)
    policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
    write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
        'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
        'changed_runtime':{n:{'before':prior['policy_files'][n],'after':policy['policy_files'][n]}for n in CHANGED},
        'game_control':False,'save_reads':False,'new_experiments':0},indent=2)+'\n');print(policy['policy_digest'])
elif sys.argv[1]=='context':
    validation=sys.argv[2] if len(sys.argv)>2 else 'validation'
    assert validation in ('validation','validation2')
    candidate=read(EVAL/'runs/teacher358_candidate'/validation/'report.json')
    assert candidate['passed']and candidate['policy_unchanged']and candidate['tests_unchanged']
    context=read(EVAL/'development357/context.json')
    context.update(release=358,created_utc=datetime.now(timezone.utc).isoformat(),
        summary='Admit consumable deck development beside a supported score-floor clear, retaining bounded work, inventory and resource safeguards, and improve equal-gain target selection.',
        outcome_summary='Final loaded2.156 product journals remain seven starts: two verified Ante8 wins, four losses, and one unfinished run explicitly stopped by the user. Both wins earned zero new Gold. These are selected development openings, not a representative or unseen cohort. No2.157 or2.158 terminal outcome, rescued run, improved win odds or training gain is demonstrated. No verified complete Jokerless win is established.',
        limits_summary='Supported score-floor fixtures prove local safe development, not future survival or an optimal copying pool. Ordinary random-mean tactical gaps, last-template valuation, consumable surplus sales, cash investment and concealed discard planning remain. Original public logs are fallible demonstrations, not expert labels. No game/save/profile control, captured policy evaluation or training occurred. Normal restart activation is unconfirmed.',
        budget_summary='Only passive final public-journal/source review and routine manufactured fixtures/regressions ran in development. Zero new source/search/captured-policy/simulation/GPU workers. All historical allowances remain closed. Stopped product-batch starts cannot be reused as hidden experiment authority. Current journals/settings/saves/native DLLs are preserved.',
        evidence={k:ref(p)for k,p in {'authority':HERE/'AUTHORITY.md','outcomes':EVAL/'development357/shop_review/final_report.json','budget':HERE/'BUDGET.json','limits':HERE/'AUTHORITY.md'}.items()})
    write(HERE/'context.json',json.dumps(context,indent=2)+'\n');print(json.dumps(ref(HERE/'context.json')))
else:raise SystemExit('Expected prepare or context')
