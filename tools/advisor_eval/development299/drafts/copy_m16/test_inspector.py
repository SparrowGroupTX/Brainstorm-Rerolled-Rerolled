"""Manufactured ZIP fixtures only; never read original source or register M16."""
from pathlib import Path
import ast
import importlib.util
import json
import sys
import tempfile
import zipfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
spec = importlib.util.spec_from_file_location('source_lexer', ROOT / 'tools/advisor_eval/development300/mechanics11/inspect_source.py')
lexer = importlib.util.module_from_spec(spec)
sys.modules['source_lexer'] = lexer
spec.loader.exec_module(lexer)
import inspect_source as subject


def main():
    checks = 0

    def check(value):
        nonlocal checks
        checks += 1
        assert value

    for name in ('inspect_source.py', 'register.py', 'test_inspector.py'):
        ast.parse((HERE / name).read_text())
        checks += 1
    card = b'''-- function Card:set_edition() fake end\r
function Card:set_edition(edition)\r
 local text="function end"\r
 if edition then self.edition = edition end\r
end\r
function Card:calculate_joker(context)\r
 if context.ending_shop then\r
  if self.ability.name == 'Perkeo' then return copy_card(self) end\r
 end\r
end\r
'''
    with tempfile.TemporaryDirectory(prefix='synthetic_copy_inspect_') as temporary:
        root = Path(temporary)
        archive = root / 'source.zip'
        with zipfile.ZipFile(archive, 'x') as stream:
            stream.writestr('card.lua', card)
            stream.writestr('game.lua', b'function Game:update_draw_to_hand()\n if self.first_hand_drawn then return true end\nend\nfunction Game:main_menu()\n return false\nend\n')
            stream.writestr('functions/common_events.lua', b'function copy_card(other)\n return other\nend\n')
            stream.writestr('functions/misc_functions.lua', b'function playing_card_joker_effects(cards)\n for _, c in pairs(cards) do local a=c end\nend\n')
            stream.writestr('forbidden.lua', b'function copy_card() ERROR_DO_NOT_READ_THIS_MEMBER end')
        result = subject.inspect(archive, root / 'inspection')
        check(set(result['members']) == set(subject.MEMBERS))
        check(len(result['members']) == 4)
        check(result['members']['card.lua']['sha256'] == subject.sha(card))
        edition = next(item for item in result['methods'] if item['name'] == 'set_edition')
        check(edition['status'] == 'found' and not edition['truncated'])
        check((root / 'inspection' / edition['excerpt_file']).read_bytes().startswith(b'function Card:set_edition'))
        check(b'\r\n' in (root / 'inspection' / edition['excerpt_file']).read_bytes())
        check(next(item for item in result['methods'] if item['name'] == 'main_menu')['status'] == 'found')
        check(next(item for item in result['methods'] if item['name'] == 'copy_card')['status'] == 'found')
        check(next(item for item in result['methods'] if item['name'] == 'playing_card_joker_effects')['status'] == 'found')
        perkeo = next(item for item in result['neighborhoods'] if item['name'] == 'perkeo')
        check(perkeo['matches'] == perkeo['shown_matches'] == 1 and not perkeo['truncated'])
        check(sum(path.stat().st_size for path in (root / 'inspection').glob('*.lua')) == result['combined_output_bytes'] <= subject.CAP)
        check(result['source_text_incomplete'] and any(item['status'] == 'not_found' for item in result['methods']))
        # Missing/duplicate/oversized members are explicit, never silently read.
        unusual = root / 'unusual.zip'
        with zipfile.ZipFile(unusual, 'x', compression=zipfile.ZIP_DEFLATED) as stream:
            stream.writestr('card.lua', card)
            stream.writestr('CARD.LUA', card)
            stream.writestr('game.lua', b' ' * (subject.MEMBER_CAP + 1))
        result = subject.inspect(unusual, root / 'unusual')
        check(result['members']['card.lua']['status'] == 'ambiguous')
        check(result['members']['game.lua']['status'] == 'read_cap_exceeded')
        check(result['members']['game.lua']['read_bytes'] == 0)
        check(result['members']['functions/common_events.lua']['status'] == 'missing')
        check(result['combined_output_bytes'] == 0 and result['source_text_incomplete'])
        # The same declaration in two allowed files is not selected arbitrarily.
        ambiguous = root / 'ambiguous.zip'
        with zipfile.ZipFile(ambiguous, 'x') as stream:
            for member in ('functions/common_events.lua', 'functions/misc_functions.lua'):
                stream.writestr(member, b'function copy_card(card)\n return card\nend\n')
        result = subject.inspect(ambiguous, root / 'ambiguous')
        check(next(item for item in result['methods'] if item['name'] == 'copy_card')['status'] == 'ambiguous')
        # Manufacture many markers and a huge single-line method. Both local
        # and global truncation must remain visible in the evidence manifest.
        large = root / 'large.zip'
        with zipfile.ZipFile(large, 'x') as stream:
            stream.writestr('card.lua', b'function Card:set_cost()\n local x="' + b'x' * 15000 + b'"\nend\n' + b'-- Perkeo ending_shop\n' * 1000)
        result = subject.inspect(large, root / 'large')
        cost = next(item for item in result['methods'] if item['name'] == 'set_cost')
        check(cost['truncated'] and cost['shown_bytes'] == 10000)
        check(cost['full_method_bytes'] > cost['shown_bytes'])
        check(next(item for item in result['neighborhoods'] if item['name'] == 'perkeo')['matches'] == 1000)
        check(next(item for item in result['neighborhoods'] if item['name'] == 'perkeo')['truncated'])
        with patch.object(subject, 'CAP', 150):
            result = subject.inspect(archive, root / 'tiny')
        check(result['combined_output_bytes'] == 150)
        check(any(item.get('output_budget_exhausted') for item in result['methods']))
        check(result['source_text_incomplete'])
        # A malformed allowed file yields explicit lexer errors, not execution.
        malformed = root / 'malformed.zip'
        with zipfile.ZipFile(malformed, 'x') as stream:
            stream.writestr('game.lua', b'function Game:main_menu()\n local x="unterminated')
        result = subject.inspect(malformed, root / 'malformed')
        check(next(item for item in result['methods'] if item['name'] == 'main_menu')['status'] == 'lexer_error')
        check(not result['source_execution'] and not result['native_search'] and not result['player_file_access'])
        # Wrong one-use receipt must fail before attempting any archive read.
        guarded = root / 'guarded'
        guarded.mkdir()
        (guarded / 'registration.json').write_text(json.dumps({'job': 'M15', 'timeout_seconds': 30}))
        (guarded / 'spent.json').write_text(json.dumps({'job': 'M16', 'registration_sha256': 'wrong'}))
        with patch.object(subject, '__file__', str(guarded / 'inspect_source.py')):
            try:
                subject.main()
            except RuntimeError:
                check(True)
            else:
                check(False)
    with (HERE / 'synthetic_fixture_report.json').open('x', encoding='utf-8') as stream:
        json.dump({'schema': 1, 'checks': checks, 'passed': True, 'original_source_access': False,
                   'source_execution': False, 'registration': False,
                   'source': 'Temporary manufactured ZIP files only'}, stream, indent=2)
        stream.write('\n')
    print('M16 inspector synthetic checks:', checks, 'passed')


if __name__ == '__main__':
    main()
