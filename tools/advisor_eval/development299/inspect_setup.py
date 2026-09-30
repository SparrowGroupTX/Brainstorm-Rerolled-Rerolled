"""Registered mechanical setup probe; executable read as ZIP, never launched."""
from pathlib import Path
import zipfile
import sys

with zipfile.ZipFile('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe') as archive:
    for name,needles in {'game.lua':['function Game:start_run','set_deck_win','selected_back ='],
        'functions/common_events.lua':['function set_deck_win','function set_joker_win']}.items():
        lines=archive.read(name).decode().splitlines()
        for needle in needles:
            for index,line in enumerate(lines):
                if needle in line:
                    print('SOURCE_REFERENCE',name,index+1,needle,flush=True)
                    print('\n'.join(lines[max(0,index-2):index+28]),flush=True)
import engine_probe
sys.argv=[sys.argv[0],'--deck','b_red','--stake','8','--seed','ADVISOR1',
    '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(Path(__file__).parent/'policy')]
raise SystemExit(engine_probe.main())
