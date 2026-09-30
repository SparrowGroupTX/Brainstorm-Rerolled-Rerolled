"""Package review artifacts only. No shared runtime/test files are changed."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
prefix = 'tools/advisor_eval/development299/drafts/clear_budget303/'
patches = []
for name in ('search.lua', 'decision.lua', 'phase_copy.lua', 'retry_policy.lua'):
    before = (ROOT / 'Brainstorm/Advisor' / name).read_text()
    after = (HERE / name).read_text()
    path = 'Brainstorm/Advisor/' + name
    patches.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                       fromfile='a/' + path, tofile='b/' + path))
with (HERE / 'runtime.patch').open('x', encoding='utf-8', newline='\n') as stream:
    stream.write(''.join(patches))
for name in ('advisor_clear_budget.lua', 'advisor_fast_clear.lua', 'advisor_retry_policy.lua'):
    source = name if name == 'advisor_clear_budget.lua' else 'regression_' + name
    text = (HERE / source).read_text().replace(prefix, 'Brainstorm/Advisor/')
    with (HERE / ('install_' + name)).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(text)
ready = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(HERE.iterdir()) if path.is_file()}
with (HERE / 'READY_SHA256.json').open('x') as stream:
    json.dump({'kind': 'detached303_ready_draft_not_installed', 'files': ready,
               'ordinary_fixtures_passed': 6, 'new_fixture_checks': 33,
               'runtime_changed': False, 'source_or_captured_experiments': 0}, stream, indent=2)
print('Packaged detached303 draft review files.')
