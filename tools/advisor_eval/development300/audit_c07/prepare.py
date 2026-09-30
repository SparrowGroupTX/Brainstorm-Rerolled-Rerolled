"""Create distinct C07 read-only audit tooling from preserved C06 helpers."""
from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
OLD = HERE.parent / 'audit_c06'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    origins = {}
    for name in ('audit.py', 'validation.py'):
        path = OLD / name
        text = path.read_text()
        origins[name] = {'source': str(path), 'sha256': sha(path)}
        text = text.replace('C06', 'C07').replace('frozen315', 'frozen320')
        if name == 'audit.py':
            text = text.replace('e591f83e9b8bdcdbba288ff199836db12d40711d9b38b0df958c350bbbd0228f',
                                'e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966')
            text = text.replace('from validation import verify_gold_callbacks, verify_manifest, verify_wiring',
                                'from validation import verify_gold_callbacks, verify_manifest, verify_wiring\nfrom mechanics import actual_mechanics, verify_graph_receipt')
            needle = "    provenance = sole('engine_probe_provenance')"
            assert needle in text
            text = text.replace(needle, "    graph_receipt, graph_issues = verify_graph_receipt(FOLDER, registration, EXPECTED['policy'])\n    for reason in graph_issues:\n        check(False, reason)\n" + needle)
            needle = "    audit = {"
            assert needle in text
            text = text.replace(needle, "    mechanics, mechanics_issues = actual_mechanics(index, completed, contexts)\n    for issue in mechanics_issues:\n        check(False, issue['reason'], issue.get('step'))\n" + needle)
            text = text.replace("'gold_callback_audit': gold_callback_audit,", "'gold_callback_audit': gold_callback_audit, 'actual_mechanics': mechanics, 'installed_graph_audit': graph_receipt,")
            text = text.replace('previously used by C01/C02/C04.', 'previously used by C01/C02/C04/C06.')
            text = text.replace("Path(__file__).with_name('validation.py'))", "Path(__file__).with_name('validation.py'), Path(__file__).with_name('mechanics.py'))")
        else:
            text = text.replace("'2.115.0-alpha'", "'2.120.0-alpha'")
            text = text.replace("metadata.get('checkpoint') == 315", "metadata.get('checkpoint') == 320")
            text = text.replace("'complete_source_policy_wiring_315_v1'", "'complete_source_policy_wiring_c07_v1'")
            text = text.replace('Wrong315 wiring contract', 'Wrong C07 wiring contract')
        ast.parse(text)
        with (HERE / name).open('x', encoding='utf-8') as stream:
            stream.write(text)
    with (HERE / 'origins.json').open('x', encoding='utf-8') as stream:
        json.dump({'kind': 'read_only_auditor_preparation', 'source_helpers': origins,
                   'executed_source_or_policy': False, 'outcome_assessed': False}, stream, indent=2)
    print('C07 read-only auditor copies prepared; no record or trace evaluated.')


if __name__ == '__main__':
    main()
