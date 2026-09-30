"""Preserve diagnosis/navigation and exact public anchors; no policy execution."""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import hashlib,json,sqlite3

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
source=HERE/'captures/004'
summary=json.loads((source/'summary.json').read_text())
decisions=json.loads((source/'analysis/decisions.json').read_text())
anchors=[160,171,195,208,222,271,1142,1152,1165,1822,2267,2278,
         5307,5322,5335,5348,5362,5376,5388,6940,8099,8493,8516,8535,
         8554,8572,8587,8603,9157]
clears=[]
for d in decisions:
    b=d.get('before') or {};a=d.get('after') or {}
    if (d.get('action') or {}).get('kind')=='play' and b.get('discards_left',0)>0 and a.get('chips',0)>=(b.get('blind') or {}).get('chips',float('inf')):
        clears.append({'request':d['sequence'],'run':d['run'],'observation':d['observation_sequence'],
            'advice':d['advice_sequence'],'settlement':d['settlement'],'before_chips':b['chips'],
            'settled_chips':a['chips'],'target':b['blind']['chips'],'blind':b['blind']['name'],
            'discards_before':b['discards_left'],'discards_after':a.get('discards_left'),
            'receipt':d['advice'].get('discard_before_clear')})
selected=[d for d in decisions if d['sequence'] in anchors]
raw_seqs=set(anchors+[279,1235,2282,4745,5396,8618,9163])
for d in selected:
    raw_seqs.update([d['observation_sequence'],d['advice_sequence']])
    if d.get('callback'):raw_seqs.add(d['callback']['sequence'])
    if d.get('settlement'):raw_seqs.add(d['settlement']['sequence'])
db=sqlite3.connect('file:'+str((source/'events.sqlite3').resolve())+'?mode=ro',uri=True)
raw=[]
for seq,kind,segment,ordinal,digest,data in db.execute('SELECT seq,kind,segment,ordinal,raw_sha,data FROM events ORDER BY seq'):
    if seq in raw_seqs:raw.append({'sequence':seq,'kind':kind,'segment':segment,'ordinal':ordinal,'raw_sha256':digest,'event':json.loads(data)})
db.close()
save(HERE/'evidence.json',{'capture':'004','database_sha256':sha(source/'events.sqlite3'),
    'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
    'selected_decisions':selected,'physical_clears_with_unused_discards':clears,
    'raw_anchors':raw,'policy_executed':False,'alternative_win_claimed':False})

nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
     'tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md','tools/advisor_eval/README.md']
backup=HERE/'before';backup.mkdir(exist_ok=False)
prefix=('PASSIVE MONITOR415 — 2026-09-26\n'
 'Runtime remains exact installed2.199 revision414. New user authorization permits\n'
 'passive ACTIVE PUBLIC-JOURNAL monitoring of session-20260926T235238Z-1 only.\n'
 'Read tools/advisor_eval/development415/SCOPE.md, REPORT.md, REVIEW.md and\n'
 'LATEST.json, plus SESSION_RESET_414.md/.json for exact installed bytes.\n'
 'Captured public label confirms loaded2.199; outcomes are not causal gain proof.\n'
 'Broad unused-discard exceptions, Mouth/Acorn planning gaps, Perkeo generator\n'
 'rescue veto and shop-budget fallback are diagnosed, NOT repaired. No runtime\n'
 'edit/install, game control, save/profile access, captured scorer/policy replay\n'
 'or new experiment in this monitoring slice. Sole415 review cycle is exhausted.\n'
 'Heartbeat monitor-current-balatro-session stays quiet on unchanged state and\n'
 'stops on this session ending or its process exiting. Do not infer normal exit.\n'
 'Older no-active-journal wording below is superseded only for this authorization;\n'
 'all other preservation/execution/release boundaries remain. No50% win-rate or\n'
 'below1% unused-discards claim. Historical checkpoints follow unchanged.\n\n')
preserved={}
for rel in nav:
    p=ROOT/rel;b=p.read_bytes();target=backup/rel;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(b);assert target.read_bytes()==b
    preserved[rel]={'before_sha256':sha(target),'backup':target.relative_to(ROOT).as_posix()}
    p.write_bytes(prefix.replace('\n','\r\n').encode()+b)
    assert p.read_bytes().endswith(b)
    preserved[rel]['after_sha256']=sha(p)
save(HERE/'navigation_preservation.json',preserved)
save(HERE/'MONITOR_STATE.json',{'recorded_utc':datetime.now(timezone.utc).isoformat(),
    'capture':'004','through_sequence':summary['events'],'session':summary['session'],
    'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
    'runtime_revision':414,'runtime_digest':summary['runtime_digest'],
    'monitor_id':'monitor-current-balatro-session','monitor_status':'ACTIVE',
    'reported_families':['unused_discards_order_guard','unused_discards_concealed_bypass',
      'unused_discards_mark_guard','acorn_last_hand_only_discards','mouth_blocked_cycle_planning',
      'perkeo_generator_rescue_veto','shop_budget_survival_fallback'],
    'review_cycle_complete':True,'runtime_changed':False,'scope':'passive monitoring and diagnosis only'})
print(json.dumps({'anchored_decisions':len(selected),'raw_anchors':len(raw),'unused_discard_clears':len(clears),
    'reasons':dict(Counter((x['receipt'] or {}).get('reason','missing') for x in clears)),
    'navigation_backups':len(preserved)}))
