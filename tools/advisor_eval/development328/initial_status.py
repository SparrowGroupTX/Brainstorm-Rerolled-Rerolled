"""Immutable pre-execution status for the newly authorized finite batch."""
from pathlib import Path
from datetime import datetime, timezone
import json
import hashlib
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915'
authority=OUT/'authority.json'
value={'schema':1,'status':'ACTIVE','created_at_utc':datetime.now(timezone.utc).isoformat(),
 'authority':{'path':authority.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(authority.read_bytes()).hexdigest()},
 'counts':{'source_components':0,'captured_pair_jobs':0,'captured_policy_evaluations':0,'search_workers':0,'complete_attempts':0},
 'complete_attempt_outcomes':{'win':0,'loss':0,'error':0,'timeout':0,'unsupported':0,'censored':0,'running':0,'not_started':6},
 'registered_jobs':[],'launched_jobs':[],'reserved_worker_seconds':0,'actual_worker_seconds':0,
 'remaining_comparison_jobs':6,'remaining_complete_attempt_jobs':6,'unreserved_worker_cap_seconds':1260,
 'note':'Fresh user-authorized validation batch only. No policy/adapter/source worker has been registered or launched. All prior cycles remain closed.'}
path=OUT/'status_initial.json'
with path.open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
print(json.dumps({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}))
