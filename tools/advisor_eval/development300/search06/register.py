"""S06 preregistration ONLY. Running reserves/spends S06; root dispatches later."""
from pathlib import Path
import json
import sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/advisor_eval/development299'))
from cycle import BASE,register,read,sha
from spec import make_request,NATIVE_NAME,NATIVE_SHA256

def main():
    record_path=ROOT/'tools/advisor_eval/runs/legendary313_installed/record.json'
    record=read(record_path);policy=record_path.parent/'policy'
    generation=read(HERE/'query_generation.json');request=read(HERE/'request.json');receipt=read(HERE/'generation_receipt.json')
    assert request==make_request(generation)
    assert sha(record_path)==receipt['record_sha256']
    assert sha(HERE/'query_generation.json')==receipt['query_generation_sha256']
    assert sha(HERE/'request.json')==receipt['request_sha256']
    assert sha(HERE/'generate_query.lua')==receipt['generator_sha256']
    assert record['policy']['policy_files']['Brainstorm/'+NATIVE_NAME]==NATIVE_SHA256
    prior=BASE/'S05';old=read(prior/'registration.json')
    files={}
    for name,expected in old['files'].items():
        if name.startswith(('Immolate/','build_receipts/','bin/'))and not name.endswith('.exe'):
            assert sha(prior/name)==expected,'Native source/build asset changed: '+name
            files[name]=prior/name
    files['bin/'+NATIVE_NAME]=policy/('Brainstorm/'+NATIVE_NAME)
    # Freeze the complete exact deployed policy, not just the touched request files.
    for name,expected in record['policy']['policy_files'].items():
        assert sha(policy/name)==expected,'Frozen installed313 policy changed: '+name
        files['policy/'+name]=policy/name
    for name in ['worker.py','spec.py','generate_query.lua','prepare.py','request.json','query_generation.json',
                 'profile_assumption.json','generation_receipt.json','query_generation.log','query_generation2.log','test_s06.py','README.md',
                 'runtime_provenance.json','validation.json','validation.log','integration_manifest.json','manifest.py','register.py']:
        files[name]=HERE/name
    files['installed_policy_record.json']=record_path
    files['pure_fixture_runner.py']=ROOT/'tests/run_lua_tests.py'
    files['cycle_manager.py']=ROOT/'tools/advisor_eval/development299/cycle.py'
    register('S06',files,[sys.executable,'-B','-u','{job}/worker.py'],dict(
      hypothesis='Installed313 Auto quota may choose missing Canio plus Perkeo and nativev9 accepts/finds that conditional opening with one distinct missing target, copy alternative byAnte5 and preferred Burnt, under one30s search lease.',
      request=request,policy_digest=record['policy']['policy_digest'],
      profile=request['profile'],profile_consumed_by_native=False,qualification=False,static_route=True,
      serial_worker=True,outer_cap_seconds=30,native_sequence_max_ms=27000,max_native_calls=2,
      phase1_fixed_ms=9000,phase2_max_ms=18000,phase2_requires_actual_exit=True,
      no_registration_or_dispatch_during_preparation=True,
      product_lifecycle='Actual installed pure Lua query/facade generated both phase templates; native experiment uses serial Python orchestration, not live product or LOVE threads.',
      old_S05_authority_reused=False,source_or_game_or_profile_file_access=False,
      outcomes_preserved=['found','not_found','timeout','cancelled','invalid','busy','error'],
      limitations=request['limitation']),external=[Path(sys.executable)])
    print(BASE/'S06/registration.json')

if __name__=='__main__':main()
