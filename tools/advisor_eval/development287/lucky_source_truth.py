"""Build a bounded Lucky source-method probe; never execute it or create authority.

The root coordinator must register/freeze every input and consume a new one-use
30s B1/B2 job before executing the generated Lua. Source reads here accept an
already-extracted directory only; this tool cannot open an executable ZIP or DLL.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
SIGNATURES = {
    'card.lua': (
        'function Card:get_chip_bonus(', 'function Card:get_chip_mult(',
        'function Card:get_chip_x_mult(', 'function Card:get_p_dollars(',
        'function Card:calculate_seal(', 'function Card:calculate_joker(',
        'function Card:get_edition(',
    ),
    'functions/common_events.lua': ('function eval_card(',),
}


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def extract(source: str, signature: str) -> str:
    if source.count(signature) != 1:
        raise ValueError(f'Expected exactly one signature: {signature}')
    start = source.index(signature)
    following = re.search(r'\n(?:function |G\.FUNCS\.\w+\s*=\s*function)', source[start + len(signature):])
    if not following:
        raise ValueError(f'Missing function boundary after {signature}')
    return source[start:start + len(signature) + following.start()]


def literal(raw: bytes) -> bytes:
    # Decimal byte escapes work across Lua 5.1 and avoid delimiter injection.
    return b'"' + b''.join(('\\%03d' % byte).encode() for byte in raw) + b'"'


def build_probe(policy_root: Path, source_root: Path, mode: str) -> tuple[bytes, dict]:
    if mode not in ('ordinary', 'red'):
        raise ValueError('Mode must be ordinary or red')
    chunks = [b'Card={};G={}']
    evidence = {'mode': mode, 'cases': 4 if mode == 'ordinary' else 16,
                'source_files': {}, 'source_functions': {}, 'policy_files': {},
                'qualification': False, 'execution_authority': None,
                'scope': 'conditional_original_card_methods_and_eval_card_only',
                'test_doubles': ['event scheduling', 'final chip/mult arithmetic', 'returned cash application']}
    for name, signatures in SIGNATURES.items():
        raw = (source_root / name).read_bytes()
        evidence['source_files'][name] = sha(raw)
        for signature in signatures:
            function = extract(raw.decode('utf-8'), signature).encode('utf-8')
            evidence['source_functions'][signature] = sha(function)
            chunks.append(function)
    for name, global_name in [('scoring', 'POLICY_SCORING'), ('snapshot', 'POLICY_SNAPSHOT')]:
        path = f'Brainstorm/Advisor/{name}.lua'
        raw = (policy_root / path).read_bytes()
        evidence['policy_files'][path] = sha(raw)
        chunks.append(global_name.encode() + b'=assert(loadstring(' + literal(raw)
                      + b',"@frozen/' + name.encode() + b'.lua"))()')
    harness = (HERE / 'lucky_source_truth.lua').read_bytes()
    evidence['harness_sha256'] = sha(harness)
    evidence['builder_sha256'] = sha(Path(__file__).read_bytes())
    chunks.append(b'local harness=assert(loadstring(' + literal(harness) + b',"@registered_lucky_truth.lua"))()')
    chunks.append(b'''local function json(v)
 if v==nil then return 'null' end
 if type(v)=='number' then assert(v==v and math.abs(v)<math.huge);return tostring(v) end
 if type(v)=='boolean' then return tostring(v) end
 if type(v)=='string' then return '"'..v:gsub('[%z\\1-\\31\\\\"]',function(c) return string.format('\\\\u%04x',string.byte(c)) end)..'"' end
 assert(type(v)=='table','Unsupported JSON value')
 local array=#v>0;local out={}
 if array then for _,x in ipairs(v) do out[#out+1]=json(x) end
 else local keys={};for k in pairs(v) do assert(type(k)=='string');keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys) do out[#out+1]=json(k)..':'..json(v[k]) end end
 return (array and '[' or '{')..table.concat(out,',')..(array and ']' or '}')
end''')
    chunks.append(b'harness.run(' + literal(mode.encode()) + b',function(row) print(json(row));io.stdout:flush() end)')
    probe = b'\n'.join(chunks)
    evidence['generated_probe_sha256'] = sha(probe)
    return probe, evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy', type=Path, required=True)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--mode', choices=('ordinary', 'red'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    probe, evidence = build_probe(args.policy, args.source_dir, args.mode)
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'source_probe.lua').write_bytes(probe)
    (args.output / 'preparation.json').write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
