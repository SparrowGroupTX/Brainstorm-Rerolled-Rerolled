"""Extract two exact public JSON snapshots; no policy or Lua execution."""
import hashlib
import io
import json
from pathlib import Path
import sys

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT/'tools/advisor_eval'))
from read_player_log import records

def sha(raw): return hashlib.sha256(raw).hexdigest()
def write(path,raw):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('xb') as f: f.write(raw)
def dump(path,value): write(path,(json.dumps(value,indent=2,allow_nan=False)+'\n').encode())
def value_span(text,key):
    """Find a field's exact value text, parsing values rather than matching text."""
    decoder=json.JSONDecoder();pos=0
    while text[pos].isspace(): pos+=1
    assert text[pos]=='{';pos+=1
    while True:
        while text[pos].isspace(): pos+=1
        if text[pos]=='}': raise KeyError(key)
        field,pos=decoder.raw_decode(text,pos)
        while text[pos].isspace(): pos+=1
        assert text[pos]==':';pos+=1
        while text[pos].isspace(): pos+=1
        start=pos;_,pos=decoder.raw_decode(text,pos)
        if field==key: return text[start:pos]
        while text[pos].isspace(): pos+=1
        assert text[pos]==',';pos+=1

audit_path=ROOT/'tools/advisor_eval/development345/log_analysis/passive_audit.json'
audit=json.loads(audit_path.read_text(encoding='utf-8'))
required={2070:'pre_small_2070',2192:'pre_leaf_2192'}
anchors={e['anchor']['sequence']:e['anchor'] for e in audit['events'] if e['anchor']['sequence'] in required}
assert set(anchors)==set(required)
seen={}
for item in audit['inputs']:
    wanted=[seq for seq,a in anchors.items() if a['segment']==Path(item['path']).name]
    if not wanted: continue
    path=Path(item['path'])
    with path.open('rb') as f: raw_prefix=f.read(item['bytes'])
    assert sha(raw_prefix)==item['input_sha256'],'Previously audited input prefix changed'
    for ordinal,(raw,frame) in enumerate(records(io.BytesIO(raw_prefix)),1):
        event=json.loads(raw);seq=event.get('sequence')
        if seq not in wanted: continue
        anchor=anchors[seq]
        assert ordinal==anchor['ordinal'] and sha(raw)==anchor['decoded_event_sha256']
        assert frame['frame_sha256']==anchor['stored_frame_sha256']
        snapshot_text=value_span(value_span(raw.decode('utf-8'),'context'),'snapshot')
        snapshot_bytes=snapshot_text.encode('utf-8');snapshot=json.loads(snapshot_bytes)
        assert snapshot==event['context']['snapshot'] and snapshot['phase']=='shop'
        assert not any(k in snapshot for k in ('retry_context','_retry','_retry_context','_shop_scoring','pseudorandom'))
        folder=OUT/'inputs'/required[seq]
        write(folder/'event.jsonl',raw);write(folder/'snapshot.json',snapshot_bytes)
        certificate_counts={}
        for card in snapshot.get('consumeables',[]):
            cert=card.get('tarot_hold_source',{})
            key=json.dumps({'key':card.get('key'),'supported':cert.get('supported'),'reason':cert.get('reason')},sort_keys=True)
            certificate_counts[key]=certificate_counts.get(key,0)+1
        p={'schema':1,'kind':'gold345_exact_public_snapshot','anchor':anchor,'source_prefix':item,
           'loaded_version':event['context'].get('version'),'seed':event['context'].get('seed'),
           'profile_id':snapshot.get('completionist_goal',{}).get('profile_id'),
           'snapshot_sha256':sha(snapshot_bytes),'snapshot_bytes':len(snapshot_bytes),
           'event_sha256':sha(raw),'event_bytes':len(raw),'event_contains_original_public_snapshot':True,
           'snapshot_serialization':'Exact UTF-8 lexical field bytes from the reconstructed original public JSONL event; no reserialization or field changes.',
           'snapshot_canonical_sha256':sha(json.dumps(snapshot,sort_keys=True,separators=(',',':'),allow_nan=False).encode()),
           'phase':snapshot['phase'],'ante':snapshot.get('ante'),'next_blind':snapshot.get('next_blind'),
           'certificate_refresh':False,'policy_execution':False,'action_dispatch':False,'selected_action_rescore':False,
           'missing_public_fields':[key for key in ('shop_forecast','normal_opening','retry_context') if key not in snapshot],
           'certificate_classes':[dict(json.loads(key),count=count) for key,count in certificate_counts.items()],
           'qualification':'Dependent recorded development input. Original unsupported constructor certificates remain unsupported. Raw registry identity, card params/front/pinned and settled visibility inputs were not logged and must not be inferred or refreshed.'}
        dump(folder/'provenance.json',p);seen[seq]={'name':required[seq],'snapshot':str(folder/'snapshot.json'),'snapshot_sha256':p['snapshot_sha256'],'provenance':str(folder/'provenance.json'),'provenance_sha256':sha((folder/'provenance.json').read_bytes())}
assert set(seen)==set(required)
manifest={'schema':1,'status':'INPUT_PREPARATION_ONLY_NO_POLICY_RUNS','audit_path':str(audit_path),'audit_sha256':sha(audit_path.read_bytes()),
          'inputs':seen,'leases_consumed':0,'policy_runs':0,'next_step':'Root freezes adapter, final candidate, baseline344, runtime, profile and inputs into fresh one-use registrations before any detached evaluation.'}
dump(OUT/'input_manifest.json',manifest)
print(json.dumps({'manifest':str(OUT/'input_manifest.json'),'sha256':sha((OUT/'input_manifest.json').read_bytes()),'inputs':seen,'policy_runs':0}))
