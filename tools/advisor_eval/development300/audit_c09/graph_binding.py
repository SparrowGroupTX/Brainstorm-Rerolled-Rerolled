"""Read-only C09 graph rebinding/provenance checks; no policy or source imports."""
from pathlib import Path
import hashlib
import json

def sha(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def verify_graph_receipt(folder,registration,expected_policy):
    issues=[]
    def check(value,reason):
        if not value:issues.append(reason)
    def read(name):return json.loads((folder/name).read_text())
    files=registration['files'];meta=registration['metadata']
    binding=read('installed_binding.json');graph=read('installed_graph_rebinding.json')
    prior=read('source_C07_registration.json');source_graph=read('source_C07_installed_graph_check.json')
    raw=read('inert_graph_raw.json')
    registered={k[7:]:v for k,v in files.items() if k.startswith('policy/')}
    check(binding.get('job')=='C09' and binding.get('checkpoint')==321 and binding.get('version')=='2.121.0-alpha','Installed binding scope differs')
    check(binding.get('policy_digest')==graph.get('policy_digest')==digest(registered)==expected_policy,'Static graph whole-policy digest differs')
    check(graph.get('policy_files')==registered,'Static graph whole-policy file set differs')
    check(meta.get('installed_binding_sha256')==sha(folder/'installed_binding.json'),'Registered installed binding hash differs')
    check(meta.get('installed_graph_rebinding_sha256')==sha(folder/'installed_graph_rebinding.json'),'Registered static graph binding hash differs')
    check(binding.get('final_verification_sha256')==sha(folder/'installed_final_verification.json') and binding.get('validation_sha256')==sha(folder/'installed_validation.json') and binding.get('installed_record_sha256')==sha(folder/'installed_policy_record.json'),'Installed binding evidence hashes differ')
    check(graph.get('kind')=='c09_static_graph_rebinding_v1' and graph.get('passed') is True and graph.get('runtime_prefix_equal') is True,'Static graph rebinding status differs')
    check(graph.get('source_initializations')==graph.get('policy_decisions')==graph.get('new_inert_graph_executions')==0,'Static graph receipt claims unexpected execution')
    check(graph.get('source_graph_receipt_sha256')==sha(folder/'source_C07_installed_graph_check.json')==prior['files'].get('installed_graph_check.json'),'Original C07 graph proof hash differs')
    check(graph.get('source_registration_sha256')==sha(folder/'source_C07_registration.json'),'Original C07 registration hash differs')
    check(source_graph.get('kind')=='c07_complete_installed_graph_check' and source_graph.get('passed') is True and source_graph.get('source_initializations')==source_graph.get('policy_decisions')==0,'Original inert graph proof scope differs')
    check(source_graph.get('policy_digest')==prior['metadata']['policy_digest']==digest(source_graph.get('policy_files')),'Original C07 whole-policy graph provenance differs')
    check(graph.get('graph')==source_graph.get('graph')==raw,'Rebound graph payload differs from original proof')
    check(graph.get('raw_report_sha256')==source_graph.get('raw_report_sha256')==sha(folder/'inert_graph_raw.json'),'Original inert raw graph hash differs')
    check(graph.get('stdout_sha256')==source_graph.get('stdout_sha256')==sha(folder/'inert_graph_stdout.log'),'Original inert graph stdout hash differs')
    check(raw.get('kind')=='c07_inert_current_runtime_graph' and raw.get('passed') is True and raw.get('source_initialized') is False and raw.get('policy_decisions')==0 and raw.get('retry_enabled') is False and raw.get('gold_objective_enabled') is True,'Inherited current-runtime graph scope differs')
    check(len(raw.get('modules',[]))==49 and len(raw.get('connections',[]))==40,'Current graph node/edge count differs')
    check(graph.get('adapter_files')==source_graph.get('adapter_files') and set(graph.get('adapter_files',{}))=={'engine_run.lua','policy_wiring.lua','test_wiring.lua','check_graph.py'},'Graph adapter/checker set differs')
    check(all(files.get(k)==v==prior['files'].get(k) for k,v in graph.get('adapter_files',{}).items()),'Exact inherited graph adapter/checker bytes differ')
    runtime='Brainstorm/Advisor/runtime.lua';old_path=folder.parent/'C07/policy'/runtime
    check(sha(old_path)==prior['files']['policy/'+runtime],'Retained C07 runtime bytes changed')
    old=old_path.read_bytes();new=(folder/'policy'/runtime).read_bytes();marker=b'function A.defaults()'
    check(old.count(marker)==new.count(marker)==1,'Runtime graph boundary differs')
    old_prefix=old.split(marker)[0];new_prefix=new.split(marker)[0]
    check(old_prefix==new_prefix and len(new_prefix)==graph.get('runtime_prefix_bytes') and hashlib.sha256(new_prefix).hexdigest()==graph.get('runtime_prefix_sha256'),'Exact current runtime initialization prefix differs')
    features=binding.get('reviewed_feature_files',{})
    check(features==meta.get('reviewed_feature_files') and bool(features) and all(registered.get(k)==v for k,v in features.items()),'Exact reviewed feature binding differs')
    check(features.get('Brainstorm/Advisor/growth.lua')==binding.get('reviewed_growth_sha256')=='d0de330671d31888fb49c886326cc470274552645d616836ad3fb588c139d688','Final321 growth byte binding differs')
    compact=read('prior_audits.json')
    check(compact==meta.get('prior_selected_audits'),'Compact prior-audit metadata differs')
    for job,row in compact.items():
        name=row.get('filename','');path=Path(row.get('original_path','')).resolve()
        check(Path(name).name==name and name.startswith('audit') and name.endswith('.json') and path==(folder.parent/job/name).resolve(),'Prior audit reference is not a contained original audit')
        check(path.is_file() and sha(path)==row.get('sha256'),'Original authoritative prior audit hash differs')
        check(row.get('record_sha256')==sha(folder/('prior_'+job+'_record.json')) and row.get('registration_sha256')==sha(folder/('prior_'+job+'_registration.json')),'Compact prior record/registration binding differs')
        check(row.get('audit_issues')==[] and row.get('disposition')==('timeout' if job=='C07' else 'loss'),'Prior audited outcome differs')
        if row.get('selected_pointer_sha256'):
            pointer=read('prior_'+job+'_selected_audit.json')
            check(sha(folder/('prior_'+job+'_selected_audit.json'))==row['selected_pointer_sha256'] and pointer.get('filename')==name and pointer.get('sha256')==row['sha256'],'Selected prior audit pointer differs')
    check(set(compact)=={'C07','C08'},'Unexpected prior audit family')
    check(sha(folder/'authority.json')==registration.get('authority_sha256'),'Authority hash differs')
    reservation=folder.parent/'C09_reservation.json'
    check(reservation.is_file() and sha(reservation)==registration.get('reservation_sha256'),'Fresh C09 reservation hash differs')
    if reservation.is_file():
        receipt=json.loads(reservation.read_text())
        check(receipt.get('job')=='C09' and receipt.get('timeout_seconds')==180 and receipt.get('one_use') is True,'Fresh C09 one-use limits differ')
    return {'passed':not issues,'policy_digest':expected_policy,'manifest_modules':len(raw.get('modules',[])),
            'manifest_edges':len(raw.get('connections',[])),'root_bindings':raw.get('root_bindings'),
            'graph_rebinding_sha256':sha(folder/'installed_graph_rebinding.json'),'original_graph_sha256':sha(folder/'source_C07_installed_graph_check.json'),
            'new_graph_executions':0,'runtime_prefix_sha256':graph.get('runtime_prefix_sha256'),'required_feature_files':features,
            'scope':'Read-only verification of a static rebind of original inert graph evidence, compact authoritative prior-audit provenance and exact installed321 bytes. No source, policy, module or adapter was executed by this auditor.'},issues
