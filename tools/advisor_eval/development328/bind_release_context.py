"""Bind prepared context to a passed exact installation, without changing authority."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[3]
EVAL=ROOT/'tools/advisor_eval'


def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}


p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--release',required=True,type=int)
p.add_argument('--prefix',required=True)
p.add_argument('--prepared',required=True,type=Path)
p.add_argument('--output',required=True,type=Path)
a=p.parse_args()
assert re.fullmatch('[a-z0-9_]+',a.prefix)
prepared=a.prepared.resolve();prepared.relative_to(ROOT)
output=a.output.resolve();output.relative_to(ROOT)
candidate_path=EVAL/f'runs/{a.prefix}_candidate/validation/report.json'
installed_path=EVAL/f'runs/{a.prefix}_installed/record.json'
validation_path=EVAL/f'runs/{a.prefix}_installed_validation/report.json'
c,i,v=map(read,(candidate_path,installed_path,validation_path))
assert c['passed'] and v['passed'] and i['all_repository_files_match']
assert c['policy_digest']==v['policy_digest']==i['policy']['policy_digest']
assert c['test_files']==v['test_files'] and i['version']==f'2.{a.release-200}.0-alpha'
lua=(validation_path.parent/'lua.log').read_text(encoding='utf-8')
python=(validation_path.parent/'python.log').read_text(encoding='utf-8')
counts=re.search(r'(\d+)/(\d+) fixtures passed',lua);assert counts and counts[1]==counts[2]
n_lua=int(counts[1]);n_python=int(re.search(r'Ran (\d+) tests',python)[1])
value=read(prepared)
value['created_at_utc']=datetime.now(timezone.utc).isoformat()
value['prepared_context_preserved']=ref(prepared)
value['preparation_status']='installed_and_exact_regression_passed_activation_unconfirmed'
value['summary']+=f' Full candidate and exact-installed regressions passed {n_lua} Lua fixtures and {n_python} Python tests with unchanged frozen policy/test hashes. {i["version"]} is installed; activation waits for the user\'s normal restart.'
value['release_validation']={'version':i['version'],'installed_at':i['installed_at'],'backup':i['backup'],
 'policy_digest':c['policy_digest'],'lua_fixtures':n_lua,'python_tests':n_python,
 'candidate':ref(candidate_path),'installed':ref(installed_path),'exact_installed':ref(validation_path)}
output.parent.mkdir(parents=True,exist_ok=True)
with output.open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
print(json.dumps(ref(output)))
