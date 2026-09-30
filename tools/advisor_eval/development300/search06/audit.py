"""Read-only S06 receipt audit; writes a new audit, never changes old evidence."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
from spec import make_request,parse_result
ROOT=Path(__file__).resolve().parents[4]
FOLDER=ROOT/'tools/advisor_eval/runs/gold299_20260914/S06'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def main():
    f=FOLDER;r=read(f/'registration.json');record=read(f/'record.json');result=read(f/'result.json')
    assert sha(f/'registration.json')=='5818b31a7cf97b67175eb1dc29b10bc82ab1df69e25564785e167b8d6a4fd713'
    assert sha(f/'trace.log')=='f78b8502528e3a174b9fc2c47a127771417aacd77fa3c47c7e03d2a780c733dc'
    assert record['registration_sha256']==sha(f/'registration.json')and record['trace_sha256']==sha(f/'trace.log')
    assert record['status']=='complete'and record['exit_code']==0 and record['one_use_spent']
    assert record['elapsed_seconds']<record['timeout_seconds']==30
    assert all(sha(f/name)==digest for name,digest in r['files'].items())
    assert all(sha(Path(name))==digest for name,digest in r['external_files'].items())
    request=read(f/'request.json');generation=read(f/'query_generation.json')
    assert request==make_request(generation)
    assert len(result['phases'])==result['search_calls']==1 and result['reserved_native_ms']==9000
    phase=result['phases'][0];q=phase['query'];native=parse_result((f/'phase1_raw.json').read_bytes(),q)
    assert phase['result']==native and phase==read(f/'phase1_phase_complete.json')
    assert q==request['phase_templates'][0]and phase['fully_exited']
    assert result['status']==native['status']=='found'and result['found']['seed']==native['seed']=='ITKSGS21'
    assert result['found']['receipt']==phase and result['found']['query']==q
    assert not list(f.glob('phase2_*'))
    assert native['seconds']<=phase['native_call_elapsed_seconds']<=result['worker_elapsed_seconds']<record['elapsed_seconds']
    evidence={name:sha(f/name)for name in ['registration.json','record.json','trace.log','request.json','result.json',
      'phase1_raw.json','phase1_phase_started.json','phase1_phase_complete.json','query_generation.json','generation_receipt.json',
      'profile_assumption.json','installed_policy_record.json','native_sequence_spent.json']}
    audit=dict(schema=1,job='S06',audited_at_utc=datetime.now(timezone.utc).isoformat(),status='found_native_route',
      seed=native['seed'],phase=1,burnt_required=True,burnt_relaxation_executed=False,search_calls=1,
      screened=native['screened'],exact_candidates=native['exact_candidates'],native_seconds=native['seconds'],
      synchronous_native_seconds=phase['native_call_elapsed_seconds'],outer_seconds=record['elapsed_seconds'],
      native_allocated_ms=9000,maximum_sequence_ms=27000,outer_cap_seconds=30,threads=native['threads'],
      start_index=phase['start_index'],start_seed=phase['start_seed'],requested_index_ceiling=phase['max_indices'],
      filter=dict(deck='Red Deck',stake=8,tag='Charm Tag',souls=2,primary='j_caino',secondary='j_perkeo',
        copy_alternatives=['j_brainstorm','j_blueprint'],copy_deadline=5,burnt_deadline=5,no_perishable_targets=True,
        missing_keys=['j_caino'],minimum_distinct=1,first_ante=1,last_ante=8),
      profile=dict(synthetic=True,complete=149,missing=1,unknown=0,only_missing='j_caino',
        all_unlocked_discovered=True,actual_player_profile=False,consumed_by_native=False),
      policy_digest=r['metadata']['policy_digest'],policy_version=read(f/'installed_policy_record.json')['version'],
      native_sha256=request['native_sha256'],all_frozen_inputs_verified=True,external_inputs_verified=True,
      frozen_input_count=len(r['files']),evidence_sha256=evidence,original_receipts_unchanged=True,
      qualification=False,acquisition_retention_survival_verified=False,win_or_sticker_verified=False,
      source_execution=False,game_or_save_access=False,unseen_holdout=False,
      limitations=['Native conditional route predicate only; no source acquisition or terminal evidence.',
        'Neither phase2 relaxation nor LOVE thread cancellation/launch was exercised.',
        'Parallel screened counts do not prove contiguous index coverage; requested ceiling is not traversal.',
        'Selected synthetic development cannot estimate player or challenge win rates.'])
    with(f/'audit.json').open('x',encoding='utf-8')as out:json.dump(audit,out,indent=2);out.write('\n')
    with(f/'AUDIT.md').open('x',encoding='utf-8')as out:
        out.write('S06 found ITKSGS21 in the strict first phase: Canio + Perkeo Starting Charm, copy alternative and Burnt by Ante5, Red Gold, no perishable targets, only Canio missing (quota1). Native:0.418769s; outer:0.515999999945052s;376,745,984 screened;2,220 exact candidates;32 threads. One9s call allocated; no Burnt-relaxed second call. Frozen installed313 policy/native/source-build assets and every registered input match. This proves a native conditional route match, not acquisition, survival, a complete win or a sticker. Source and player files were not accessed.\n')
    print(f/'audit.json')
if __name__=='__main__':main()
