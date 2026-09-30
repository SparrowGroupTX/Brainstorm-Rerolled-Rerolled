"""Read and verify already-observed S05 evidence. No search, source or save access."""
from pathlib import Path
import hashlib
import json


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_observed_receipt(folder):
    folder = Path(folder)
    records = {name: json.loads((folder/name).read_text(encoding='utf-8')) for name in
               ('registration.json', 'record.json', 'spent.json', 'result.json', 'request.json')}
    registration, record, spent = (records[key] for key in ('registration.json', 'record.json', 'spent.json'))
    assert registration['job'] == record['job'] == spent['job'] == 'S05'
    assert record['status'] == 'complete' and record['exit_code'] == 0
    assert record['one_use_spent'] and record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert record['registration_sha256'] == spent['registration_sha256'] == sha(folder/'registration.json')
    assert record['trace_sha256'] == sha(folder/'trace.log')
    assert registration['files']['request.json'] == sha(folder/'request.json')
    request = records['request.json']
    assert request['job'] == 'S05' and request['start_index'] == 2000000001
    assert request['native_api_version'] == 9 and request['deck'] == 'Red Deck' and request['stake'] == 8
    assert request['targets'] == ['Yorick', 'Brainstorm', 'Burnt Joker', 'Perkeo', '']
    assert request['locations'] == ['soul_pack', 'by_ante_5', 'by_ante_5', 'soul_pack', 'ante_1']
    assert request['copy_alternatives'] is True and request['minimum_distinct'] == 0
    assert request['first_ante'] == 1 and request['last_ante'] == 8 and request['budget_ms'] == 27000
    assert request['no_perishable_targets'] is True and request['missing_names'] == []
    raw_text = (folder/'raw_result.json').read_text(encoding='utf-8')
    native = json.loads(raw_text)
    result = records['result.json']
    assert native['status'] == result['status'] == 'found' and native['seed'] == result['seed'] == 'S7PXV521'
    assert native['budget_ms'] == 27000 and result['search_calls'] == 1
    assert all(result[key] == value for key, value in native.items())
    trace_rows = []
    for line in (folder/'trace.log').read_text(encoding='utf-8').splitlines():
        try:
            trace_rows.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    assert result in trace_rows, 'Observed result must be preserved in the hash-bound original trace'
    names = ('request.json', 'result.json', 'raw_result.json', 'registration.json', 'record.json', 'spent.json', 'trace.log')
    return {'request': request, 'result': native, 'raw_result': raw_text,
            'binding': {'job': 'S05', 'files': {name: sha(folder/name) for name in names},
                        'selection': 'Already-observed selected development seed; no discovery or qualification',
                        'native_search_executed_in_this_component': False}}
