"""Prepare a fresh M17 UI-button lifecycle adapter; never register or execute it."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = ROOT / "tools/advisor_eval/runs/gold299_20260914/M12"

def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)

def main():
    adapter = HERE / "adapter"
    adapter.mkdir(exist_ok=False)
    names = ("engine_probe.py", "engine_probe.lua", "engine_run.lua", "engine_contract.lua",
             "opening_support.py", "benchmark.py", "normal_recipe.py", "normal_terminal.lua",
             "startup_receipt.py")
    originals = {}
    for name in names:
        raw = (OLD / name).read_bytes()
        originals[name] = hashlib.sha256(raw).hexdigest()
        text = raw.decode("utf-8").replace("collection_product_startup", "collection_button_startup")
        if name == "engine_probe.py":
            text = change(text, '    args = parser.parse_args()',
                '    parser.add_argument("--startup-case", choices=("manual", "auto"), required=True)\n'
                '    args = parser.parse_args()\n'
                '    if args.test_scenario != "collection_button_startup":\n'
                '        parser.error("M17 adapter is limited to its registered startup scenario")')
            text = change(text, "            fixture = Path(__file__).with_name('startup_fixture.lua').read_bytes()",
                '''            chunks.append(b'PROBE_STARTUP_CASE=' + lua_value(args.startup_case))
            for relative, module in (
                ('Core/auto_run_product.lua', 'probe_auto_run_product'),
                ('Core/auto_terminal.lua', 'probe_auto_terminal'),
                ('UI/collection_run.lua', 'probe_collection_run_ui')):
                extra = args.policy_root/'Brainstorm'/relative
                content = extra.read_bytes()
                assert hashlib.sha256(content).hexdigest() == product_hashes[extra.relative_to(args.policy_root).as_posix()]
                chunks.append(b'package.preload[' + literal(module.encode()) + b']=assert(loadstring(' + literal(content) + b',' + literal(('@policy/' + relative).encode()) + b'))')
            fixture = Path(__file__).with_name('startup_fixture.lua').read_bytes()''')
            text = change(text, "'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],",
                "'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],\n"
                "                'startup_case': args.startup_case,\n"
                "                'mechanical_context': 'M17 actual product UI callback, source menu/close/controller phases, observed S05 receipt stand-in; no native search or gameplay action.',")
        elif name == "engine_run.lua":
            text = change(text, 'trace=trace,until_state=until_state,input_ready=input_ready,',
                          'trace=trace,until_state=until_state,input_ready=input_ready,tick=tick,')
        (adapter / name).write_text(text, encoding="utf-8", newline="\n")
    with (HERE / "parent_evidence_hashes.json").open("x", encoding="utf-8") as stream:
        json.dump(originals, stream, indent=2)
        stream.write("\n")
    print("Prepared M17 adapter copies only. No registration, original-source execution or native call.")

if __name__ == "__main__":
    main()
