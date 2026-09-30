"""Preserve navigation history and record the user's revised release authority."""
from pathlib import Path
from datetime import datetime,timezone
import json,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest
base=json.loads((EVAL/'SESSION_RESET_419.json').read_text());installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
tests=test_manifest();config=file_digest(installed/'config.lua')
native={p.name:file_digest(p) for p in installed.glob('*.dll')}
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
 'tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md','tools/advisor_eval/WIN_RATE_RESEARCH.md',
 'tools/advisor_eval/README.md','tools/advisor_eval/NEXT_PRIORITIES_419.md',
 'tools/advisor_eval/ARCHITECTURE_MAP_419.md']
prefix='''CURRENT RELEASE AUTHORIZATION — 2026-09-27
Read tools/advisor_eval/INSTALLATION_POLICY.md. The user removed the explicit
normal-exit/closure confirmation requirement: check Balatro's process directly
and install a fully validated update when a fresh check shows it is absent.
Do not ask again. If running, defer; never close or control it. Preserve journals,
backups, settings/DLLs and exact candidate/installed gates. Absence is not proof
of normal exit or completed runs; record that distinction honestly. Historical
confirmation requirements below are superseded. Installed remains4192.203.

'''.encode('utf-8')
before={};after={}
for rel in nav:
 path=ROOT/rel;old=path.read_bytes();backup=HERE/'before'/rel
 backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(old)
 before[rel]=file_digest(backup)
 path.write_bytes(prefix+old);assert path.read_bytes()==prefix+backup.read_bytes()
 after[rel]=file_digest(path)
r=subprocess.run(['pwsh','-NoProfile','-Command',
 '@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
 capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
assert test_manifest()==tests and file_digest(installed/'config.lua')==config
assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==native
record={'updated_utc':datetime.now(timezone.utc).isoformat(),
 'user_instruction':"Don't require explicit confirmation anymore. Just check for yourself and install if so.",
 'policy':'tools/advisor_eval/INSTALLATION_POLICY.md','policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),
 'explicit_closure_confirmation_required':False,'fresh_passive_absence_required':True,
 'normal_exit_inferred_from_absence':False,'navigation_before':before,'navigation_after':after,
 'history_preserved':True,'runtime_and_tests_unchanged':True,'settings_and_native_unchanged':True,
 'installed_version':base['version'],'installed_digest':base['policy_digest'],'passive_processes':processes,
 'installation_needed':False,'game_control':False,'automation_created':False}
with (HERE/'record.json').open('x',encoding='utf-8') as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({'policy_updated':True,'installed_version':base['version'],'runtime_unchanged':True,'processes':processes}))
