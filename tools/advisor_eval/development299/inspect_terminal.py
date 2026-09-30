"""M02 draft: bounded source terminal inspection and four zero-decision fixtures."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

folder=Path(__file__).resolve().parent
selected={
    'functions/misc_functions.lua':['function set_deck_win','function set_joker_win'],
    'functions/state_events.lua':['set_deck_win(', 'set_joker_win(', 'G.GAME.won = true', 'saved'],
    'functions/button_callbacks.lua':['set_deck_win(', 'set_joker_win('],
}
with zipfile.ZipFile('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe') as archive:
    for name,needles in selected.items():
        raw=archive.read(name);lines=raw.decode().splitlines()
        refs=[]
        for needle in needles:
            for index,line in enumerate(lines):
                if needle in line:
                    refs.append({'needle':needle,'line':index+1,'before':max(1,index-5),
                                 'text':'\n'.join(lines[max(0,index-6):index+65])})
        with (folder/(Path(name).stem+'_source_references.json')).open('x') as stream:
            json.dump({'path':name,'sha256':hashlib.sha256(raw).hexdigest(),'references':refs},stream,indent=2)
        print(json.dumps({'type':'source_terminal_reference','path':name,'sha256':hashlib.sha256(raw).hexdigest(),
                          'references':refs}),flush=True)
import engine_probe
for scenario in ['terminal_win_final','terminal_loss_final','terminal_saved_final','terminal_unsaved_final']:
    print(json.dumps({'type':'mechanical_case_started','scenario':scenario,'policy_decisions':0}),flush=True)
    sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed','ADVISOR1',
              '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
              '--episode','--test-scenario',scenario]
    result=engine_probe.main()
    print(json.dumps({'type':'mechanical_case_finished','scenario':scenario,'exit_code':result}),flush=True)
    if result:
        raise SystemExit(result)
