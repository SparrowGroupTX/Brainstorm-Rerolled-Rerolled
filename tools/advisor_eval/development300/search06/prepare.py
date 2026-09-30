"""Pure preparation only: run installed Lua query with synthetic metadata.

No reservation, native search, game/source launch or player files are accessed.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from spec import make_request

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
RECORD=ROOT/'tools/advisor_eval/runs/legendary313_installed/record.json'
MODULES=['Brainstorm/Advisor/collection_search.lua','Brainstorm/Advisor/gold_search.lua',
 'Brainstorm/Advisor/gold_stickers.lua','Brainstorm/Core/collection_search_product.lua']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def create(path,value):
    with path.open('x',encoding='utf-8') as out:
        json.dump(value,out,indent=2,ensure_ascii=True,allow_nan=False);out.write('\n')

def main():
    record=json.loads(RECORD.read_text());policy=RECORD.parent/'policy'
    for name in MODULES:
        if sha(policy/name)!=record['policy']['policy_files'][name]:raise ValueError('Frozen query dependency changed: '+name)
    command=[sys.executable,'-B',str(ROOT/'tests/run_lua_tests.py'),str(HERE/'generate_query.lua')]
    run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=15,
        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    with (HERE/'query_generation2.log').open('x',encoding='utf-8')as out:out.write(run.stdout+run.stderr)
    if run.returncode:raise RuntimeError('Pure Lua preparation failed; preserved log')
    lines=[line.removeprefix('S06_QUERY_JSON ') for line in run.stdout.splitlines() if line.startswith('S06_QUERY_JSON ')]
    if len(lines)!=1:raise ValueError('Expected one synthetic generation output')
    generation=json.loads(lines[0]);request=make_request(generation)
    create(HERE/'query_generation.json',generation);create(HERE/'request.json',request)
    create(HERE/'profile_assumption.json',dict(schema=1,synthetic=True,actual_player_profile=False,
      profile=request['profile'],gold_history=generation['goal'],all_unlocked_discovered=True,
      profile_consumed_by_native=False,population_qualification=False,acquisition_or_award_injection=False))
    create(HERE/'generation_receipt.json',dict(schema=1,policy_record=str(RECORD),record_sha256=sha(RECORD),
      policy_digest=record['policy']['policy_digest'],policy_version=record['version'],
      module_hashes={name:sha(policy/name) for name in MODULES},
      generator_sha256=sha(HERE/'generate_query.lua'),query_generation_sha256=sha(HERE/'query_generation.json'),
      request_sha256=sha(HERE/'request.json'),lua_fixture_runner_sha256=sha(ROOT/'tests/run_lua_tests.py'),
      pure=True,native_calls=0,source_or_game_calls=0,registration_created=False,
      synthetic_phase1_not_found_is_fixture_only=True))
    print('Prepared S06 only; no reservation or experiment execution.')

if __name__=='__main__':main()
