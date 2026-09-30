"""Staged manufactured journal tests, no live game, source execution or replay."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

root=Path(__file__).resolve().parents[4]
component=Path(__file__).resolve().parent
relative=component.relative_to(root).as_posix()
tests={"gold":relative+"/tests/advisor_gold_journal.lua", "journal":"tests/advisor_player_journal.lua",
       "timing":"tests/advisor_player_journal_timing.lua", "reuse":"tests/advisor_journal_reuse.lua"}
live="Brainstorm/Advisor/player_journal.lua"
for mode in ("before", "staged"):
    source=relative+("/before/" if mode=="before" else "/")+live
    wrappers=[]
    for name,test in tests.items():
        path=component/("run_"+mode+"_"+name+".lua")
        if not path.exists():
            with path.open("x",encoding="utf-8") as output:
                output.write("local original=dofile\ndofile=function(path)\n  if path=='"+live+"' then return original('"+source+"') end\n  return original(path)\nend\noriginal('"+test+"')\n")
        wrappers.append(path.relative_to(root).as_posix())
    files=[live,source,*tests.values(),*wrappers]
    hashes={file:hashlib.sha256((root/file).read_bytes()).hexdigest() for file in files}
    command=[sys.executable,"tests/run_lua_tests.py",*wrappers]
    receipt={"kind":"manufactured_fixture_only","live_game":False,"source_execution":False,"captured_replay":False,
             "command":command,"timeout_seconds":60,"files":hashes}
    started=time.monotonic()
    try:
        result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=60,
                              creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
        receipt.update(exit_code=result.returncode,stdout=result.stdout,stderr=result.stderr)
    except subprocess.TimeoutExpired as error:
        receipt.update(exit_code=None,timeout=True,stdout=str(error.stdout or ""),stderr=str(error.stderr or ""))
    receipt["duration_seconds"]=time.monotonic()-started
    receipt["files_unchanged"]=all(hashlib.sha256((root/file).read_bytes()).hexdigest()==sha for file,sha in hashes.items())
    number=1
    path=component/(mode+"_validation.json")
    while path.exists():
        number+=1
        path=component/(mode+"_validation_"+str(number)+".json")
    with path.open("x",encoding="utf-8") as output:json.dump(receipt,output,indent=2);output.write("\n")
    print(mode,receipt["exit_code"],receipt["stdout"],receipt["stderr"])
    if mode=="staged" and receipt["exit_code"]!=0:raise SystemExit(1)
