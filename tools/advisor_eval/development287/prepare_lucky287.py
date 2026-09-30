"""Prepare B1/B2 exact inputs under a fresh user-approved287 authority; no execution."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

from lucky_source_truth import build_probe, HERE


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def item(path):
    return {'path': str(Path(path).resolve()), 'sha256': sha(path)}


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--authority',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--policy',type=Path,required=True)
    parser.add_argument('--policy-digest',required=True)
    parser.add_argument('--install',type=Path,required=True)
    args=parser.parse_args()
    authority_raw=args.authority.read_bytes();authority=json.loads(authority_raw)
    assert authority['kind']=='prospective287_authority' and authority['status']=='APPROVED' and authority['approved_by']=='user'
    assert authority['per_job_caps']['B1']==authority['per_job_caps']['B2']==30
    assert datetime.fromisoformat(authority['expires_at_utc'])>datetime.now(timezone.utc)
    args.output.mkdir(parents=True,exist_ok=False)
    rules=item(args.install/'Balatro.exe');runtime=item(args.install/'lua51.dll')
    source_root=args.output/'source';source_root.mkdir()
    with zipfile.ZipFile(rules['path']) as archive:
        for name in ('card.lua','functions/common_events.lua'):
            path=source_root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(archive.read(name))
    runtime_copy=args.output/'lua51.dll';shutil.copyfile(runtime['path'],runtime_copy)
    assert sha(runtime_copy)==runtime['sha256']
    policies={}
    for name in ('scoring','snapshot'):
        relative='Brainstorm/Advisor/'+name+'.lua';target=args.output/'policy'/relative
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(args.policy/relative,target)
        policies[relative]=item(target)
    tools=args.output/'tools';tools.mkdir()
    for name in ('lucky_source_truth.py','lucky_source_truth.lua','lucky_source_worker.py','prepare_lucky287.py'):
        shutil.copyfile(HERE/name,tools/name)
    manifests={}
    for job_id,mode in (('B1','ordinary'),('B2','red')):
        directory=args.output/job_id;directory.mkdir()
        probe,evidence=build_probe(args.output/'policy',source_root,mode)
        probe_path=directory/'source_probe.lua';probe_path.write_bytes(probe)
        assert evidence['harness_sha256']==sha(tools/'lucky_source_truth.lua')
        assert evidence['builder_sha256']==sha(tools/'lucky_source_truth.py')
        write(directory/'preparation.json',evidence)
        manifest={'schema':1,'kind':'lucky_source_truth287','job_id':job_id,'mode':mode,'cap_seconds':30,
                  'expected_cases':4 if mode=='ordinary' else 16,'qualification':False,
                  'policy_digest':args.policy_digest,'policy_root_reference':str(args.policy.resolve()),
                  'policy_files':policies,'rules':rules,'runtime':item(runtime_copy),
                  'sources':{name:item(source_root/name) for name in ('card.lua','functions/common_events.lua')},
                  'probe':item(probe_path),'worker':item(tools/'lucky_source_worker.py'),
                  'builder':item(tools/'lucky_source_truth.py'),'harness':item(tools/'lucky_source_truth.lua'),
                  'scope':evidence['scope'],'test_doubles':evidence['test_doubles']}
        manifest_path=directory/'manifest.json';write(manifest_path,manifest);manifests[job_id]=item(manifest_path)
    assert args.authority.read_bytes()==authority_raw
    assert sha(rules['path'])==rules['sha256'] and sha(runtime['path'])==runtime['sha256']
    for relative,frozen in policies.items():assert sha(args.policy/relative)==frozen['sha256']
    write(args.output/'preparation.json',{'schema':1,'kind':'lucky287_source_preparation','execution_performed':False,
        'prepared_at_utc':datetime.now(timezone.utc).isoformat(),'authority':item(args.authority),
        'source_rules':rules,'source_runtime':runtime,'frozen_runtime':item(runtime_copy),
        'manifest_files':manifests,'scope':'source files read from executable ZIP; no source or complete gameplay executed',
        'source_phase_qualified':False})
    print(json.dumps(manifests,indent=2))


if __name__=='__main__':main()
