"""Read preserved source text and current native/UI names; execute none of them."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]


class SearchNames(unittest.TestCase):
    def test_complete_source_key_set_and_native_spellings(self):
        folder = ROOT / 'tools/advisor_eval/runs/roi247_catalog_source'
        source = (folder / 'source_probe.lua').read_bytes()
        record = json.loads((folder / 'report.json').read_text(encoding='utf-8'))
        self.assertEqual(hashlib.sha256(source).hexdigest(), record['files']['source_probe.lua'])
        expected = {}
        for key, line in re.findall(r'^(j_\w+)=(.*)$', source.decode(), re.M):
            match = re.search(r'\bname\s*=\s*(["\x27])(.*?)\1', line)
            if match:
                expected[key] = match[2]
        expected.update(j_caino='Canio', j_seance='Séance', j_riff_raff='Riff-Raff')
        module = (ROOT / 'tools/advisor_eval/development295/search_helper.lua').read_text(encoding='utf-8')
        actual = dict(re.findall(r'^(j_\w+)=(.+)$', module, re.M))
        self.assertEqual(len(expected), 150)
        self.assertEqual(actual, expected)
        ui = (ROOT / 'Brainstorm/UI/ui.lua').read_text(encoding='utf-8')
        choices = re.search(r'local joker_keys = \{(.*?)\n\}', ui, re.S)[1]
        labels = set(re.findall(r'"([^"]+)"', choices))
        self.assertTrue(set(actual.values()).issubset(labels))
        native = (ROOT / 'Immolate/src/items.hpp').read_text(encoding='utf-8')
        accepted = set()
        for expression in re.findall(r'if \(i == (.*?)\) \{', native, re.S):
            for arm in expression.split('||'):
                strings = re.findall(r'"((?:\\.|[^"\\])*)"', arm)
                value = ''.join(bytes(part, 'utf-8').decode('unicode_escape') for part in strings)
                accepted.add(value.encode('latin1').decode('utf-8'))
        self.assertTrue(set(actual.values()).issubset(accepted), sorted(set(actual.values()) - accepted))


if __name__ == '__main__':
    unittest.main()
