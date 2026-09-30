"""Root registers M14 against exact repaired frozen product; no dispatch here."""
from pathlib import Path
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'tools/advisor_eval/development299'))
sys.path.insert(0, str(HERE/'adapter'))
from cycle import register
from startup_receipt import load_observed_receipt


def main():
    record_path = Path(sys.argv[1]).resolve()
    record = json.loads(record_path.read_text(encoding='utf-8')); policy = record_path.parent/'policy'
    hashes = record['policy']['policy_files']
    assert record['policy']['policy_digest'] == 'e553ec3b04ba3e020e4c5c7b690b1939ae686faa95b77f77de3c60591d764d8c'
    assert 'Brainstorm/Core/collection_search_product.lua' in hashes
    evidence = ROOT/'tools/advisor_eval/runs/gold299_20260914/S05'
    observed = load_observed_receipt(evidence)
    files = {p.name: p for p in (HERE/'adapter').iterdir() if p.is_file() and p.suffix in ('.lua', '.py')}
    for name in ('spec.md', 'parent_evidence_hashes.json', 'synthetic_fixture_report.json'):
        files[name] = HERE/name
    for name in observed['binding']['files']:
        files['evidence/S05/'+name] = evidence/name
    files['frozen_product_record.json'] = record_path
    files['evidence/M13/inspection.json'] = ROOT/'tools/advisor_eval/runs/gold299_20260914/M13/inspection/inspection.json'
    files['evidence/M13/audit.json'] = ROOT/'tools/advisor_eval/runs/gold299_20260914/M13/audit.json'
    files.update({'policy/'+name: policy/name for name in hashes})
    install = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
    folder = register('M14', files, [sys.executable, '-B', '-u', '{job}/worker.py'], {
        'hypothesis': 'Source-shaped persistent boot display cache reproduces frozen302 startup rejection, while repaired304 starts observed S05 through authentic Game.delete_run/start_run and Back and retains actual Small Charm.',
        'mechanical_boundary': 'M12 original-source initialization and observed-receipt stand-in; inject only G.LOADING={font=<inert display stand-in>}; baseline can_begin only, candidate launch exactly once; stop preblind.',
        'source_shape_evidence': 'M13 functions/misc_functions.lua boot_timer; original boot_timer is not itself executed in this component.',
        'initial_seed': 'STARTUP1', 'requested_seed': 'S7PXV521', 'observed_receipt': observed['binding'],
        'maximum_advisor_actions': 0, 'maximum_product_launches': 1, 'native_search_in_component': False,
        'baseline_product_sha256': hashlib.sha256((HERE/'adapter/baseline_collection_search_product.lua').read_bytes()).hexdigest(),
        'policy_digest': record['policy']['policy_digest'], 'outer_cap_seconds': 30,
        'profile': 'all_unlocked_discovered_v1, actual source-loaded fresh in-memory progress unchanged',
        'source_access': 'Executable ZIP and isolated lua51.dll under fresh one-use M14 authority only',
        'save_access': 'none; inherited isolated source no-save guards', 'qualification': False,
        'limits': 'Boot-cache startup comparison only; no actual game launch/control, pack opening, acquisition, terminal outcome or achievement. Main-menu lifecycle remains source-inspection plus pure-fixture evidence.',
    }, external=[install/'Balatro.exe', install/'lua51.dll', Path(sys.executable)])
    print(folder/'registration.json')


if __name__ == '__main__':
    main()
