"""Routine read-only evidence/AST/adapter checks; no source or native execution."""
from pathlib import Path
import ast
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
from startup_receipt import load_observed_receipt


def main():
    checks = 0
    def check(value):
        nonlocal checks
        checks += 1
        assert value
    for folder in (HERE, HERE/'adapter'):
        for path in folder.glob('*.py'):
            ast.parse(path.read_text(encoding='utf-8'), filename=str(path)); checks += 1
    originals = json.loads((HERE/'original_adapter_hashes.json').read_text(encoding='utf-8'))
    for name, expected in originals.items():
        check(hashlib.sha256((ROOT/'tools/advisor_eval/development299/normal_adapter'/name).read_bytes()).hexdigest() == expected)
    observed = load_observed_receipt(ROOT/'tools/advisor_eval/runs/gold299_20260914/S05')
    check(observed['result']['seed'] == 'S7PXV521')
    check(observed['binding']['native_search_executed_in_this_component'] is False)
    run = (HERE/'adapter'/'engine_run.lua').read_text(encoding='utf-8')
    check(run.count("require('probe_collection_startup_fixture')") == 1)
    check("PROBE_TEST_SCENARIO~='collection_product_startup' then\n    G.GAME.seeded=false" in run)
    probe = (HERE/'adapter'/'engine_probe.py').read_text(encoding='utf-8')
    check('"startup_fixture.lua", "startup_receipt.py")}' in probe)
    check("provenance['collection_startup_mechanical']" in probe)
    check("'@policy/Core/collection_search_product.lua'" in probe)
    receipt = (HERE/'startup_fixture.lua').read_text(encoding='utf-8')
    for prohibited in ('native_search(', 'G.FUNCS.skip_blind(', 'G.FUNCS.play_cards_from_highlighted(',
                       'G.GAME.won=true', 'G.GAME.seeded=false', 'profile.joker_usage='):
        check(prohibited not in receipt)
    with (HERE/'synthetic_fixture_report.json').open('x', encoding='utf-8') as stream:
        json.dump({'schema': 1, 'checks': checks, 'passed': True,
            'scope': 'Read-only S05 evidence validation, Python AST compilation, untouched original adapter hashes and explicit mechanical wiring',
            'source_execution': False, 'native_search': False, 'registration': False}, stream, indent=2)
        stream.write('\n')
    print(f'M12 preparation checks: {checks} passed; no source/native execution or registration.')


if __name__ == '__main__':
    main()
