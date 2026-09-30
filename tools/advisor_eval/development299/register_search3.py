from cycle import ROOT,BASE,register,read,create
import sys

digits='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';coeff=[66231629136,1892332261,54066636,1544761,44136,1261,36,1]
index=299000001;remaining=index;parts=[]
for c in coeff:
    if remaining>0:
        digit=(remaining-1)//c;remaining-=1+digit*c;parts.append(digits[digit])
seed=''.join(reversed(parts))
request={'schema':1,'seed':seed,'start_index':index,'max_indices':1000000000,'budget_ms':27000,
 'targets':['Yorick','Brainstorm','Burnt Joker','Perkeo'],'locations':['soul_pack','by_ante_5','by_ante_5','soul_pack'],
 'deck':'Red Deck','stake':8,'no_perishable_targets':True,'copy_alternatives':False,
 'cpu':'maximum','matches':1,'profile':'native_complete_unlock_assumption','selection':'deterministic development interval,not unseen validation'}
path=ROOT/'tools/advisor_eval/development299/search3_request.json';create(path,request)
prior=BASE/'M04';r=read(prior/'registration.json')
files={rel:prior/rel for rel in r['files']}
files.update({'search_v9_worker.py':ROOT/'tools/advisor_eval/development299/search_v9_worker.py','request.json':path})
create(BASE/'M04/audit.json',{'status':'passed','synthetic_checks':41,'legacy_api':'passed',
 'v9_smoke':{'screened':50000,'exact_candidates':0,'status':'not_found'},
 'cancel_smoke':'finished before cancellation; cancellation responsiveness remains unverified',
 'qualification':False,'complete_attempt':False})
register('S03',files,[sys.executable,'-B','-u','{job}/search_v9_worker.py'],{
 'hypothesis':'The explicit-status v9 native path can find the exact requested RedGold setup within27s or1billion indices,whichever ends first.',
 'request':request,'static_route':True,'qualification':False,'outer_cap_seconds':30})
print(BASE/'S03/registration.json')
