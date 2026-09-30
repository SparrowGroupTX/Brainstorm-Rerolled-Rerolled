"""Stage only the independently validated, previously absent collector fixture."""
import hashlib
import json
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    manifest=json.loads((HERE/'collector_manifest.json').read_text(encoding='utf-8'))
    for item in manifest['dependencies']:
        assert sha(ROOT/item['path'])==item['sha256'],'Reviewed dependency changed: '+item['path']
    pending=[]
    for item in manifest['integration']:
        source,target=HERE/item['source'],ROOT/item['target']
        assert item['base_sha256'] is None and not target.exists(),'Preserve existing target: '+str(target)
        assert sha(source)==item['sha256'],'Reviewed fixture changed'
        pending.append((source,target))
    for source,target in pending:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    print(json.dumps({'status':'staged','targets':[str(t)for _,t in pending]}))


if __name__=='__main__':main()
