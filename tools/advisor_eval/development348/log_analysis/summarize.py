"""Summarize already-frozen passive bytes; never read a live journal tail."""
import collections
from datetime import datetime, timedelta
import hashlib
import io
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from read_player_log import records

def sha(data): return hashlib.sha256(data).hexdigest()
AUDIT = HERE / 'passive_audit.json'
expected = '532092c5bc654205c655d7e0fd123b8135393422acbab81026facff6ced194a7'
assert sha(AUDIT.read_bytes()) == expected
audit = json.loads(AUDIT.read_bytes())
events = audit['events']
by_seq = {e['anchor']['sequence']: e for e in events}
def identity(e): return {key:e[key] for key in ('anchor','at','kind','version','seed')}
def details_brief(e):
    wanted = ('event','reason','detail','run_number','run_id','run_actions','run_seconds','time','actions','runs_started','outcomes','gold_award','gold_progress','state')
    return {**identity(e),'details':{k:e['details'][k] for k in wanted if k in e['details']},'state':e['state']}
stop = by_seq[1854]
chronology = [details_brief(by_seq[i]) for i in (12,1011,1020,1844,1845,1846,1848,1849,1850,1851,1852,1853,1854)]
fingerprints=[]
for e in events:
    if e['kind'] != 'auto_run': continue
    for field in ('fingerprint','before','after'):
        value=e['details'].get(field)
        if isinstance(value,dict) and value.get('kind')=='snapshot_fingerprint_sha256':
            fingerprints.append({**identity(e),'event':e['details'].get('event'),'field':field,**value})
searches=[]
for e in events:
    if e['kind']=='collection_search_finished':
        receipt=e['details']['receipt']
        request=receipt.get('request',{})
        searches.append({**identity(e),'result':receipt.get('result'),
            'request':{k:request.get(k) for k in ('deck','stake_level','tag','souls','target_jokers','target_locations','reject_perishable_targets','minimum_distinct','first_ante','last_ante','interchangeable_copies')},
            'started_at':next((x['details'].get('start_seed') for x in reversed(events[:events.index(e)]) if x['kind']=='collection_search_started'),None),
            'receipt_wall_seconds':receipt.get('elapsed_wall_seconds')})
public={}
original_receipts=[]
for file in audit['inputs']:
    data=Path(file['frozen_path']).read_bytes()
    assert sha(data)==file['sha256'] and len(data)==file['bytes']
    for raw,meta in records(io.BytesIO(data)):
        e=json.loads(raw)
        if e.get('sequence') not in (1851,1853,1854): continue
        seq=e['sequence'];snapshot=e.get('context',{}).get('snapshot',{})
        out=HERE / ('original_event_'+str(seq)+'.json')
        with out.open('xb') as handle: handle.write(raw)
        original_receipts.append({'sequence':seq,'path':str(out),'sha256':sha(raw)})
        inventory=snapshot.get('consumeables',[])
        public[seq]={'inventory_count':len(inventory),'inventory_limit':snapshot.get('consumable_limit'),
            'inventory_classes':dict(collections.Counter(c.get('key') for c in inventory)),
            'negative_count':sum(isinstance(c.get('edition'),dict) and c['edition'].get('negative') is True for c in inventory),
            'tarot_certificates':dict(collections.Counter(str(c.get('tarot_hold_source',{}).get('supported')) for c in inventory if c.get('ability',{}).get('set')=='Tarot')),
            'pack_type':snapshot.get('pack_type'),'pack_choices':snapshot.get('pack_choices'),
            'pack_cards':[{'index':i,'key':c.get('key'),'name':c.get('name'),'id':c.get('id')} for i,c in enumerate(snapshot.get('pack_cards',[]),1)],
            'snapshot_scope':e.get('context',{}).get('snapshot_scope'),
            'snapshot_compact_json_bytes':len(json.dumps(snapshot,separators=(',',':'),ensure_ascii=False).encode('utf-8')),
            'serialization_limit':'This JSON byte count is not the raw runtime fingerprint length; journal snapshots omit some runtime fields.'}
windows=[e for e in events if e['kind']=='performance_window' and e['anchor']['sequence']>1854]
poststop={'windows':len(windows),'first_at':windows[0]['at'],'last_at':windows[-1]['at'],
    'flags_last':windows[-1]['details']['flags'],'nonperformance_events':sum(e['anchor']['sequence']>1854 and e['kind']!='performance_window' for e in events),
    'last_frame_interval':windows[-1]['details']['metrics'].get('frame_interval')}
source_paths=['Brainstorm/Advisor/auto_run.lua','Brainstorm/Advisor/product_auto.lua','Brainstorm/Advisor/player_journal.lua']
source_hashes={str(p):sha((ROOT/p).read_bytes()) for p in source_paths if (ROOT/p).is_file()}
report={'schema':1,'scope':audit['scope'],'audit':{'path':str(AUDIT),'sha256':expected},
    'inputs':audit['inputs'],'loaded_versions':audit['loaded_versions'],'decode_errors':audit['decode_errors'],
    'last_sequence':1895,'last_at':events[-1]['at'],'stops':[details_brief(e) for e in events if e['details'].get('event')=='session_stopped'],
    'terminal_outcomes':[details_brief(e) for e in events if e['details'].get('event')=='run_finished'],
    'latest_run':{'seed':'YVYN2Z11','run_id':'game:3','status':'unfinished; stopped by controller logging guard',
        'start_sequence':1020,'stop_sequence':1854,'run_seconds_before_stop':stop['details']['time']-by_seq[1020]['details']['time'],
        'automatic_actions':159,'confirmed_new_gold':0,'progress':stop['goal'].get('counts'),'state':stop['state'],
        'last_advice':stop['advice'],'jokers':[{'key':j.get('key'),'name':j.get('name'),'gold_status':j.get('gold_status'),'eternal':j.get('ability',{}).get('eternal',False)} for j in stop['jokers']]},
    'chronology':chronology,'searches':searches,'fingerprint_evidence':{
        'controller_string_limit':262144,'largest_logged':max(fingerprints,key=lambda x:x['byte_length']),
        'last_logged':fingerprints[-1],'final_fingerprint_length':'Not recorded: the controller rejected the event before the product log could hash and emit it.',
        'source_inference':'A pending pack-open action was accepted and its settled public pack observed. The next action_observed record is absent, followed by log_unavailable with the controller clone guard string. Prior fingerprint was 258571 bytes. Controller source applies a262144-byte string limit before product log compaction. Oversized next fingerprint is strongly consistent; its exact rejected length is not directly observed. This is not evidence of a nonfinite Black Hole score.'},
    'public_near_stop':public,'original_event_receipts':original_receipts,'after_stop':poststop,
    'source_read_hashes':source_hashes,
    'limits':['No advisor was evaluated on any captured state.','The latest run is censored at a pack; no loss or win is imputed.','No beyond-stop actions or outcomes were observed in the frozen prefix.','Previously studied seeds remain development data.','Search found receipts do not prove acquisition, retention, survival or future win odds.']}
out=HERE/'summary.json'
with out.open('x',encoding='utf-8') as handle:
    json.dump(report,handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(out),'sha256':sha(out.read_bytes()),'latest_run':{k:report['latest_run'][k] for k in ('seed','status','automatic_actions','run_seconds_before_stop')},
    'near_stop':public,'after_stop':poststop,'searches':searches}))
