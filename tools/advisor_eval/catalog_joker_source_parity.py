#!/usr/bin/env python3
"""Check prospective Joker construction against original source, with no game launch."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
from discard_source_parity import function_source

ROOT=Path(__file__).resolve().parents[2]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--policy-root',type=Path,default=ROOT)
    parser.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    with zipfile.ZipFile(args.install/'Balatro.exe') as z:
        card=z.read('card.lua');game=z.read('game.lua');common=z.read('functions/common_events.lua')
    prototypes=[(m[1],m[2]) for m in re.finditer(r'^\s+(j_\w+)\s*=\s*(\{.*\}),?\s*$',game.decode(),re.M)
                if "set = 'Joker'" in m[2] or 'set = "Joker"' in m[2]]
    if len(prototypes)!=150:raise ValueError('Original Joker prototype layout changed')
    module=(args.policy_root/'Brainstorm/Advisor/catalog_joker.lua').read_bytes()
    fixture=Path(__file__).with_suffix('.lua').read_bytes()
    runner=(ROOT/'tests/run_lua_tests.py').read_bytes()
    callback='Card={}\n'+function_source(card.decode(),'function Card:set_ability(')+'\n'+function_source(card.decode(),'function Card:set_cost(')+'\n'+function_source(common.decode(),'function poll_edition(')
    harness=(callback+'\nPROBE_CENTERS={\n'+''.join(key+'='+value+',\n' for key,value in prototypes)+'}\n'+
             'PROBE_MODULE='+json.dumps(str(out/'catalog_joker.lua').replace('\\','/'))+'\n'+fixture.decode()).encode()
    values={'catalog_joker.lua':module,'source_probe.lua':harness,'fixture.lua':fixture,'run_lua_tests.py':runner,
            'workflow.py':Path(__file__).read_bytes()}
    for name,value in values.items():(out/name).write_bytes(value)
    sha=lambda b:hashlib.sha256(b).hexdigest()
    report={'schema':1,'qualification':False,'timeout_seconds':15,'source_execution':'isolated lua51.dll',
            'files':{name:sha(value) for name,value in values.items()},'original_card_sha256':sha(card),
            'original_game_sha256':sha(game),'original_common_events_sha256':sha(common),
            'runtime_sha256':sha((args.install/'lua51.dll').read_bytes())}
    started=time.perf_counter()
    try:
        r=subprocess.run([sys.executable,str(out/'run_lua_tests.py'),'--lua-library',str(args.install/'lua51.dll'),
                          str(out/'source_probe.lua')],cwd=ROOT,capture_output=True,text=True,timeout=15,
                          creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        log=r.stdout+r.stderr;report.update(outcome='passed' if r.returncode==0 else 'failed',exit_code=r.returncode)
        match=re.search(r'catalog source parity: (\d+) Jokers, (\d+) comparisons',log)
        if match:report['jokers'],report['comparisons']=map(int,match.groups())
    except subprocess.TimeoutExpired as e:log=str(e);report['outcome']='timeout'
    report['elapsed_seconds']=time.perf_counter()-started
    (out/'output.log').write_text(log,encoding='utf-8');(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2));return 0 if report['outcome']=='passed' else 1


if __name__=='__main__':raise SystemExit(main())
