"""Detached bounded Burnt fallback drafts, layered on304+adaptive quota."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
QUOTA = HERE.parent/'adaptive_quota_rebased'
BASE = ROOT/'tools/advisor_eval/runs/startup304_candidate/policy'


def main():
    originals = {}
    for name in ('Brainstorm/Advisor/collection_search.lua', 'Brainstorm/Core/auto_run_product.lua',
                 'Brainstorm/UI/collection_run.lua', 'Brainstorm/Core/collection_search_product.lua',
                 'tests/advisor_collection_product.lua', 'tests/advisor_auto_run_product.lua',
                 'tests/advisor_collection_query.lua', 'tests/advisor_adaptive_quota.lua'):
        source = BASE/name if name == 'Brainstorm/Core/collection_search_product.lua' else QUOTA/name
        raw = source.read_bytes(); originals[name] = hashlib.sha256(raw).hexdigest()
        text = raw.decode('utf-8')
        if name.startswith('tests/'):
            text = text.replace('development300/adaptive_quota_rebased/', 'development300/burnt_fallback/')
            text = text.replace("local path='Brainstorm/Core/'", "local path='tools/advisor_eval/development300/burnt_fallback/Brainstorm/Core/'")
        output = HERE/name; output.parent.mkdir(parents=True, exist_ok=True)
        with output.open('x', encoding='utf-8', newline='\n') as stream: stream.write(text)
    with (HERE/'base_hashes.json').open('x', encoding='utf-8') as stream:
        json.dump(originals, stream, indent=2); stream.write('\n')
    print('Prepared detached fallback baseline; no runtime staging or native/source execution.')


if __name__ == '__main__':
    main()
