"""Freeze the reviewed growth integration; never execute captured states or games."""
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
CHANGED=['Brainstorm/Advisor/decision.lua','Brainstorm/Advisor/growth.lua']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb')as f:f.write(value if isinstance(value,bytes)else value.encode('utf-8'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
if sys.argv[1]=='prepare':
    prior=read(EVAL/'runs/teacher358_installed/record.json')['policy'];current=policy_hashes(ROOT)
    assert current.keys()==prior['policy_files'].keys()
    for name,expected in prior['policy_files'].items():
        if name not in CHANGED:assert current[name]==expected,name
    for name in VERSION_FIELDS:
        p=ROOT/'Brainstorm'/name;write(HERE/'before/Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.159.0-alpha')
    out=EVAL/'runs/growth359_candidate';out.mkdir(exist_ok=False)
    policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
    write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
        'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
        'changed_runtime':{n:{'before':prior['policy_files'][n],'after':policy['policy_files'][n]}for n in CHANGED},
        'game_control':False,'save_reads':False,'new_experiments':0},indent=2)+'\n');print(policy['policy_digest'])
elif sys.argv[1]=='context':
    validation=sys.argv[2] if len(sys.argv)>2 else 'validation'
    assert validation in ('validation','validation2')
    candidate=read(EVAL/'runs/growth359_candidate'/validation/'report.json')
    assert candidate['passed']and candidate['policy_unchanged']and candidate['tests_unchanged']
    context=read(EVAL/'development358/context.json')
    context.update(release=359,created_utc=datetime.now(timezone.utc).isoformat(),
        summary='Give proven useful Yorick/Burnt discards priority over optional consumable development and qualify current-row copied Yorick scoring benefit inside the existing growth budget.',
        outcome_summary='Passive journals confirm loaded2.158 on previously studied M4BVSY11. Through2026-09-16T19:17:59Z,21 rounds cleared and11 retained discards;24Empress uses include18optional development actions. No terminal appears in this prefix. Earlier loaded2.156 batch remains two verified wins,four losses,one user-stopped unfinished opening,zero newGold in win-first mode. No2.159 outcome or improved win odds is demonstrated; no verified complete Jokerless win is established.',
        limits_summary='Priority applies only to an admitted growth discard preserving the existing clear/resources. Copy-aware growth value remains a heuristic based on the actual supported visible row; it never multiplies physical discard counters or assumes a future reorder. Full five-card discards, exhaustive continuations, hazardous bosses, saturated growth, template planning and below-target budget allocation remain bounded or unsupported. No game/save/profile control,captured policy execution or training occurred. New installation activation awaits normal restart.',
        budget_summary='Development used passive public-log/source analysis and manufactured fixture/full regression only. Zero new detached/source/search/simulation/GPU workers; historical allowances remain closed. The user-started live product session was not controlled,stopped,resumed or granted more starts by tools. Journals/settings/saves/native DLLs are preserved.',
        passive_product_evidence={'loaded_version':'2.158.0-alpha','seed':'M4BVSY11','cutoff':'2026-09-16T19:17:59Z','terminal_count_in_prefix':0,'manifest':ref(HERE/'log_review/logs1/manifest.json')},
        evidence={k:ref(p)for k,p in {'authority':HERE/'AUTHORITY.md','outcomes':HERE/'log_review/report.json','budget':HERE/'BUDGET.json','limits':HERE/'AUTHORITY.md'}.items()})
    write(HERE/'context.json',json.dumps(context,indent=2)+'\n');print(json.dumps(ref(HERE/'context.json')))
else:raise SystemExit('Expected prepare or context')
