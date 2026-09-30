"""Root-only static installed321 binding. Never runs Lua, a policy, or a worker."""
from pathlib import Path
from datetime import datetime,timezone
import argparse
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
RUNS=ROOT/'tools/advisor_eval/runs'
BASE=RUNS/'gold299_20260914'

def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def read(path):return json.loads(Path(path).read_text())
def digest(v):return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def check_binding(installed,expected_policy_digest,expected_final_sha256,reviewed_growth_sha256):
    installed=Path(installed).resolve();installed.relative_to(RUNS)
    assert installed.name.endswith('_installed') and len(expected_policy_digest)==len(expected_final_sha256)==len(reviewed_growth_sha256)==64
    record=read(installed/'record.json');policy=record['policy'];pfiles=policy['policy_files']
    assert record['version']=='2.121.0-alpha' and policy['policy_digest']==expected_policy_digest==digest(pfiles)
    stem=installed.name.removesuffix('_installed')
    final_path=installed.parent/(stem+'_final/final_verification.json')
    validation_path=installed.parent/(stem+'_installed_validation/report.json')
    assert sha(final_path)==expected_final_sha256
    final=read(final_path);validation=read(validation_path)
    assert final['version']==record['version'] and final['policy_digest']==validation['policy_digest']==expected_policy_digest
    assert final['installed_matches'] and final['native_unchanged'] and final['config_restored_or_modified_by_finalizer'] is False
    assert final['installed_report']==sha(validation_path)
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    assert validation['policy_files']==pfiles
    for name,value in pfiles.items():
        path=(installed/'policy'/name).resolve();path.relative_to(installed/'policy')
        assert sha(path)==value,name
    assert pfiles['Brainstorm/Advisor/growth.lua']==reviewed_growth_sha256,'Final growth differs from explicitly reviewed bytes'
    old=read(BASE/'C07/registration.json');graph=read(BASE/'C07/installed_graph_check.json')
    raw_path=BASE/'C07/inert_graph_raw.json';stdout_path=BASE/'C07/inert_graph_stdout.log'
    assert graph['passed'] and graph['source_initializations']==graph['policy_decisions']==0
    assert sha(BASE/'C07/installed_graph_check.json')==old['files']['installed_graph_check.json']
    assert sha(raw_path)==graph['raw_report_sha256'] and sha(stdout_path)==graph['stdout_sha256']
    assert graph['graph']==read(raw_path) and len(graph['graph']['modules'])==49 and len(graph['graph']['connections'])==40
    assert set(graph['adapter_files'])=={'engine_run.lua','policy_wiring.lua','test_wiring.lua','check_graph.py'}
    for name,value in graph['adapter_files'].items():assert sha(HERE/name)==value==old['files'][name],name
    for row in read(HERE/'preparation_origins.json'):
        assert sha(HERE/row['file'])==row['source_sha256']==old['files'][row['file']]
    runtime_name='Brainstorm/Advisor/runtime.lua';marker=b'function A.defaults()'
    previous=(BASE/'C07/policy'/runtime_name).read_bytes();current=(installed/'policy'/runtime_name).read_bytes()
    assert previous.count(marker)==current.count(marker)==1
    prefix=previous.split(marker)[0]
    assert prefix==current.split(marker)[0],'Runtime module/import/link initialization changed; graph cannot be reused'
    features=read(BASE/'C07/required_features.json')['files'].copy()
    features['Brainstorm/Advisor/growth.lua']=reviewed_growth_sha256
    assert all(pfiles[name]==value for name,value in features.items()),'An inherited reviewed feature also changed'
    rebound={'kind':'c09_static_graph_rebinding_v1','passed':True,'policy_root':str(installed/'policy'),
             'policy_digest':expected_policy_digest,'policy_files':pfiles,'adapter_files':graph['adapter_files'],
             'graph':graph['graph'],'source_graph_receipt_sha256':sha(BASE/'C07/installed_graph_check.json'),
             'source_registration_sha256':sha(BASE/'C07/registration.json'),'raw_report_sha256':sha(raw_path),
             'stdout_sha256':sha(stdout_path),'runtime_prefix_sha256':hashlib.sha256(prefix).hexdigest(),
             'runtime_prefix_bytes':len(prefix),'runtime_prefix_equal':True,
             'source_initializations':0,'policy_decisions':0,'new_inert_graph_executions':0,
             'scope':'Static rebinding of an existing inert graph proof after exact adapter/checker and complete runtime initialization-prefix equality. Module implementation changes are covered by separate final installed regression, not by a new graph execution.'}
    binding={'schema':1,'job':'C09','checkpoint':321,'version':record['version'],'installed_dir':str(installed),
             'policy_digest':expected_policy_digest,'final_verification':str(final_path),'final_verification_sha256':sha(final_path),
             'validation_report':str(validation_path),'validation_sha256':sha(validation_path),
             'installed_record_sha256':sha(installed/'record.json'),'reviewed_feature_files':features,
             'reviewed_growth_sha256':reviewed_growth_sha256,'bound_at_utc':datetime.now(timezone.utc).isoformat(),
             'registered':False,'reserved':False,'worker_executed':False}
    return binding,rebound

def bind(*args):
    assert not (BASE/'C09').exists() and not (BASE/'C09_reservation.json').exists()
    binding,graph=check_binding(*args)
    for name,value in [('installed_binding.json',binding),('installed_graph_rebinding.json',graph)]:
        with (HERE/name).open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
    return {'binding_sha256':sha(HERE/'installed_binding.json'),'graph_sha256':sha(HERE/'installed_graph_rebinding.json'),'registered':False}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--installed-dir',type=Path,required=True);p.add_argument('--expected-policy-digest',required=True)
    p.add_argument('--expected-final-sha256',required=True);p.add_argument('--reviewed-growth-sha256',required=True)
    mode=p.add_mutually_exclusive_group(required=True);mode.add_argument('--describe',action='store_true');mode.add_argument('--bind',action='store_true')
    a=p.parse_args();args=(a.installed_dir,a.expected_policy_digest,a.expected_final_sha256,a.reviewed_growth_sha256)
    print(json.dumps(bind(*args) if a.bind else check_binding(*args),indent=2))
