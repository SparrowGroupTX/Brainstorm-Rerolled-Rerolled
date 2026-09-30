"""Version and freeze the composed public-observation runtime for regression."""
from pathlib import Path
import sys,json,hashlib
ROOT=Path(__file__).resolve().parents[3]; EVAL=ROOT/'tools/advisor_eval'
sys.path.insert(0,str(EVAL))
from install_slice import stamp_version, VERSION_FIELDS
from paired_policy_audit import freeze_product
HERE=Path(__file__).parent
receipt=json.loads((HERE/'acorn332_preparation/root_integration_evidence/receipt.json').read_text())
assert receipt['status']=='composed_not_stamped_tested_or_installed'
for row in receipt['completed']:
    assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['after_sha256']
folder=EVAL/'runs/acorn332_candidate'; folder.mkdir(exist_ok=False)
for relative in VERSION_FIELDS: stamp_version(ROOT/'Brainstorm'/relative,relative,'2.132.0-alpha')
record=freeze_product(ROOT,folder/'policy')
with (folder/'freeze.json').open('x',encoding='utf-8') as f: json.dump(record,f,indent=2); f.write('\n')
print(json.dumps({'candidate':str(folder),'policy_digest':record['policy_digest'],'files':len(record['policy_files'])}))
