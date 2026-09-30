"""Copy the already tested sidecar; verify its frozen native dependencies."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
base=ROOT/'tools/advisor_eval/runs/gold299_20260914/M04'
reg=json.loads((base/'registration.json').read_text())
for relative,expected in reg['files'].items():
    if relative.startswith('Immolate/'):
        assert sha(ROOT/relative)==expected,relative
    if relative.startswith('bin/') and (relative.endswith('.ids') or relative.endswith('.json') or Path(relative).name.startswith('lib')):
        assert sha(ROOT/'Brainstorm'/Path(relative).name)==expected,relative
source=base/'bin/Immolate.dll';digest=sha(source)
assert digest=='ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf'
target=ROOT/'Brainstorm'/('Immolate-advisor-'+digest+'.dll')
assert not target.exists(),'Never overwrite an existing native artifact'
shutil.copy2(source,target)
assert sha(target)==digest
print(target)
