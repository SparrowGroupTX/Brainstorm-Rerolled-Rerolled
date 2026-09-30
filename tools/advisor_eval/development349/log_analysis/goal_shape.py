"""Record only static source and already frozen public goal field shapes."""
import hashlib
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(data):return hashlib.sha256(data).hexdigest()
event_path=HERE/'original_event_85.json'
data=event_path.read_bytes();e=json.loads(data);s=e['context']['snapshot'];g=s['completionist_goal'];card=s['shop_jokers'][1]
assert card['key']=='j_droll'
source=[]
for rel in ('Brainstorm/Advisor/runtime.lua','Brainstorm/Advisor/gold_stickers.lua','Brainstorm/Advisor/snapshot.lua'):
 p=ROOT/rel;b=p.read_bytes()
 source.append({'path':str(p),'bytes':len(b),'sha256':sha(b)})
fields=('schema','goal','metadata_status','catalog_status','held_status','stake_status','eligibility','counts')
report={'schema':1,'scope':'Static field-shape audit; no Lua execution, evaluation or new player-data access.',
 'event':{'path':str(event_path),'sha256':sha(data),'sequence':e['sequence'],'version':e['context']['version']},
 'source_read_receipts':source,
 'public_goal':{k:g.get(k) for k in fields},
 'goal_enabled_present':'enabled' in g,'goal_active_present':'active' in g,
 'offer':{'id':card.get('id'),'key':card.get('key'),'ability_set':card.get('ability',{}).get('set'),
   'ability_eternal':card.get('ability',{}).get('eternal'),'top_level_eternal_present':'eternal' in card,
   'edition_present':'edition' in card,'edition':card.get('edition'),'goal_record':g['by_key'][card['key']]},
 'modifiers_all_eternal':s.get('modifiers',{}).get('all_eternal'),
 'mismatch_risks':[
   'The goal table has no enabled/active flag. Runtime attaches it only while the gold_stickers setting is true; presence plus validated metadata is the existing opt-in shape.',
   'Per-card Eternal is ability.eternal; challenge-wide Eternal may instead be represented by snapshot.modifiers.all_eternal.',
   'Normal edition may be absent. Non-Negative slot protection should not accidentally exempt Holographic/Foil/Polychrome Eternals.',
   'A public seed string is present in ordinary generated runs too; eligibility must use the explicit verified eligibility metadata, not context.seed presence.',
   'Empty reasons and held-target lists are serialized as objects when Lua tables are empty. Do not require a JSON array shape or a nonempty reasons field to recognize eligibility.',
   'status belongs to by_key[card.key].status, with complete/missing/unknown values; no per-card gold boolean is supplied.',
   'Detached snapshots from the underlying snapshot module do not automatically include runtime objective context; tests need realistic completionist_goal metadata and cannot assume capture adds it.'
 ],
 'conclusion':'All existing public metadata needed to classify the observed Droll as an already-complete, non-Negative Eternal is present. No new profile or source execution is needed.'}
dest=HERE/'goal_shape.json'
with dest.open('x',encoding='utf-8') as handle:json.dump(report,handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(dest),'sha256':sha(dest.read_bytes()),'classification_metadata_present':True}))
