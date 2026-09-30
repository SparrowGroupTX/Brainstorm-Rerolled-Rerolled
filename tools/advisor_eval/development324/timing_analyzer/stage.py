"""Guarded new tooling/test files only; --stage must be explicitly supplied."""
import argparse
import hashlib
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',action='store_true');args=parser.parse_args()
    m=json.loads((HERE/'manifest.json').read_text())
    for row in m['files']:assert sha(HERE/row['path'])==row['sha256'],row
    for row in m['dependencies']:assert sha(ROOT/row['path'])==row['sha256'],row
    for row in m['integration']:
        assert row['base_sha256'] is None and not (ROOT/row['target']).exists(),row
        assert sha(HERE/row['source'])==row['sha256'],row
    if args.stage:
        for row in m['integration']:
            with (ROOT/row['target']).open('xb')as f:f.write((HERE/row['source']).read_bytes())
        for row in m['integration']:assert sha(ROOT/row['target'])==row['sha256'],row
    print(json.dumps({'status':'staged' if args.stage else 'checked','files':m['integration']}))
if __name__=='__main__':main()
