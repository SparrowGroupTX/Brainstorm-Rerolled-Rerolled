#!/usr/bin/env python3
"""Source-check executable copy preparations in a hidden bounded Lua DLL worker."""
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
def sha(value): return hashlib.sha256(value).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--policy-root',type=Path,default=ROOT)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    files={name:(args.policy_root/'Brainstorm/Advisor'/name).read_bytes() for name in ('blind_prep.lua','blind_start.lua')}
    files.update({'blind_copy_source_parity.py':Path(__file__).read_bytes(),
                  'blind_copy_source_parity.lua':Path(__file__).with_suffix('.lua').read_bytes(),
                  'blind_start_source_parity.lua':Path(__file__).with_name('blind_start_source_parity.lua').read_bytes(),
                  'run_lua_tests.py':(ROOT/'tests/run_lua_tests.py').read_bytes()})
    for name,data in files.items(): (out/name).write_bytes(data)
    with zipfile.ZipFile(args.install/'Balatro.exe') as archive:
        card=archive.read('card.lua');misc=archive.read('functions/misc_functions.lua')
    chunks=['Card={}']
    for signature in ('function Card:calculate_joker(','function Card:remove_from_deck('): chunks.append(function_source(card.decode(),signature))
    chunks.append(function_source(misc.decode(),'function playing_card_joker_effects('))
    chunks.append('PROBE_MODULE='+json.dumps(str(out/'blind_start.lua').replace('\\','/')))
    chunks.append('PREP_MODULE='+json.dumps(str(out/'blind_prep.lua').replace('\\','/')))
    chunks.append(files['blind_start_source_parity.lua'].decode())
    chunks.append(files['blind_copy_source_parity.lua'].decode())
    harness='\n'.join(chunks).encode();(out/'source_probe.lua').write_bytes(harness)
    report={'schema':1,'frozen_sha256':{k:sha(v) for k,v in files.items()},
            'source_card_sha256':sha(card),'source_misc_sha256':sha(misc),
            'generated_probe_sha256':sha(harness),'source_execution':'isolated lua51.dll','timeout_seconds':30,
            'scope':'Original callbacks before/after actual advised legal copy preparations; no episodes or wins.'}
    started=time.perf_counter()
    try:
        result=subprocess.run([sys.executable,str(out/'run_lua_tests.py'),'--lua-library',str(args.install/'lua51.dll'),str(out/'source_probe.lua')],
                              cwd=ROOT,capture_output=True,text=True,timeout=30,
                              creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        report['status']='passed' if result.returncode==0 else 'failed';report['returncode']=result.returncode
        log=result.stdout+result.stderr
        match=re.search(r'blind-copy source parity: (\d+) proposals, (\d+) cases, (\d+) comparisons',log)
        if match: report['proposals'],report['cases'],report['comparisons']=map(int,match.groups())
    except subprocess.TimeoutExpired as error: report['status']='timeout';log=str(error)
    report['wall_seconds']=time.perf_counter()-started
    (out/'output.log').write_text(log,encoding='utf-8');(out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2),flush=True)
    return 0 if report['status']=='passed' else 1
if __name__=='__main__': raise SystemExit(main())
