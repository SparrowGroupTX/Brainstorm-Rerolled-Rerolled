"""Record development-only archive findings; never stage runtime candidates."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
files=[]
for path in sorted(HERE.rglob('*')):
    if path.is_file() and '__pycache__' not in path.parts and path.name!='manifest.json':
        files.append({'path':path.relative_to(HERE).as_posix(),'bytes':path.stat().st_size,'sha256':digest(path)})
manifest={'schema':1,'component':'archive_codec327_read_only_review','sealed_at':datetime.now(timezone.utc).isoformat(),
          'status':'development_only_not_staged_not_shipped','runtime_format_selected':'BRJ2',
          'candidate_format':'BRJ3','candidate_tests':{'command':'python tools/advisor_eval/development327/archive_codec/run_detached_tests.py',
           'exit_code':0,'tests':23,'elapsed_seconds':0.138,'scope':'Manufactured pure Lua fixture host and Python decoder only.'},
          'source_or_policy_experiments':0,'game_control_actions':0,'original_log_mutations':0,
          'inputs':'Parent-captured eight repository public observation copies only.',
          'lossless_result_receipt':'captured_roundtrip2.json','failed_harness_receipt':'captured_roundtrip.json',
          'prospective_nonlossless_export_receipt':'prospective_export_size.json','files':files}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'manifest':str(HERE/'manifest.json'),'sha256':digest(HERE/'manifest.json'),'files':len(files)}))
