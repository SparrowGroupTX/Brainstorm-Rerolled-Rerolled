"""Root-only freeze of the remaining C05 slot from exact installed331 provenance."""
from pathlib import Path
import json
import validation_cycle as v

path=Path(__file__).with_name('validation_adapter')/'prepared/C05_nine331_sealed.json'
assert v.sha(path)=='ec7b3229e5755b8d76ea6d7660d84055bcd23834eafa1b779d1851df53de2317'
spec=json.loads(path.read_text())
assert spec['job']=='C05' and spec['timeout_seconds']==180
assert spec['metadata']['checkpoint']==331 and spec['metadata']['prior_comparison_job']=='C02'
assert spec['metadata']['fresh_reciprocal_pair'] is False
assert all(v.sha(source)==spec['expected_files'][name] for name,source in spec['files'].items())
assert all(v.sha(source)==digest for source,digest in spec['external_sha256'].items())
files=dict(spec['files'])
files['prepared_registration_inputs.json']=str(path.resolve())
files['root_freeze_definition.py']=str(Path(__file__).resolve())
print(v.register('C05',files,spec['command'],spec['metadata'],spec['external']))
