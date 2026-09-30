"""M08: one synthetic nonempty final row and original Gold progress callbacks."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile
import engine_probe
folder=Path(__file__).resolve().parent
with zipfile.ZipFile('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe') as archive:
    raw=archive.read('engine/controller.lua');lines=raw.decode().splitlines();references=[]
    needles=['function Controller:queue_L_cursor_press','function Controller:key_press_update',
             'function Controller:queue_R_cursor_press','function Controller:L_cursor_press',
             'function Controller:R_cursor_press','function Controller:cursor_press']
    for needle in needles:
        for index,line in enumerate(lines):
            if needle in line:
                references.append({'needle':needle,'line':index+1,'text':'\n'.join(lines[index:index+60])});break
    with (folder/'controller_input_source_references.json').open('x') as stream:
        json.dump({'source':'engine/controller.lua','sha256':hashlib.sha256(raw).hexdigest(),
                   'maximum_methods':6,'maximum_lines_per_method':60,'references':references},stream,indent=2)
    print(json.dumps({'type':'controller_input_source_references','source_sha256':hashlib.sha256(raw).hexdigest(),
                      'methods':[{'needle':r['needle'],'line':r['line']} for r in references]}),flush=True)
sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed','ADVISOR1',
          '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
          '--episode','--test-scenario','terminal_win_final']
raise SystemExit(engine_probe.main())
