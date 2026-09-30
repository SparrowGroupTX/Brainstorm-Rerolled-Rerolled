"""Prepare a detached normal-deck source adapter; no game/source execution."""
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent
dest=HERE/'normal_adapter'
dest.mkdir(exist_ok=False)
for name in ('engine_probe.py','engine_probe.lua','engine_run.lua','engine_contract.lua','opening_support.py','benchmark.py','development_report.py'):
    shutil.copyfile(SOURCE/name,dest/name)
def replace(name,old,new):
    path=dest/name;data=path.read_bytes();old=old.replace('\n','\r\n').encode() if b'\r\n' in data else old.encode()
    new=new.replace('\n','\r\n').encode() if b'\r\n' in data else new.encode()
    assert data.count(old)==1,(name,old[:60],data.count(old))
    path.write_bytes(data.replace(old,new))
replace('engine_probe.py','    parser.add_argument("--seed", default="ADVISOR1")',
    '    parser.add_argument("--seed", default="ADVISOR1")\n    parser.add_argument("--deck", choices=("b_red", "b_zodiac"))\n    parser.add_argument("--stake", type=int, choices=range(1,9), default=8)')
replace('engine_probe.py','    args = parser.parse_args()',
    '    args = parser.parse_args()\n    if args.deck:\n        if args.opening_targets is not None or args.jokerless_opening_recipe or args.replay_trace:\n            parser.error("Normal deck requires its separately declared route, not challenge/replay hooks")\n        args.challenge="normal"')
replace('engine_probe.py','    if selection: provenance[\'seed_selection\']=selection',
    '    if args.deck: provenance["normal_run"]={"deck":args.deck,"stake":args.stake,"qualification":False}\n    if selection: provenance[\'seed_selection\']=selection')
replace('engine_probe.py','    chunks.append(b"PROBE_SEED=" + literal(run_seed.encode()))',
    '    chunks.append(b"PROBE_SEED=" + literal(run_seed.encode()))\n    chunks.append(b"PROBE_DECK=" + lua_value(args.deck))\n    chunks.append(b"PROBE_STAKE=" + lua_value(args.stake))')
replace('engine_probe.lua',
    "    local challenge=G.CHALLENGES[tonumber(PROBE_CHALLENGE)]\n    for _,candidate in ipairs(G.CHALLENGES) do if candidate.id==PROBE_CHALLENGE then challenge=candidate end end\n    assert(challenge,'Unknown challenge: '..tostring(PROBE_CHALLENGE))\n    G:start_run({seed=PROBE_SEED,challenge=challenge})",
    "    if PROBE_DECK then\n        G.GAME.selected_back=Back(assert(G.P_CENTERS[PROBE_DECK],'Unknown ordinary deck'))\n        G:start_run({seed=PROBE_SEED,stake=PROBE_STAKE})\n        assert(G.GAME.challenge==nil and G.GAME.stake==PROBE_STAKE,'Normal stake initialization mismatch')\n        assert(G.GAME.selected_back.effect.center.key==PROBE_DECK,'Normal deck initialization mismatch')\n    else\n        local challenge=G.CHALLENGES[tonumber(PROBE_CHALLENGE)]\n        for _,candidate in ipairs(G.CHALLENGES) do if candidate.id==PROBE_CHALLENGE then challenge=candidate end end\n        assert(challenge,'Unknown challenge: '..tostring(PROBE_CHALLENGE))\n        G:start_run({seed=PROBE_SEED,challenge=challenge})\n    end")
print(dest)
