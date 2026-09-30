"""Python/fixture wiring checks only; no original source/native execution."""
from pathlib import Path
import ast
import json

HERE = Path(__file__).resolve().parent


def main():
    count = 0
    for folder in (HERE, HERE/'adapter'):
        for path in folder.glob('*.py'):
            ast.parse(path.read_text(encoding='utf-8')); count += 1
    text = (HERE/'adapter/startup_fixture.lua').read_text(encoding='utf-8')
    for required in ('local boot_cache={font={synthetic_display_font=true}}', 'baseline.can_begin()',
                     'baseline_preflight_rejected=true', "after.skip_tags.Small=='tag_charm'", 'env.score_calls()==0'):
        assert required in text; count += 1
    assert 'boot_timer(' not in text; count += 1
    with (HERE/'synthetic_fixture_report.json').open('x', encoding='utf-8') as stream:
        json.dump({'schema': 1, 'checks': count, 'passed': True, 'source_execution': False,
            'native_search': False, 'registration': False}, stream, indent=2); stream.write('\n')
    print(f'M14 preparation: {count} checks passed; no source/native work.')


if __name__ == '__main__':
    main()
