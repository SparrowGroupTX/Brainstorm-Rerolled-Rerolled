from pathlib import Path
import json
import sys
from cycle import ROOT,BASE,register,create

create(BASE/'S01/audit_correction.json',{
 'supersedes':'audit.json causal diagnosis only; originals and spent lease preserved',
 'status':'empty_result_request_or_miss_unqualified','found_seeds':[],
 'verified_indices_traversed':None,'requested_indices_not_evidence':200000000,
 'reason':'Current source orders repeated identical targets, not these four distinct targets. Original audit acquisition-order diagnosis was incorrect. S01 passed tag_charm where product passes Charm Tag. v8 empty responses do not distinguish invalid filters and not_found; traversal and cause remain unverified.',
 'disposition':'S02 freezes the correct display tag and same original target order. No replacement or renewed S01 authority.'})
create(BASE/'M01/audit.json',{'status':'passed_initialization','complete_attempt':False,
 'observations':['Original start_run completed with normal challenge=nil, Red Deck, stake8,52 cards,4 hands,3 discards and opening Small threshold300.',
 'No normal terminal outcome or acquisition was tested. Existing normal adapter still needs authentic win-record support.'],
 'qualification':False})
record_path=ROOT/'tools/advisor_eval/runs/growth298_installed/record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
request=json.loads((Path(__file__).parent/'search1_request.json').read_text())
request.update(tag_name='Charm Tag',start_index=299000001,soft_seconds=26,max_batches=100,matches=4,
 empty_response_semantics='not_found_or_invalid; traversed index count unverified')
path=Path(__file__).with_name('search2_request.json');create(path,request)
worker=Path(__file__).with_name('search_v8_worker2.py')
source=Path(__file__).with_name('search_v8_worker.py').read_text()
source=source.replace("b'tag_charm'","request['tag_name'].encode()")
source=source.replace("'completed_indices':scanned","'requested_indices_through_returns':scanned,'verified_indices_traversed':None")
with worker.open('x') as stream:stream.write(source)
files={'search_v8_worker2.py':worker,'request.json':path,'policy_record.json':record_path}
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('S02',files,[sys.executable,'-B','-u','{job}/search_v8_worker2.py'],{
 'hypothesis':'Correct product display-tag serialization permits existing maximum-CPU native search to discover the exact user opening within30s.',
 'policy_digest':record['policy']['policy_digest'],'request':request,'profile':'native_complete_unlock_assumption',
 'static_route':True,'qualification':False})
print(BASE/'S02/registration.json')
