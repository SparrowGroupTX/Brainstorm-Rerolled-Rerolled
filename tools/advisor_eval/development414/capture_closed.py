"""Preserve only the old process's closed public journal prefix, never new play."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess
HERE=Path(__file__).resolve().parent
SOURCE=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
SESSION='session-20260926T232648Z-1'
# Observed newer process42968 began after every segment in this old prefix.
# User reported the run ended, then restarting. Normal exit is not inferred.
NEW_PROCESS_START=datetime(2026,9,26,23,35,58,tzinfo=timezone.utc).timestamp()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def processes():
 r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
 return json.loads(r.stdout) if r.stdout.strip() else []
def no_old_process():
 ps=processes();rows=ps if isinstance(ps,list) else [ps]
 assert all(p['Id']!=47196 for p in rows),'Old writing process still present'
 return ps
before=no_old_process()
paths=sorted(SOURCE.glob(SESSION+'-*.brj'));assert len(paths)==9
assert all(p.stat().st_mtime<NEW_PROCESS_START for p in paths)
(HERE/'capture').mkdir(exist_ok=False);(HERE/'logs1').mkdir(exist_ok=False)
segments=[]
for p in paths:
 stat=p.stat();digest=sha(p);dest=HERE/'logs1'/p.name
 shutil.copy2(p,dest)
 assert sha(dest)==digest==sha(p) and dest.stat().st_size==stat.st_size==p.stat().st_size
 segments.append({'name':p.name,'bytes':stat.st_size,'sha256':digest,'source_still_matched':True})
assert sorted(SOURCE.glob(SESSION+'-*.brj'))==paths
assert all(p.stat().st_mtime<NEW_PROCESS_START for p in paths)
after=no_old_process()
report={'captured_utc':datetime.now(timezone.utc).isoformat(),'source':str(SOURCE),'session':SESSION,'sessions':[SESSION],
 'segments':segments,'total_bytes':sum(x['bytes'] for x in segments),'all_source_still_matched':True,
 'scope':'Only closed prefix belonging to departed process47196, before observed newer process42968. No new/active journal prefix read; user-reported run end/restart does not establish normal exit or terminal outcome.',
 'old_process':47196,'observed_new_process':42968,'observed_new_start_utc':'2026-09-26T23:35:58Z',
 'passive_processes_before':before,'passive_processes_after':after,'normal_exit_confirmed':False}
(HERE/'capture/manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'session':SESSION,'segments':len(segments),'bytes':report['total_bytes'],'passive_processes':after}))
