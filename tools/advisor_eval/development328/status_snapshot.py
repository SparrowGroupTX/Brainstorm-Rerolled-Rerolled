"""Immutable accounting snapshot for the existing fresh authority, not a reset."""
from pathlib import Path
from datetime import datetime,timezone
from collections import Counter
import json,sys
import validation_cycle as v
def snapshot(name):
 assert name.replace('_','').isalnum()
 jobs=[];outcomes=Counter();counts={'source_components':0,'captured_pair_jobs':0,'captured_policy_evaluations':0,'search_workers':0,'complete_attempts':0}
 for p in sorted(v.BASE.glob('*_reservation.json')):
  reservation=v.read(p);job=reservation['job'];folder=v.BASE/job
  r=v.read(folder/'record.json') if (folder/'record.json').exists() else None
  audit=v.read(folder/'audit.json') if (folder/'audit.json').exists() else None
  spent=(folder/'spent.json').exists()
  row={'job':job,'reserved_seconds':reservation['timeout_seconds'],'spent':spent,'record':r,
   'reservation_sha256':v.sha(p),'registration_sha256':v.sha(folder/'registration.json'),
   'record_sha256':v.sha(folder/'record.json') if r else None,
   'audit_sha256':v.sha(folder/'audit.json') if audit else None}
  if job.startswith('P'):
   counts['captured_pair_jobs']+=int(spent)
   for role in ('baseline','candidate'):
    summary=folder/(role+'_summary.json')
    if summary.exists():counts['captured_policy_evaluations']+=1
  else:
   counts['complete_attempts']+=int(spent)
   outcome=audit['outcome'] if audit else ('running' if spent and not r else 'error' if r and r['status']=='error' else 'not_started')
   if spent and r and not audit:raise ValueError('Completed attempt needs a retained audit before checkpoint accounting')
   row['outcome']=outcome
   if spent:outcomes[outcome]+=1
  jobs.append(row)
 reserved=sum(j['reserved_seconds'] for j in jobs)
 actual=sum((j['record'] or {}).get('elapsed_seconds',0) for j in jobs)
 outcomes={k:outcomes[k] for k in ('win','loss','error','timeout','unsupported','censored','running')}|{'not_started':6-counts['complete_attempts']}
 value={'schema':1,'kind':'fresh_loss_validation_status','status':'ACTIVE','created_at_utc':datetime.now(timezone.utc).isoformat(),
  'authority_sha256':v.AUTHORITY_SHA,'counts':counts,'complete_attempt_outcomes':outcomes,'jobs':jobs,
  'reserved_worker_seconds':reserved,'actual_worker_seconds':actual,'remaining_authority_seconds':1260-reserved,
  'remaining_comparison_slots':6-sum(j['job'].startswith('P') for j in jobs),'remaining_complete_slots':6-sum(j['job'].startswith('C') for j in jobs),
  'verified_complete_win':outcomes['win']>0,'qualification':False,
  'unused_capacity':'retained_under_existing_authority','historical_allowances':'CLOSED; no prior capacity carries forward'}
 path=v.BASE/(name+'.json');v.create(path,value)
 print(json.dumps({'path':str(path),'sha256':v.sha(path),'counts':counts,'outcomes':outcomes,'reserved':reserved,'actual':actual,'remaining':1260-reserved}))
 return value,path
if __name__=='__main__':snapshot(sys.argv[1])
