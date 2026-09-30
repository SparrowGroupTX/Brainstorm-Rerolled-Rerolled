"""Read-only dependency preflight and pure fixture receipt; no registration."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text())
def create(path,value):
    with path.open('x',encoding='utf-8')as out:json.dump(value,out,indent=2,allow_nan=False);out.write('\n')
def main():
    record_path=ROOT/'tools/advisor_eval/runs/legendary313_installed/record.json'
    record=read(record_path);policy=record_path.parent/'policy'
    for name,digest in record['policy']['policy_files'].items():assert sha(policy/name)==digest,name
    prior=ROOT/'tools/advisor_eval/runs/gold299_20260914/S05'
    assets={name:digest for name,digest in read(prior/'registration.json')['files'].items()
      if name.startswith(('Immolate/','build_receipts/','bin/'))and not name.endswith('.exe')}
    for name,digest in assets.items():assert sha(prior/name)==digest,name
    fixture=subprocess.run([sys.executable,'-B',str(HERE/'test_s06.py')],cwd=ROOT,capture_output=True,text=True,
      timeout=15,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    with(HERE/'validation.log').open('x',encoding='utf-8')as out:out.write(fixture.stdout+fixture.stderr)
    assert fixture.returncode==0,'Pure fixtures failed'
    lua=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
    create(HERE/'runtime_provenance.json',dict(schema=1,python_path=sys.executable,python_sha256=sha(Path(sys.executable)),
      pure_generator_lua_path=str(lua),pure_generator_lua_sha256=sha(lua),
      lua_used_for_native_worker=False,source_or_game_executable_access=False))
    create(HERE/'validation.json',dict(schema=1,pure_python_tests=15,passed=True,
      pure_installed_lua_query_fixture_passed=True,policy_files_verified=len(record['policy']['policy_files']),
      native_assets_verified=len(assets),native_calls=0,registered=False,
      validation_log_sha256=sha(HERE/'validation.log')))
    create(HERE/'integration_manifest.json',dict(schema=1,status='READY_FOR_ROOT_REVIEW_ONLY',
      policy_record=str(record_path),policy_record_sha256=sha(record_path),policy_digest=record['policy']['policy_digest'],
      files={p.name:sha(p)for p in sorted(HERE.iterdir())if p.is_file()},
      native_assets=assets,registration_command='python -B tools/advisor_eval/development300/search06/register.py',
      dispatch_command='python -B tools/advisor_eval/development299/cycle.py run S06',
      registered=False,executed=False,cap_seconds=30))
    print(HERE/'integration_manifest.json')
if __name__=='__main__':main()
