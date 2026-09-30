from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import time

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
results=[]
for label,runner in [('before_mixed','run_before_mixed.lua'),('candidate_final','run_candidate.lua')]:
    command=['python','tests/run_lua_tests.py',str((OUT/runner).relative_to(ROOT))]
    started=time.perf_counter()
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
    log=OUT/f'{label}.log';assert not log.exists()
    log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
    results.append({'mode':label,'command':command,'exit_code':r.returncode,'seconds':time.perf_counter()-started,
                    'log':str(log.relative_to(ROOT)),'sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
    print(label,r.returncode,r.stdout[-250:],r.stderr[-500:])
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
target='Brainstorm/Advisor/gold_tarot_hold.lua'
before=(OUT/'before'/target).read_text();after=(OUT/target).read_text()
patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=target+'.before',tofile=target))
(OUT/'gold_tarot_hold.patch').write_text(patch,encoding='utf-8')
report=json.loads((OUT/'manifest.json').read_text())
report.update({'row_identity_count':110,'source_note':'Cartomancer included only for ending-shop copy dependency; separate exact-full inventory startup gate required in Gold/Shop.',
 'staged_sha256':sha(OUT/target),'tests':{'tests/advisor_gold_tarot_rows.lua':sha(OUT/'tests/advisor_gold_tarot_rows.lua')},
 'validation':results,'prior_validation':'validation.json','suite_cap_seconds':60,
 'integration_instruction':'Merge only the row_names catalog/comment block; retain separately staged pin normalization and constructor changes.',
 'limitations':'Read-only source analysis and manufactured local fixtures; no captured-policy replay, source worker, search, terminal attempt or demonstration of rescued win.'})
(OUT/'component_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if results[0]['exit_code']!=0 and results[1]['exit_code']==0 else 1)
