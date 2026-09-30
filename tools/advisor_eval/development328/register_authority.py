"""Record the user's fresh finite validation authority; this executes no experiment."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915'
OUT.mkdir(exist_ok=False)
baseline=ROOT/'tools/advisor_eval/runs/log327_installed/record.json'
value={
 'schema':1,'kind':'fresh_loss_validation_authority','status':'ACTIVE',
 'created_at_utc':datetime.now(timezone.utc).isoformat(),
 'request':'Fix the losses.',
 'authorization_question':'To verify whether the strategic fixes improve these losses, may I run a fresh bounded validation batch after implementation: up to 6 detached public-state comparisons (30 seconds each) and 6 complete simulated attempts (180 seconds each), for a maximum of 21 minutes of worker time, with no seed search or live-game control? Earlier experiment allowances are closed, so this needs fresh authorization.',
 'authorization_answer':'Authorize this bounded validation batch',
 'limits':{'detached_comparison_jobs':6,'seconds_per_comparison_job':30,
           'complete_attempt_jobs':6,'seconds_per_complete_attempt':180,
           'total_worker_seconds':1260,'search_jobs':0,'other_source_component_jobs':0},
 'slots':{'comparisons':['P01','P02','P03','P04','P05','P06'],
          'complete_attempts':['C01','C02','C03','C04','C05','C06']},
 'comparison_scope':'Each job may compare baseline and candidate on one declared redacted public state within one shared 30-second limit. No hidden fingerprint payloads; no future draws or source continuation inferred.',
 'attempt_scope':'Previously observed dependent development seeds. Complete isolated source attempts require fresh exact policy/adapter/profile/source/runtime provenance before one-use execution. No player saves, live gameplay, seed search, neural training or automation.',
 'baseline_checkpoint':{'path':baseline.relative_to(ROOT).as_posix(),
    'sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),
    'version':'2.127.0-alpha','policy_digest':json.loads(baseline.read_text())['policy']['policy_digest']},
 'candidate_checkpoint':'Not yet registered: finish and freeze tested strategic fixes first.',
 'one_use_rules':['Register each immutable job and reserve its full wall-clock cap before launch.',
                 'A failed launch, error, unsupported result or timeout consumes the reserved slot; preserve original output.',
                 'No retry, relabel, new directory or unused historical allowance renews a slot.',
                 'No job can exceed its type cap or the1260-second cumulative reserved limit.',
                 'Unused capacity closes explicitly when this finite validation task finishes.'],
 'historical_authority':'All historical cycles remain CLOSED; this is new authority only.',
 'registered_jobs':0,'launched_jobs':0,'reserved_worker_seconds':0,
}
path=OUT/'authority.json'
with path.open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
print(json.dumps({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                  'status':value['status'],'registered_jobs':0,'total_worker_seconds':1260}))
