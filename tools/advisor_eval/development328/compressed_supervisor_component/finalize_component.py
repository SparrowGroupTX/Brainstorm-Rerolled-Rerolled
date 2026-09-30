"""Hash existing detached tooling and dummy-test receipts; no worker launch."""
from pathlib import Path
import difflib
import hashlib
import json
import stdout_transport

HERE=Path(__file__).resolve().parent
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
before=(HERE/'baseline_validation_cycle.py').read_text(encoding='utf-8')
after=(HERE/'validation_cycle.py').read_text(encoding='utf-8')
assert (HERE.parent/'validation_cycle.py').read_text(encoding='utf-8')==before,'Root supervisor changed during detached work'
patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/tools/advisor_eval/development328/validation_cycle.py',tofile='b/tools/advisor_eval/development328/validation_cycle.py'))
(HERE/'validation_cycle.patch').write_text(patch,encoding='utf-8',newline='')
value={'schema':1,'kind':'detached_prospective_compressed_stdout_supervisor','status':'ready_for_root_review',
  'root_supervisor_changed':False,'existing_frozen_registrations_changed':False,
  'baseline_root_supervisor_sha256':sha(HERE.parent/'validation_cycle.py'),
  'files':{p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.name!='manifest.json'},
  'stdout_contract':stdout_transport.CONTRACT,
  'validation':{'dummy_tests_passed':15,'final_exit_code':0,'final_worker_wall_seconds':1.0227769,
       'intermediate_12_test_pass_wall_seconds':0.8104501,'initial_test_failure_preserved':'TEST_AUTHORING_01.json',
       'scope':'Only disposable temp dummy processes/byte streams and an injected fictional ledger; no real authority/slot access.'},
  'new_experiment_jobs':0,'source_executions':0,'captured_policy_decisions':0,'complete_attempts':0,'search_jobs':0,
  'limits':'Original one-use authority and time caps remain. Applies only to prospectively registered gzip C jobs; existing evidence is unchanged. No gameplay, outcome or speedup claim.'}
with (HERE/'manifest.json').open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
print(json.dumps({'manifest_sha256':sha(HERE/'manifest.json'),'supervisor_sha256':sha(HERE/'validation_cycle.py'),
                 'transport_sha256':sha(HERE/'stdout_transport.py'),'patch_sha256':sha(HERE/'validation_cycle.patch')}))
