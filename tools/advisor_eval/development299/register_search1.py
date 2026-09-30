from pathlib import Path
import json
import sys
from cycle import ROOT,BASE,register,create

record_path=ROOT/'tools/advisor_eval/runs/growth298_installed/record.json'
record=json.loads(record_path.read_text())
policy=record_path.parent/'policy'
request={'schema':1,'api':8,'native_file':'Immolate-advisor-a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885.dll',
    'deck':'b_red','stake':8,'targets':['Yorick','Brainstorm','Burnt Joker','Perkeo'],
    'locations':['soul_pack','by_ante_5','by_ante_5','soul_pack'],'no_perishable_targets':True,
    'native_cpu_mode':'maximum','start_index':299000001,'batch_indices':200000,
    'max_batches':1000,'matches':4,'soft_seconds':27,'outer_seconds':30,
    'selection_scope':'fresh deterministic index development discovery, not random population or unseen validation'}
request_path=Path(__file__).with_name('search1_request.json');create(request_path,request)
files={'search_v8_worker.py':Path(__file__).with_name('search_v8_worker.py'),'request.json':request_path,
    'policy_record.json':record_path}
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('S01',files,[sys.executable,'-B','-u','{job}/search_v8_worker.py'],
    {'hypothesis':'Existing maximum-CPU normal search can find the exact requested strong Red Gold opening within30s.',
     'policy_digest':record['policy']['policy_digest'],'request':request,'profile':'native_complete_unlock_assumption',
     'static_route':True,'qualification':False})
print(BASE/'S01/registration.json')
