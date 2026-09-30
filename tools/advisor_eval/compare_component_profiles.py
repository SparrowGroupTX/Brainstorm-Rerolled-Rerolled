"""Audit two frozen component profiles without equating added work with speedup."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import statistics
from component_profile import summarize, verify, write_json
from benchmark import digest, file_digest

def load(path):
    path=Path(path).resolve();manifest=verify(path)
    report=json.loads((path/'report.json').read_text(encoding='utf-8'))
    if report!=summarize(report['records'],manifest['workloads']):
        raise ValueError('Profile summary differs from retained worker records')
    for record in report['records']:
        log=path/Path(record['log']).name
        if file_digest(log)!=record['log_digest']:
            raise ValueError('Retained profile worker log changed')
    return manifest,report

def evidence(workload):
    rows=workload['rows']['prepared']
    first=rows[0] if rows else {}
    labels=sorted({key for row in rows for key in row.get('components',{})})
    components={key:{
        'median_inclusive_fraction':statistics.median(row['components'].get(key,{}).get('inclusive_seconds',0)/max(row['elapsed_seconds'],1e-9) for row in rows),
        'median_inclusive_seconds':statistics.median(row['components'].get(key,{}).get('inclusive_seconds',0) for row in rows),
        'calls':first.get('components',{}).get(key,{}).get('calls',0)} for key in labels}
    return {'latencies':workload['latencies'],'cache_pair_exact':workload['exact_paired_result'],
            'action':first.get('action'),'evaluations':first.get('evaluations'),
            'shop_diagnostics':first.get('shop_diagnostics'),'score_cache':first.get('score_cache'),
            'readiness_status':first.get('readiness_status'),'readiness_reason':first.get('readiness_reason'),
            'components':components}

def compare(before_path,after_path,output):
    before_manifest,before=load(before_path);after_manifest,after=load(after_path)
    if before_manifest['adapter_digest']!=after_manifest['adapter_digest'] or before_manifest['workloads']!=after_manifest['workloads']:
        raise ValueError('Cross-policy comparison requires identical frozen adapter and workloads')
    if before_manifest['runtime_digest']!=after_manifest['runtime_digest']:
        raise ValueError('Cross-policy comparison requires the same runtime')
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=False)
    shutil.copyfile(Path(__file__),output/'compare_component_profiles.py')
    report={'schema':1,'qualification':False,'win_rate_evidence':False,'general_speedup_established':False,
        'inputs':{'before':{'path':str(Path(before_path).resolve()),'manifest_digest':before_manifest['manifest_digest'],
                            'policy_digest':before_manifest['policy_digest'],'report_digest':file_digest(Path(before_path)/'report.json')},
                  'after':{'path':str(Path(after_path).resolve()),'manifest_digest':after_manifest['manifest_digest'],
                           'policy_digest':after_manifest['policy_digest'],'report_digest':file_digest(Path(after_path)/'report.json')}},
        'adapter_digest':after_manifest['adapter_digest'],'aggregation_sha256':file_digest(output/'compare_component_profiles.py'),
        'workloads':[]}
    for left,right in zip(before['workloads'],after['workloads']):
        l=left['rows']['prepared'];r=right['rows']['prepared']
        def same(field):return bool(l and r) and len({row[field] for row in l+r})==1
        complete=left['exact_paired_result'] and right['exact_paired_result']
        report['workloads'].append({'workload':left['workload'],'complete_exact_cache_pairs':complete,
            'same_input':same('input_fingerprint'),'same_action':same('action_fingerprint'),
            'same_score_count':same('evaluations'),'same_full_result':same('decision_fingerprint'),
            'cross_policy_speed_comparison_eligible':complete and same('input_fingerprint') and same('evaluations') and same('decision_fingerprint'),
            'before':evidence(left),'after':evidence(right)})
    report['report_digest']=digest(report);write_json(output/'report.json',report)
    print(json.dumps({'output':str(output),'workloads':len(report['workloads']),
        'exact_cache_pairs':all(w['complete_exact_cache_pairs'] for w in report['workloads']),
        'cross_policy_speed_comparison_eligible':sum(w['cross_policy_speed_comparison_eligible'] for w in report['workloads'])}))
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--before',type=Path,required=True);p.add_argument('--after',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args();compare(a.before,a.after,a.output)
