"""Root-operated, hash-guarded staging. Default checks only; --stage mutates."""
from pathlib import Path
import argparse
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def inside(path):
    path=path.resolve(); path.relative_to(ROOT); return path
def check(path,expected):
    if sha(path)!=expected: raise RuntimeError(f'Hash mismatch: {path}')
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--expected-manifest-sha256',required=True)
    parser.add_argument('--stage',action='store_true')
    args=parser.parse_args()
    manifest=HERE/'manifest.reviewed.json'
    check(manifest,args.expected_manifest_sha256)
    data=json.loads(manifest.read_text(encoding='utf8'))
    for name,digest in data['files'].items(): check(inside(HERE/name),digest)
    for name,digest in data['unchanged_dependencies'].items(): check(inside(ROOT/name),digest)
    for name,digest in data['existing_fixtures'].items(): check(inside(ROOT/'tests'/(name+'.lua')),digest)
    check(inside(ROOT/data['baseline']['path']),data['baseline']['sha256'])
    runtime=inside(ROOT/'Brainstorm/Advisor/growth.lua')
    fixture=inside(ROOT/'tests/advisor_growth_additive.lua')
    check(runtime,data['baseline']['sha256'])
    if fixture.exists(): raise RuntimeError('New fixture already exists; refusing to overwrite it.')
    if data['stage']!={'growth.lua':'Brainstorm/Advisor/growth.lua',
                       'advisor_growth_additive.lua':'tests/advisor_growth_additive.lua'}:
        raise RuntimeError('Unexpected stage targets.')
    if not args.stage:
        print(json.dumps({'checks_passed':True,'staged':False,'manifest_sha256':sha(manifest)}));return
    backup=inside(HERE/'stage_backup_additive319')
    backup.mkdir(exist_ok=False)
    with (backup/'growth.lua.before').open('xb') as out: out.write(runtime.read_bytes())
    with (backup/'manifest.reviewed.json').open('xb') as out: out.write(manifest.read_bytes())
    # Exclusive creation protects unrelated/untracked work and makes partial
    # failures explicit; this helper never resets, deletes or silently retries.
    with fixture.open('xb') as out: out.write((HERE/'advisor_growth_additive.lua').read_bytes())
    runtime.write_bytes((HERE/'growth.lua').read_bytes())
    check(runtime,data['files']['growth.lua']);check(fixture,data['files']['advisor_growth_additive.lua'])
    receipt={'staged':True,'release_prefix':'additive319','manifest_sha256':sha(manifest),
             'backup':str(backup.relative_to(ROOT)),
             'files':{str(p.relative_to(ROOT)):sha(p) for p in (runtime,fixture)},
             'installation_performed':False}
    with (backup/'staging_receipt.json').open('x',encoding='utf8') as out: json.dump(receipt,out,indent=2)
    print(json.dumps(receipt,indent=2))
if __name__=='__main__': main()
