"""Prepare one-use M12 only when root dispatches this script. Never runs it."""
from pathlib import Path
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'tools/advisor_eval/development299'))
from cycle import register
from startup_receipt import load_observed_receipt


def main():
    record_path = Path(sys.argv[1]).resolve()
    record = json.loads(record_path.read_text(encoding='utf-8'))
    policy = record_path.parent/'policy'
    hashes = record['policy']['policy_files']
    for name in ('Brainstorm/Core/collection_search_product.lua', 'Brainstorm/Advisor/collection_search.lua',
                 'Brainstorm/Advisor/normal_opening.lua', 'Brainstorm/Advisor/gold_stickers.lua',
                 'Brainstorm/Advisor/gold_search.lua'):
        assert name in hashes and hashlib.sha256((policy/name).read_bytes()).hexdigest() == hashes[name]
    evidence = ROOT/'tools/advisor_eval/runs/gold299_20260914/S05'
    observed = load_observed_receipt(evidence)
    files = {p.name: p for p in (HERE/'adapter').iterdir() if p.is_file() and p.suffix in ('.lua', '.py')}
    for name in ('worker.py', 'startup_fixture.lua', 'startup_receipt.py', 'spec.md',
                 'original_adapter_hashes.json', 'synthetic_fixture_report.json'):
        files[name] = HERE/name
    for name in observed['binding']['files']:
        files['evidence/S05/'+name] = evidence/name
    files['evidence/S05/audit.json'] = evidence/'audit.json'
    for name in ('normal_opening_recipe.json', 'normal_seed_selection.json'):
        files['evidence/S05/'+name] = HERE.parent/'search05'/'selection'/name
    files['frozen_product_record.json'] = record_path
    files.update({'policy/'+name: policy/name for name in hashes})
    install = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
    folder = register('M12', files, [sys.executable, '-B', '-u', '{job}/worker.py'], {
        'hypothesis': 'The frozen collection search product facade launches the observed searched seed using authentic Game.delete_run/start_run and Back, retaining Red/Gold/unseeded filtered flags and a valid two-Soul opening binding.',
        'mechanical_boundary': 'Initialize ordinary Red Gold with STARTUP1, inject already-observed S05 receipt through an explicit stand-in, launch once via the frozen facade, and stop at untouched Small Blind before any advisor action.',
        'bootstrap_seed': 'STARTUP1', 'requested_seed': observed['result']['seed'],
        'observed_receipt': observed['binding'], 'native_search_in_component': False,
        'search_runtime': 'Injected already-observed receipt; no LOVE thread, FFI, worker or new native call',
        'inactive_query_difference': 'Fresh loaded synthetic missing-name list is retained by actual query builder; S05 had empty list. minimum_distinct=0 disables this field in both queries.',
        'maximum_advisor_actions': 0, 'maximum_product_launches': 1,
        'maximum_post_launch_presentation_ticks': 1200, 'outer_cap_seconds': 30,
        'policy_digest': record['policy']['policy_digest'], 'product_record_sha256': hashlib.sha256(record_path.read_bytes()).hexdigest(),
        'profile': 'all_unlocked_discovered_v1; actual source-loaded fresh in-memory progress, no altered Gold records',
        'source_access': 'Executable ZIP and isolated lua51.dll; original source methods execute only inside this registered component',
        'save_access': 'none; inherited isolated source filesystem stubs and F_NO_SAVING retained',
        'no_terminal_state_injection': True, 'no_gameplay_actions': True,
        'qualification': False, 'full_autoplay_qualified': False,
        'limits': 'Startup mechanics only; no new seed discovery, Soul acquisition, final outcome, player progress or achievement claim. Any error/unsupported/timeout remains preserved as spent evidence.',
    }, external=[install/'Balatro.exe', install/'lua51.dll', Path(sys.executable)])
    print(folder/'registration.json')


if __name__ == '__main__':
    main()
