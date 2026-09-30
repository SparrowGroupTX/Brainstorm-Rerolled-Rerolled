#!/usr/bin/env python3
"""Bound a fresh verified build checkpoint and one unseen ordinary holdout pair."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import time
from types import SimpleNamespace
import decision_replay
import engine_probe
import paired_policy_audit as paired


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-policy-root',type=Path,required=True)
    parser.add_argument('--candidate-root',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--source-seed',required=True)
    parser.add_argument('--holdout-seed',required=True)
    parser.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args=parser.parse_args();out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    challenge='c_golden_needle_1'
    source_request={'challenge':challenge,'seed':args.source_seed}
    holdout_request={'challenge':challenge,'seed':args.holdout_seed}
    if source_request==holdout_request:raise ValueError('Holdout must differ from selected source')
    source=paired.initialize(out/'source',dict.fromkeys(paired.ROLES,args.source_policy_root),
                             args.install,[source_request],15,7)
    holdout=paired.initialize(out/'holdout',{'incumbent':args.source_policy_root,'candidate':args.candidate_root},
                              args.install,[holdout_request],40,None)
    if source['adapter_digest']!=holdout['adapter_digest']:raise ValueError('Adapter changed during registration')
    registration={'schema':1,'qualification':False,'created_utc':datetime.now(timezone.utc).isoformat(),
        'source_manifest_digest':source['manifest_digest'],'holdout_manifest_digest':holdout['manifest_digest'],
        'policies':holdout['policies'],'adapter_digest':source['adapter_digest'],
        'source_request':source_request,'source_action_cutoff':7,'replay_boundary_step':7,
        'holdout_request':holdout_request,'source_cap_seconds':15,'comparison_caps_seconds':[40,40,40,40],
        'total_requested_cap_seconds':175,'extensions_allowed':False,
        'workflow_digest':paired.file_digest(__file__),
        'scope':'selected source-verified counterfactual pair plus single unfiltered development holdout; no qualification'}
    registration['registration_digest']=paired.digest(registration)
    paired.write_json(out/'registration.json',registration);shutil.copyfile(__file__,out/'workflow.py')
    deadline=time.perf_counter()+175;result={'qualification':False,'registration_digest':registration['registration_digest']}
    record=paired.collect(paired.command_for(out/'source',source,'incumbent',source_request),
                          out/'source/source.log',source_request,15)
    paired.write_json(out/'source/source_record.json',record);result['source']=record
    print(json.dumps({'stage':'source','outcome':record['outcome'],'seconds':record['elapsed_seconds']}),flush=True)
    try:
        engine_probe.verified_replay(out/'source/source.log',out/'source/incumbent',source,challenge,args.source_seed,7)
        if time.perf_counter()+80<=deadline:
            result['replay']=decision_replay.run(SimpleNamespace(source_trace=out/'source/source.log',
                source_policy_root=out/'source/incumbent',candidate_root=out/'holdout/candidate',step=7,
                output_dir=out/'replay',install=args.install,timeout=40,wall_budget=85,
                full_episode=True,evaluate_prefix=False,execute=True))
        else:result['replay']={'outcome':'missing','reason':'remaining_registered_budget'}
    except (ValueError,KeyError,OSError) as error:
        result['replay']={'outcome':'unsupported','reason':str(error)}
    print(json.dumps({'stage':'replay','matched_checkpoint':result['replay'].get('matched_checkpoint'),
                      'outcomes':{k:v['outcome'] for k,v in result['replay'].get('requests',{}).items()}}),flush=True)
    for role in paired.ROLES:
        if time.perf_counter()+40>deadline:break
        record=paired.collect(paired.command_for(out/'holdout',holdout,role,holdout_request),
                              out/'holdout'/('000_'+role+'.log'),holdout_request,40)
        record.update(pair_index=0,role=role)
        with (out/'holdout/episodes.jsonl').open('a',encoding='utf-8') as handle:
            handle.write(json.dumps(record,allow_nan=False)+'\n')
        print(json.dumps({'stage':'holdout','role':role,'outcome':record['outcome'],
                          'seconds':record['elapsed_seconds']}),flush=True)
    result['holdout']=paired.audit(out/'holdout')
    paired.verify_manifest(out/'source',verify_install=True);paired.verify_manifest(out/'holdout',verify_install=True)
    if 'requests' in result['replay']:result['replay']=decision_replay.audit(out/'replay')
    result['elapsed_seconds']=175-(deadline-time.perf_counter())
    paired.write_json(out/'report.json',result)
    print(json.dumps({'report':str(out/'report.json'),'elapsed_seconds':result['elapsed_seconds']}),flush=True)
    return 0


if __name__=='__main__':raise SystemExit(main())
