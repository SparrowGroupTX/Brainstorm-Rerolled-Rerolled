"""Create-only M20 draft from frozen M19 inputs plus a distinct reviewed candidate."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
M19 = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M19'
D19 = HERE.parent / 'cache_compare19'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def output(name, value):
    with (HERE / name).open('x', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, allow_nan=False);handle.write('\n')


def main():
    registered = json.loads((M19 / 'registration.json').read_text())
    unchanged = ('driver.lua', 'lua_bytes.py', 'module_setup.lua', 'engine_contract.lua',
                 'baseline_record.json', 'step85.json', 'step185.json')
    origins = []
    for name in unchanged:
        assert sha(M19 / name) == registered['files'][name]
        (HERE / name).open('xb').write((M19 / name).read_bytes())
        origins.append({'source': str((M19 / name).relative_to(ROOT)), 'draft': name, 'sha256': sha(M19 / name), 'changed': False})
    for old, new in (('compare_cache19.py', 'compare_cache20.py'), ('register.py', 'register.py'),
                     ('test_driver.lua', 'test_driver.lua'), ('test_spec.py', 'test_spec.py')):
        original = M19 / old if old == 'compare_cache19.py' else D19 / old
        text = original.read_text().replace('M19', 'M20').replace('cache_compare19', 'cache_compare20').replace('compare_cache19', 'compare_cache20')
        if new == 'register.py':
            text = text.replace('Replacing frozen309 saturated classification-cache entries FIFO, at the same8192 capacity, preserves full decisions while reducing avoidable misses on two selected C04 public hands.',
                                'Dense prime-indexed two-way exact-key replacement at the same8192 ceiling avoids sparse numeric-key deletion/insertion overhead while retaining later classifications; M19 FIFO was slower and is not installed.')
            text = text.replace("'cache_capacity': 8192,", "'cache_capacity': 8192, 'reachable_entries': 8186, 'ways': 2, 'prime_buckets': 4093,")
            text = text.replace("files['authority.json'] = RUNS / 'gold299_20260914/authority.json'",
                                "files['authority.json'] = RUNS / 'gold299_20260914/authority.json'\n    for old_name in ('audit.json','record.json','comparison.json','registration.json'):\n        files['M19_' + old_name] = RUNS / 'gold299_20260914/M19' / old_name")
            text = text.replace("'qualification': False, 'terminal_evidence': False,", "'prior_negative_evidence': 'Frozen M19 audit/record/comparison: fewer FIFO misses, slower on both pairs; no repeat of that candidate',\n                'negative_stop_rule': 'No further cache workers after M20 if negative',\n                'qualification': False, 'terminal_evidence': False,")
        elif new == 'test_spec.py':
            text = text.replace('from prepare_inputs import module_setup\n', '')
            text = text.replace("prefix, omitted = module_setup(runtime.read_bytes())\n        self.assertEqual(prefix, (HERE / 'module_setup.lua').read_bytes())\n        self.assertEqual(len(omitted), 5)",
                                "prefix = (HERE / 'module_setup.lua').read_bytes()\n        provenance = json.loads((HERE / 'input_provenance.json').read_text())\n        self.assertEqual(hashlib.sha256(prefix).hexdigest(), provenance['module_setup_sha256'])\n        self.assertEqual(hashlib.sha256(runtime.read_bytes()).hexdigest(), provenance['module_setup_parent_sha256'])\n        self.assertEqual(len(provenance['omitted_product_integrations']), 5)")
        (HERE / new).open('x', encoding='utf-8').write(text)
        origins.append({'source': str(original.relative_to(ROOT)), 'draft': new, 'source_sha256': sha(original), 'changed': True})
    baseline = json.loads((HERE / 'baseline_record.json').read_text())
    old = baseline['policy']['policy_files']
    cache = HERE.parent / 'cache_associative/score_cache.lua'
    change = json.loads((HERE.parent / 'cache_associative/manifest.json').read_text())
    assert old['Brainstorm/Advisor/score_cache.lua'] == change['base_sha256']
    assert sha(cache) == change['candidate_sha256']
    modified = dict(old, **{'Brainstorm/Advisor/score_cache.lua': sha(cache)})
    (HERE / 'candidate_score_cache.lua').open('xb').write(cache.read_bytes())
    output('candidate_record.json', {'schema': 1, 'kind': 'detached_single_cache_substitution',
           'mechanism': 'dense_prime_bucket_two_way_exact_full_key',
           'policy': {'policy_files': modified, 'policy_digest': hashlib.sha256(canonical(modified)).hexdigest()},
           'baseline_installed_record_sha256': baseline.get('baseline_installed_record_sha256') or sha(ROOT / 'tools/advisor_eval/runs/certificate309_installed/record.json'),
           'only_changed_file': 'Brainstorm/Advisor/score_cache.lua', 'configured_capacity': 8192,
           'reachable_entries': 8186, 'prime_buckets': 4093, 'ways': 2, 'installed': False, 'qualification': False})
    provenance = json.loads((M19 / 'input_provenance.json').read_text())
    provenance.update(kind='prepared_M20_captured_inputs', candidate_policy_digest=hashlib.sha256(canonical(modified)).hexdigest(),
                      prior_negative_evidence={name: sha(M19 / name) for name in ('audit.json', 'record.json', 'comparison.json', 'registration.json')},
                      distinct_candidate=True, captured_policy_evaluated=False,
                      stop_rule='Root will schedule no further cache workers after M20 if negative')
    output('input_provenance.json', provenance)
    output('preparation_origins.json', origins)
    print(json.dumps({'prepared': 'M20', 'snapshots': [85, 185], 'candidate_sha256': sha(cache),
                      'registered': False, 'policy_or_source_evaluation': False}))


if __name__ == '__main__':
    main()
