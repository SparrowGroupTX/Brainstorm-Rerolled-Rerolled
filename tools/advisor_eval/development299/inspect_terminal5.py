"""M05 draft: exact terminal/cursor source references and four fixed source cases."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

folder=Path(__file__).resolve().parent
with zipfile.ZipFile('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe') as archive:
    refs=[]
    for name,needle in [('engine/controller.lua','function Controller:mod_cursor_context_layer'),
                        ('functions/button_callbacks.lua','G.FUNCS.overlay_menu'),
                        ('functions/state_events.lua','function end_round')]:
        raw=archive.read(name);lines=raw.decode().splitlines()
        for i,line in enumerate(lines):
            if needle in line:
                refs.append({'path':name,'sha256':hashlib.sha256(raw).hexdigest(),'line':i+1,
                             'text':'\n'.join(lines[max(0,i-2):i+72])})
                break
    with (folder/'terminal_cursor_source_references.json').open('x') as stream:json.dump(refs,stream,indent=2)
    print(json.dumps({'type':'source_terminal_cursor_references','references':refs}),flush=True)
import engine_probe
for scenario in ['terminal_win_final','terminal_loss_final','terminal_saved_final','terminal_unsaved_final']:
    print(json.dumps({'type':'mechanical_case_started','scenario':scenario,'policy_decisions':0}),flush=True)
    sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed','ADVISOR1',
              '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
              '--episode','--test-scenario',scenario]
    result=engine_probe.main()
    print(json.dumps({'type':'mechanical_case_finished','scenario':scenario,'exit_code':result}),flush=True)
    if result:raise SystemExit(result)
