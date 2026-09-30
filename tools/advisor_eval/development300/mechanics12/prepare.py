"""Create fresh, mechanically scoped adapter copies. Does not register or run."""
from pathlib import Path
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT/'tools/advisor_eval/development299/normal_adapter'


def replace_once(text, old, new):
    assert text.count(old) == 1, 'Expected unique adapter insertion point'
    return text.replace(old, new, 1)


def main():
    destination = HERE/'adapter'
    destination.mkdir(exist_ok=False)
    originals = {}
    for source in sorted(SOURCE.iterdir()):
        if source.is_file() and source.suffix in ('.lua', '.py'):
            originals[source.name] = hashlib.sha256(source.read_bytes()).hexdigest()
            shutil.copyfile(source, destination/source.name)
    probe = (destination/'engine_probe.py').read_text(encoding='utf-8')
    probe = replace_once(probe, '"forced_selection", "ui_object_lifecycle"),',
        '"forced_selection", "ui_object_lifecycle", "collection_product_startup"),')
    probe = replace_once(probe, '"normal_recipe.py", "normal_terminal.lua")}',
        '"normal_recipe.py", "normal_terminal.lua", "startup_fixture.lua", "startup_receipt.py")}')
    needle = '        assert product_hashes == policy_hashes(args.policy_root), "Product changed during loading"'
    insertion = '''        if args.test_scenario == 'collection_product_startup':
            from startup_receipt import load_observed_receipt
            observed = load_observed_receipt(Path(__file__).parent/'evidence'/'S05')
            chunks.append(b'PROBE_COLLECTION_OBSERVED_RECEIPT=' + lua_value(observed))
            source = args.policy_root/'Brainstorm'/'Core'/'collection_search_product.lua'
            content = source.read_bytes()
            assert hashlib.sha256(content).hexdigest() == product_hashes[source.relative_to(args.policy_root).as_posix()]
            chunks.append(b'package.preload.probe_collection_search_product=assert(loadstring(' + literal(content) + b",'@policy/Core/collection_search_product.lua'))")
            fixture = Path(__file__).with_name('startup_fixture.lua').read_bytes()
            chunks.append(b'package.preload.probe_collection_startup_fixture=assert(loadstring(' + literal(fixture) + b",'@mechanical/startup_fixture.lua'))")
            provenance['collection_startup_mechanical'] = {
                'scope': 'Authentic source Game.delete_run/start_run and Back via frozen product facade; zero advisor actions',
                'observed_receipt': observed['binding'], 'native_search_executed': False,
                'search_runtime': 'Declared observed-S05 receipt stand-in; no worker/thread/native invocation',
                'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],
                'inactive_query_difference': 'The actual loaded synthetic missing-name list is present; S05 had an empty list. minimum_distinct=0 disables this field in both queries.',
                'qualification': False}
'''
    probe = replace_once(probe, needle, insertion+needle)
    (destination/'engine_probe.py').write_text(probe, encoding='utf-8', newline='\n')
    run = (destination/'engine_run.lua').read_text(encoding='utf-8')
    run = replace_once(run, 'if PROBE_DECK and PROBE_TEST_SCENARIO then',
        "if PROBE_DECK and PROBE_TEST_SCENARIO and PROBE_TEST_SCENARIO~='collection_product_startup' then")
    run = replace_once(run, "    if PROBE_TEST_SCENARIO=='ui_object_lifecycle' then", '''    if PROBE_TEST_SCENARIO=='collection_product_startup' then
        require('probe_collection_startup_fixture')({G=G,modules=modules,snapshot=snapshot,
            trace=trace,until_state=until_state,input_ready=input_ready,
            score_calls=function()return score_calls end})
        return
    elseif PROBE_TEST_SCENARIO=='ui_object_lifecycle' then''')
    (destination/'engine_run.lua').write_text(run, encoding='utf-8', newline='\n')
    with (HERE/'original_adapter_hashes.json').open('x', encoding='utf-8') as stream:
        json.dump(originals, stream, indent=2); stream.write('\n')
    print('Prepared M12 adapter copies; no registration or execution.')


if __name__ == '__main__':
    main()
