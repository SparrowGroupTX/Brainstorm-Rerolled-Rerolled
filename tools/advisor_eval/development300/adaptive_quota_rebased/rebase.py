"""Rebase detached quota feature onto frozen304 startup safeguards and tests."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE.parent/'adaptive_quota304'
BASE = ROOT/'tools/advisor_eval/runs/startup304_candidate/policy'


def main():
    sources = {}
    for name in ('Brainstorm/Advisor/collection_search.lua', 'Brainstorm/UI/collection_run.lua'):
        sources[name] = (OLD/name).read_text(encoding='utf-8')
    name = 'Brainstorm/Core/auto_run_product.lua'
    text = (BASE/name).read_text(encoding='utf-8')
    needle = "'minimum_distinct','first_ante','last_ante','budget_ms'"
    assert text.count(needle) == 1
    text = text.replace(needle, "'minimum_distinct','quota_mode','first_ante','last_ante','budget_ms'", 1)
    marker = '    local timed,now=pcall(clock)'
    assert text.count(marker) == 1
    text = text.replace(marker, '''    -- Automatic collection must include progress once the fixed opening is
    -- already complete. Explicit numeric positive or strict zero requests
    -- retain their meaning; absent/legacy zero defaults to the new Auto mode.
    if configured.search_request.quota_mode==nil then
      local count=configured.search_request.minimum_distinct
      configured.search_request.quota_mode=type(count)=='number' and count>0 and 'strict' or 'auto'
    end
'''+marker, 1)
    sources[name] = text
    for name in ('tests/advisor_collection_query.lua', 'tests/advisor_adaptive_quota.lua'):
        sources[name] = (OLD/name).read_text(encoding='utf-8').replace('development300/adaptive_quota304/', 'development300/adaptive_quota_rebased/')
    name = 'tests/advisor_auto_run_product.lua'
    text = (ROOT/name).read_text(encoding='utf-8')
    text = text.replace("dofile('Brainstorm/Core/auto_run_product.lua')", "dofile('tools/advisor_eval/development300/adaptive_quota_rebased/Brainstorm/Core/auto_run_product.lua')", 1)
    old_test = (OLD/name).read_text(encoding='utf-8')
    start = old_test.index("for _,case in ipairs({\n  {options={},mode='auto'},")
    end = old_test.index("print('advisor_auto_run_product:", start)
    final = "print('advisor_auto_run_product: '..checks..' checks passed')"
    assert text.count(final) == 1
    text = text.replace(final, old_test[start:end]+final, 1)
    sources[name] = text
    name = 'tests/advisor_collection_product.lua'
    sources[name] = (ROOT/name).read_text(encoding='utf-8').replace("dofile('Brainstorm/Advisor/collection_search.lua')",
        "dofile('tools/advisor_eval/development300/adaptive_quota_rebased/Brainstorm/Advisor/collection_search.lua')", 1)
    for name, text in sources.items():
        out = HERE/name; out.parent.mkdir(parents=True, exist_ok=True)
        with out.open('x', encoding='utf-8', newline='\n') as stream: stream.write(text)
    with (HERE/'rebase_manifest.json').open('x', encoding='utf-8') as stream:
        json.dump({'base_policy': 'startup304_candidate', 'base_policy_digest': 'e553ec3b04ba3e020e4c5c7b690b1939ae686faa95b77f77de3c60591d764d8c',
            'base_runtime_hashes': {name: hashlib.sha256((BASE/name).read_bytes()).hexdigest() for name in sources if name.startswith('Brainstorm/')},
            'preserved_304_safeguards': ['persistent font-only boot cache', 'exact MAIN_MENU/MENU latch exception', 'all real locks and save guards', 'concise wait reasons'],
            'runtime_staged': False, 'source_or_native_experiment': False}, stream, indent=2); stream.write('\n')
    print('Rebased detached quota feature on304; no runtime/test staging.')


if __name__ == '__main__':
    main()
