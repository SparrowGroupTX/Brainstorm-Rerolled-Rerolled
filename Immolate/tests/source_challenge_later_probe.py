#!/usr/bin/env python3
"""Bounded original Lua generation parity for conditional later Rare offers.

Runs only source read from the executable ZIP through isolated lua51.dll; never
launches the executable or reads saves. Synthetic profiles are mechanics fixtures.
The parent must supply a fresh output directory and an explicit subprocess cap.
"""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
KEYS = 'j_dna j_vagabond j_baron j_obelisk j_baseball j_ancient j_campfire j_blueprint j_wee j_hit_the_road j_duo j_trio j_family j_order j_tribe j_stuntman j_invisible j_brainstorm j_drivers_license j_burnt'.split()
IDS = 'omelette city rich knife xray mad_world luxury non_perishable medusa double_nothing typecast inflation fragile monolith blast_off five_card golden_needle cruelty'.split()

def literal(data: bytes) -> bytes:
    sep = b'='
    while b']' + sep + b']' in data:
        sep += b'='
    return b'[' + sep + b'[' + data + b']' + sep + b']'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--native', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    ap.add_argument('--single', action='store_true', help='One diagnostic fixture; no broad search')
    ap.add_argument('--targeted', action='store_true', help='Seven additional profile/capacity fixtures')
    ap.add_argument('--seed', choices=('I1L21111','9CISW211'), default='I1L21111')
    ap.add_argument('--boundary-only', action='store_true', help='One original Riff-Raff stream-separation boundary; no native calls')
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    started = time.perf_counter()
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        sources = {name: archive.read(name) for name in archive.namelist() if name.endswith('.lua')}
        dimensions = {}
        for name in archive.namelist():
            if name.endswith('.png'):
                with archive.open(name) as png:
                    header = png.read(24)
                if header[:8] == b'\x89PNG\r\n\x1a\n':
                    dimensions[name] = struct.unpack('>II', header[16:24])
    core = (ROOT / 'Brainstorm/Core/Brainstorm.lua').read_bytes()
    hook = core[core.index(b'function Brainstorm.createCharmArcanaCard('):core.index(b'function Brainstorm.init()')]
    bootstrap = (ROOT / 'tools/advisor_eval/engine_probe.lua').read_bytes()
    payload = Path(__file__).with_suffix('.lua').read_bytes()
    ui = sources['functions/UI_definitions.lua']
    shop = ui[ui.index(b'function create_card_for_shop('):ui.index(b'function create_shop_card_ui(')]
    provenance = dict(scope='original_source_generation_only_not_run_or_acquisition', seed=args.seed,
        native_sha256=sha(args.native.read_bytes()), hook_sha256=sha(hook), bootstrap_sha256=sha(bootstrap),
        payload_sha256=sha(payload), harness_sha256=sha(Path(__file__).read_bytes()), shop_sha256=sha(shop),
        runtime_sha256=sha((args.install/'lua51.dll').read_bytes()),
        source_sha256={name: sha(data) for name, data in sources.items()},
        max_cases=57, max_cards_per_case=44, max_native_calls=1200,
        profile='source_defaults_v1 or all_unlocked_discovered_v1; limited fixture locks all Rare except Blueprint',
        currency_fixture=1000, trades='optional actual visible Common/Uncommon buy-and-sell callbacks',
        limits='Generation only; no played blinds, acquisition route, retention or win-rate qualification')
    (args.output/'provenance.json').write_text(json.dumps(provenance, indent=2))
    base = [b'PROBE_PNG={}']
    for name, (w, h) in dimensions.items():
        base.append(b'PROBE_PNG[ '+literal(name.encode())+b' ]={'+str(w).encode()+b','+str(h).encode()+b'}')
    for name, source in sources.items():
        base.append(b'package.preload[ '+literal(name[:-4].encode())+b' ]=assert(loadstring('+literal(source)+b','+literal(b'@original/'+name.encode())+b'))')
    base += [b'PROBE_CHARM_HOOK='+literal(hook), b'PROBE_CREATE_SHOP='+literal(shop),
             b'PROBE_SEED='+literal(args.seed.encode()), b'PROBE_EPISODE='+literal(payload),
             b'PROBE_RECORD_PROFILE=function(text) PROBE_DECLARED_PROFILE_TEXT=text;return 1 end']
    os.environ['BRAINSTORM_THREADS'] = '1'
    os.environ['BRAINSTORM_SEARCH_LIMIT'] = '1'
    handles = []
    if os.name == 'nt':
        handles += [os.add_dll_directory(str(args.native.resolve().parent)),
                    os.add_dll_directory(str(Path(shutil.which('g++')).resolve().parent))]
    native = ctypes.CDLL(str(args.native.resolve()))
    native.brainstorm_challenge_opening_v2.argtypes = [ctypes.c_char_p]*4+[ctypes.c_int,ctypes.c_char_p]
    native.brainstorm_challenge_opening_v2.restype = ctypes.c_void_p
    native.free_result.argtypes = [ctypes.c_void_p]
    lua = ctypes.CDLL(str((args.install/'lua51.dll').resolve()))
    lua.luaL_newstate.restype = ctypes.c_void_p
    for fn in ('luaL_openlibs','lua_close'):
        getattr(lua,fn).argtypes = [ctypes.c_void_p]
    lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
    lua.luaL_loadbuffer.restype = ctypes.c_int
    lua.lua_pcall.argtypes = [ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
    lua.lua_getfield.argtypes = [ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_void_p
    def text_at(state):
        n = ctypes.c_size_t()
        ptr = lua.lua_tolstring(state,-1,ctypes.byref(n))
        return ctypes.string_at(ptr,n.value).decode('utf8','replace') if ptr else ''
    def global_text(state,key):
        lua.lua_getfield(state,-10002,key.encode())
        return text_at(state)
    cases = [(f'c_{name}_1', mode, False) for name in IDS for mode in ('all','defaults','limited')]
    cases += [(f'c_{name}_1','all',True) for name in ('xray','rich','inflation')]
    if args.single:
        cases = cases[:1]
    if args.targeted:
        cases = [('c_xray_1','all',False),('c_xray_1','limited',False),
                 ('c_blast_off_1','all',False),('c_blast_off_1','limited',False),
                 ('c_non_perishable_1','all',False),('c_monolith_1','all',False),('c_xray_1','all',True)]
    if args.boundary_only:
        cases = [('c_xray_1','all',False)]
    results = []
    for challenge, mode, trade in cases:
        record = dict(challenge=challenge,mode=mode,trade=trade,status='started')
        output = args.output/f'{challenge}_{mode}_{int(trade)}.json'
        output.write_text(json.dumps(record,indent=2))
        profile = 'source_defaults_v1' if mode=='defaults' else 'all_unlocked_discovered_v1'
        code = b'\n'.join(base + [b'PROBE_CHALLENGE='+literal(challenge.encode()),
            b'PROBE_PROFILE_SPEC={schema=1,name='+literal(profile.encode())+b",scope={'P_CENTERS','P_TAGS','P_BLINDS'}}",
            b'PROBE_LIMITED='+(b'true' if mode=='limited' else b'false'),
            b'PROBE_ROLLOVER='+(b'true' if args.targeted and challenge=='c_xray_1' and mode=='all' and not trade else b'false'),
            b'PROBE_RIFF='+(b'true' if args.boundary_only else b'false'),
            b'PROBE_TRADE='+(b'true' if trade else b'false'),bootstrap])
        state = lua.luaL_newstate()
        assert state
        try:
            lua.luaL_openlibs(state)
            status = lua.luaL_loadbuffer(state,code,len(code),b'@source_challenge_later_probe')
            if not status:
                status = lua.lua_pcall(state,0,0,0)
            if status:
                raise RuntimeError(text_at(state))
            lines = global_text(state,'PROBE_LATER_TEXT').splitlines()
            mask, rows = lines[0], [line.split('|') for line in lines[1:]]
            protected,capacity,latest = map(int,global_text(state,'PROBE_CAPACITY_TEXT').split('|'))
            eligible = [r for r in rows if int(r[0])<=latest and protected<capacity+(r[4]=='negative')]
            record.update(mask=mask,offers=rows,trades=int(global_text(state,'PROBE_LATER_TRADES')),
                          capacity=dict(protected=protected,limit=capacity,latest=latest),eligible_offers=eligible,
                          original_boss_rollovers=global_text(state,'PROBE_ROLLOVER_TEXT'),
                          original_riff_generated=global_text(state,'PROBE_RIFF_TEXT'),
                          applied_profile_sha256=sha(global_text(state,'PROBE_DECLARED_PROFILE_TEXT').encode()))
            record['native'] = []
            for i,key in enumerate([] if args.boundary_only else KEYS):
                raw = native.brainstorm_challenge_opening_v2(args.seed.encode(),challenge.encode(),b'',key.encode(),8,mask.encode())
                assert raw
                result = json.loads(ctypes.string_at(raw));native.free_result(raw)
                record['native'].append(result)
                offered = next((r for r in eligible if r[3]==key),None)
                if mask[i]=='0':
                    assert result['status']=='invalid', result
                elif offered:
                    assert result['status']=='found', (key,offered,result)
                    actual = [str(result['later_found_ante']),str(result['later_shop']),str(result['later_slot']),result['later_target'],result['later_edition'],str(result['later_eternal']).lower()]
                    assert actual==offered, (actual,offered)
                    assert len(result)==24 and result['later_retention']=='not_verified'
                else:
                    assert result['status']=='not_found', (key,rows,result)
            if trade:
                baseline = next(r for r in results if r['challenge']==challenge and r['mode']==mode and not r['trade'])
                assert record['offers']==baseline['offers'], 'Common/Uncommon source trades changed Rare offers'
            record['status'] = 'pass'
        except BaseException as exc:
            record.update(status='error',error=repr(exc))
            raise
        finally:
            lua.lua_close(state)
            output.write_text(json.dumps(record,indent=2))
        results.append(record)
        print(json.dumps(dict(challenge=challenge,mode=mode,trade=trade,status='pass')),flush=True)
    summary = dict(status='pass',cases=len(results),native_calls=(0 if args.boundary_only else 20)*len(results),
                   source_cards=44*len(results),elapsed_seconds=time.perf_counter()-started,
                   scope='generation_only_no_acquisition_retention_survival_or_win_rate')
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary),flush=True)

if __name__=='__main__':
    main()
