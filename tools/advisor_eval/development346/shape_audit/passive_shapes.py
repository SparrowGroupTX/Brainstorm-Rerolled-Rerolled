"""Read public field shapes only; do not run any advisor policy on them."""
from pathlib import Path
import collections,hashlib,json
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
source=ROOT/'tools/advisor_eval/development346/log_analysis/passive_audit.json'
report=json.loads(source.read_text(encoding='utf-8'))
cards=collections.defaultdict(dict)
for event in report['events']:
    for card in event.get('consumeables',[]):
        shape={k:card.get(k) for k in ('key','name','ability','base','base_cost','cost','sell_cost','debuff','pinned','face_down','edition','seal','tarot_hold_source')}
        identity=json.dumps(shape,sort_keys=True,separators=(',',':'))
        if identity not in cards[card.get('key')]:cards[card.get('key')][identity]={'first_anchor':event['anchor'],'shape':shape,'count':0}
        cards[card.get('key')][identity]['count']+=1
summary={}
for key,rows in cards.items():
    values=list(rows.values());first=values[0]
    summary[key]={'unique_public_shapes':len(values),'observed_cards':sum(x['count'] for x in values),
        'ability_field_sets':sorted(set(','.join(sorted(x['shape']['ability'])) for x in values)),
        'base_field_sets':sorted(set(','.join(sorted(x['shape']['base'])) for x in values)),
        'source_statuses':dict(collections.Counter(json.dumps(x['shape'].get('tarot_hold_source'),sort_keys=True) for x in values)),
        'first_shape':first}
output={'schema':1,'scope':'Read-only passive shape inventory. No advisor policy/validator was applied to captured snapshots.',
    'input':str(source.relative_to(ROOT)),'input_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'summary':summary}
path=OUT/'passive_shape_inventory.json'
with path.open('x',encoding='utf-8')as f:json.dump(output,f,indent=2);f.write('\n')
print(json.dumps({'path':str(path),'keys':list(summary),'shape_counts':{k:x['unique_public_shapes'] for k,x in summary.items()}}))
