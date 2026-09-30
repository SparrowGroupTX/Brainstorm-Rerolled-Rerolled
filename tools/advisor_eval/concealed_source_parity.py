#!/usr/bin/env python3
"""Freeze and check concealment likelihoods in a bounded, hidden Lua DLL worker.

Reads Balatro.exe as a ZIP only; never starts the game or reads saves.
Synthetic observations are mechanics checks, not episode or win evidence.
"""
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
def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--policy-root',type=Path,default=ROOT)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    files={'concealed_belief.lua':(args.policy_root/'Brainstorm/Advisor/concealed_belief.lua').read_bytes(),
           'concealed_source_parity.py':Path(__file__).read_bytes(),
           'concealed_source_parity.lua':Path(__file__).with_suffix('.lua').read_bytes(),
           'run_lua_tests.py':(ROOT/'tests/run_lua_tests.py').read_bytes()}
    for name,data in files.items(): (out/name).write_bytes(data)
    with zipfile.ZipFile(args.install/'Balatro.exe') as archive:
        source={name:archive.read(name) for name in ('blind.lua','card.lua','cardarea.lua','functions/misc_functions.lua')}
    chunks=['Card={}; Blind={}; CardArea={}']
    for path,signature in [('blind.lua','function Blind:stay_flipped('),('card.lua','function Card:is_face('),
                           ('card.lua','function Card:get_id('),('cardarea.lua','function CardArea:draw_card_from('),
                           ('functions/misc_functions.lua','function find_joker(')]:
        chunks.append(function_source(source[path].decode(),signature))
    chunks.append('PROBE_MODULE='+json.dumps(str(out/'concealed_belief.lua').replace('\\','/')))
    chunks.append(files['concealed_source_parity.lua'].decode())
    harness='\n'.join(chunks).encode();(out/'source_probe.lua').write_bytes(harness)
    report={'schema':1,'frozen_sha256':{k:sha(v) for k,v in files.items()},
            'source_sha256':{k:sha(v) for k,v in source.items()},'generated_probe_sha256':sha(harness),
            'source_execution':'isolated lua51.dll','timeout_seconds':30,
            'scope':'Concealment observation likelihoods only; synthetic source mechanics, no wins.'}
    started=time.perf_counter()
    try:
        result=subprocess.run([sys.executable,str(out/'run_lua_tests.py'),'--lua-library',str(args.install/'lua51.dll'),str(out/'source_probe.lua')],
                              cwd=ROOT,capture_output=True,text=True,timeout=30,
                              creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        report['status']='passed' if result.returncode==0 else 'failed';report['returncode']=result.returncode
        log=result.stdout+result.stderr
        match=re.search(r'concealed source parity: (\d+) cases, (\d+) comparisons',log)
        if match: report['cases'],report['comparisons']=map(int,match.groups())
    except subprocess.TimeoutExpired as error:
        report['status']='timeout';log=str(error)
    report['wall_seconds']=time.perf_counter()-started
    (out/'output.log').write_text(log,encoding='utf-8')
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2),flush=True)
    return 0 if report['status']=='passed' else 1

if __name__=='__main__': raise SystemExit(main())
