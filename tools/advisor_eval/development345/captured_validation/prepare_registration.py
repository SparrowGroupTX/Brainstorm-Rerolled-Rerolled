"""Root-invoked immutable registration preparation; never starts workers."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from module_graph import module_setup
from policy_eval import JOB_IDS,LIMITS,read,sha,write,canonical

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
AUTH_QUESTION='May I validate the repair against two recorded public shop states, comparing installed 2.144 with the repaired policy? Maximum: four detached policy evaluations, 30 seconds each—2 minutes total—with no new runs, seed search, saves or live-game control. Your earlier experiment allowances are closed, so your existing rules require fresh authorization.'
AUTH_REPLY='Authorize these bounded comparisons'

def ref(p):
    p=Path(p).resolve();return {'path':str(p),'sha256':sha(p)}
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--candidate-record',required=True)
    parser.add_argument('--lua-runtime',required=True)
    parser.add_argument('--ledger',required=True)
    args=parser.parse_args();ledger=Path(args.ledger).resolve()
    if ledger.exists(): raise ValueError('Fresh exact ledger directory required; no overwrite or renewal')
    candidate=Path(args.candidate_record).resolve();baseline=ROOT/'tools/advisor_eval/runs/gold344_installed/record.json'
    policy_specs={};setup_sources={}
    for role,p in (('baseline',baseline),('candidate',candidate)):
        record=read(p);root=p.parent/'policy';manifest=record['policy']
        if hashlib.sha256(canonical(manifest['policy_files'])).hexdigest()!=manifest['policy_digest']: raise ValueError('Bad manifest')
        for name,digest in manifest['policy_files'].items():
            if sha(root/name)!=digest: raise ValueError('Changed frozen policy '+name)
        setup,_=module_setup((root/'Brainstorm/Advisor/runtime.lua').read_bytes());setup_sources[role]=setup
        policy_specs[role]={'record':ref(p),'root':str(root),'policy_digest':manifest['policy_digest']}
    if policy_specs['baseline']['policy_digest']!='e1240476b199919c929902bde1d6ea1a68df7e0f1e8ef26f32fac51dcd5bea6f': raise ValueError('Wrong baseline344')
    lua=Path(args.lua_runtime).resolve()
    if lua.name.lower()!='lua51.dll': raise ValueError('Isolated lua51.dll only')
    adapter={name:ref(HERE/name) for name in ('policy_eval.py','driver.lua','module_graph.py','lua_bytes.py','launch_serial.py')}
    preserved=ROOT/'tools/advisor_eval/runs/chicot_order_source1/source/card.lua'
    source_refs=[ref(preserved)]
    inputs=read(HERE/'input_manifest.json')['inputs']
    ledger.mkdir(parents=True)
    authority={'schema':1,'kind':'gold345_captured_shop_authority','status':'AUTHORIZED','approved_by':'user',
      'approval_question':AUTH_QUESTION,'approval_text':AUTH_REPLY,
      'approval_reference':'request_user_input_async call_SZMboULT3LSXFb5FXSQrvc0J, question index 0; exact user reply supplied by root.',
      'job_ids':list(JOB_IDS),'limits':LIMITS,'serial_only':True,'no_replacements':True,'ledger_directory':str(ledger),
      'hypothesis':'The repaired policy changes one or more collection admission diagnostics or actions on two fixed recorded public shops without mutating inputs or exceeding the existing shop score cap.',
      'qualification':'Exact old public certificates remain unchanged. These dependent development comparisons can remain unsupported and are not terminal validation, a rescue, a representative cohort or win-rate evidence.',
      'forbidden':['source execution','seed search','complete attempts','save/profile file access','live game control','constructor certificate inference or refresh','replacement workers'],
      'registration_prepared_by':'root invocation of reviewed prepare_registration.py; workers require separate root spent receipts and bounded launch'}
    write(ledger/'authority.json',authority)
    for role,setup in setup_sources.items():
        with (ledger/(role+'_module_setup.lua')).open('xb') as f: f.write(setup)
    registrations=[]
    for job in JOB_IDS:
        role='baseline' if job.startswith('B') else 'candidate';sequence=job[1:];spec=inputs[sequence]
        folder=ledger/job;folder.mkdir()
        snapshot=read(spec['snapshot']);provenance=read(spec['provenance'])
        if sha(spec['snapshot'])!=spec['snapshot_sha256'] or sha(spec['provenance'])!=spec['provenance_sha256']: raise ValueError('Changed input')
        profile={'schema':1,'kind':'actual_passive_public_player_context','synthetic':False,
          'label':'Actual redacted public player shop state from loaded 2.144; no profile/save file was read.',
          'sequence':int(sequence),'seed':provenance['seed'],'profile_id':provenance['profile_id'],
          'objective':snapshot.get('completionist_goal',{}).get('goal'),'gold_counts':snapshot.get('completionist_goal',{}).get('counts'),
          'snapshot_sha256':spec['snapshot_sha256'],'constructor_certificate_refresh':False,'population_qualified':False,'RNG_state_supplied':False}
        write(folder/'profile.json',profile)
        reg={'schema':1,'kind':'gold345_captured_policy_job','status':'REGISTERED','job_id':job,'role':role,'one_use':True,
          'authority':ref(ledger/'authority.json'),'timeout_seconds':30,'score_cap':50000,
          'options':'product_defaults_no_overrides','source_execution':False,'action_dispatch':False,'selected_action_rescore':False,
          'certificate_refresh':False,'adapter_files':adapter,'python':ref(sys.executable),'lua_runtime':ref(lua),
          'snapshot':ref(spec['snapshot']),'input_provenance':ref(spec['provenance']),'profile':ref(folder/'profile.json'),
          'policy':policy_specs[role],'module_setup':ref(ledger/(role+'_module_setup.lua')),'source_references':source_refs,
          'source_reference_scope':'Hash-only binding to an already-preserved mechanic reference; never loaded into worker Lua.',
          'command':[str(Path(sys.executable).resolve()),str(HERE/'policy_eval.py'),str(folder/'registration.json')],
          'result_scope':'One isolated deterministic product decision on the exact recorded public snapshot. No selected-action dispatch or source confirmation.'}
        write(folder/'registration.json',reg)
        registrations.append({'job_id':job,'registration':ref(folder/'registration.json'),'command':reg['command'],'reserved_seconds':30})
    write(ledger/'registration_manifest.json',{'schema':1,'authority':ref(ledger/'authority.json'),'jobs':registrations,'total_reserved_seconds':120,'workers_started':0,'policy_specs':policy_specs,'launcher':ref(HERE/'launch_serial.py')})
    print(json.dumps({'ledger':str(ledger),'manifest_sha256':sha(ledger/'registration_manifest.json'),'reserved_seconds':120,'workers_started':0}))
if __name__=='__main__': main()
