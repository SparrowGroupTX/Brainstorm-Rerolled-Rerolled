from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
files=['tests/advisor_auto_log_projection.lua','candidate_01.json','baseline347_01.json','before_01.json',
 'before/Brainstorm/Advisor/auto_run.lua','validate.py','seal.py']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={
 'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'component':'348 controller event projection before strict data cloning',
 'status':'test_staged_only_runtime_owned_by_root',
 'files':{str((OUT/p).relative_to(ROOT)):sha(OUT/p)for p in files},
 'candidate_runtime_sha256':sha(ROOT/'Brainstorm/Advisor/auto_run.lua'),
 'baseline_runtime_sha256':sha(ROOT/'tools/advisor_eval/runs/gold347_installed/policy/Brainstorm/Advisor/auto_run.lua'),
 'validation':{'candidate_record':'candidate_01.json','candidate_checks':215,'candidate_pass':True,
  'baseline_record':'baseline347_01.json','baseline_pass':False,
  'baseline_failure':'The immutable installed347 controller rejects the oversized raw action fingerprint before its projection callback can export a bounded descriptor.'},
 'preserved_harness_note':'before_01.json is not prechange evidence. The first local copy occurred after root had already edited the shared controller and therefore contains candidate bytes; its passing record and copied file remain preserved. baseline347_01.json subsequently tests the immutable actual347 policy with the same manufactured fixture.',
 'coverage':[
  'Projection sees the entire raw key while actual freshness and Execute callbacks continue receiving the exact raw key.',
  'Exported action-attempt and action-observed records contain only bounded descriptors; changed advice tokens do not repeat pending actions.',
  'Absent and identity callbacks preserve legacy behavior, including the unchanged strict oversized-string rejection without projection.',
  'Present nonfunction callbacks reject at construction.',
  'Throw, nil, scalar, metatable, cycle, nonfinite numbers, function payloads and oversized unrelated strings fail logging without executing or falling back to raw data.',
  'Rejected journal records still fail closed; consumed action counters and stopped status prevent silent retries or allowance renewal.',
 ],
 'scope':'Manufactured injected callbacks only; no real search workers, source execution, captured policy evaluation, save/profile access, game control or terminal experiments. Runtime edits were made by root, not this component.',
}
with(OUT/'component_report.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
print(sha(OUT/'component_report.json'))
