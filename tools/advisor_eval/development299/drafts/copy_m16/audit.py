"""Audit only the already-spent M16 receipt and preserved excerpts; no ZIP read."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[5]
FOLDER = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M16'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    record, registration, spent = [read(FOLDER / name) for name in ('record.json', 'registration.json', 'spent.json')]
    manifest = read(FOLDER / 'inspection/inspection.json')
    assert record['job'] == registration['job'] == spent['job'] == manifest['job'] == 'M16'
    assert record['status'] == 'complete' and record['exit_code'] == 0 and record['one_use_spent']
    assert record['timeout_seconds'] == registration['timeout_seconds'] == 30 and record['elapsed_seconds'] < 30
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert record['registration_sha256'] == spent['registration_sha256'] == sha(FOLDER / 'registration.json')
    assert record['trace_sha256'] == sha(FOLDER / 'trace.log')
    assert registration['authority_sha256'] == sha(FOLDER.parent / 'authority.json')
    assert registration['reservation_sha256'] == sha(FOLDER.parent / 'M16_reservation.json')
    for file, digest in registration['files'].items():
        assert sha(FOLDER / file) == digest, file
    assert set(manifest['members']) == {'game.lua', 'card.lua', 'functions/common_events.lua', 'functions/misc_functions.lua'}
    for member in manifest['members'].values():
        assert member['status'] == 'read' and member['bytes'] <= 4 * 1024 * 1024
    prior = read(FOLDER.parent / 'M15/inspection/inspection.json')
    for name in ('card.lua', 'functions/common_events.lua'):
        assert manifest['members'][name]['sha256'] == prior['members'][name]['sha256']
    methods, excerpts, missing, truncated = {}, {}, [], []
    for item in manifest['methods']:
        if item['status'] != 'found':
            missing.append(item['name'])
            continue
        path = FOLDER / 'inspection' / item['excerpt_file']
        assert sha(path) == item['excerpt_sha256'] and path.stat().st_size == item['shown_bytes']
        assert item['shown_bytes'] <= item['byte_limit'] and item['shown_lines'] <= item['line_limit']
        if not item['truncated']:
            assert sha(path) == item['full_method_sha256'] and path.stat().st_size == item['full_method_bytes']
        else:
            truncated.append(item['excerpt_file'])
        methods[item['name']] = {key: item[key] for key in ('source_member', 'start_line', 'end_line',
                                'full_method_sha256', 'excerpt_sha256', 'shown_bytes', 'truncated')}
        excerpts[item['excerpt_file']] = sha(path)
    neighborhoods = []
    for group in manifest['neighborhoods']:
        assert group['shown_matches'] == len(group['excerpts']) <= group['matches']
        assert group['shown_matches'] <= group['match_limit']
        for item in group['excerpts']:
            path = FOLDER / 'inspection' / item['excerpt_file']
            assert sha(path) == item['excerpt_sha256'] and path.stat().st_size == item['shown_bytes']
            assert item['shown_bytes'] <= group['byte_limit_per_excerpt']
            if not item['truncated']:
                assert sha(path) == item['full_neighborhood_sha256'] and path.stat().st_size == item['full_neighborhood_bytes']
            else:
                truncated.append(item['excerpt_file'])
            excerpts[item['excerpt_file']] = sha(path)
        neighborhoods.append({'name': group['name'], 'matches': group['matches'], 'shown_matches': group['shown_matches'],
                              'truncated': group['truncated']})
    assert len(methods) == 9 and not missing
    assert set(path.name for path in (FOLDER / 'inspection').glob('*.lua')) == set(excerpts)
    actual = sum((FOLDER / 'inspection' / name).stat().st_size for name in excerpts)
    assert actual == manifest['combined_output_bytes'] <= manifest['combined_output_cap_bytes'] == 160000
    assert not manifest['source_execution'] and not manifest['native_search'] and not manifest['player_file_access']
    draw = (FOLDER / 'inspection/update_draw_to_hand.lua').read_text()
    assert draw.index('draw_from_deck_to_hand(nil)') < draw.index('first_hand_drawn = true') < draw.index('G.STATE = G.STATES.SELECTING_HAND')
    assert 'G.GAME.current_round.hands_played == 0' in draw and 'G.GAME.current_round.discards_used == 0' in draw
    dispatch = (FOLDER / 'inspection/playing_card_joker_effects.lua').read_text()
    assert 'calculate_joker({playing_card_added = true, cards = cards})' in dispatch
    perkeo = (FOLDER / 'inspection/card__ending_shop_1.lua').read_text()
    assert perkeo.index('elseif context.ending_shop') < perkeo.index("self.ability.name == 'Perkeo'")
    assert perkeo.index("copy_card(pseudorandom_element(G.consumeables.cards, pseudoseed('perkeo')), nil)") < perkeo.index('card:set_edition({negative = true}, true)') < perkeo.index('card:add_to_deck()') < perkeo.index('G.consumeables:emplace(card)')
    menu = (FOLDER / 'inspection/main_menu.lua').read_text()
    assert 'self:prep_stage(G.STAGES.MAIN_MENU, G.STATES.MENU, true)' in menu
    assert 'G.CONTROLLER.lock_input = false' in menu and 'set_main_menu_UI()' in menu
    assert 'STATE_COMPLETE' not in menu
    result = {'schema': 1, 'job': 'M16', 'status': 'read_only_mechanics_verified',
              'record_sha256': sha(FOLDER / 'record.json'), 'registration_sha256': sha(FOLDER / 'registration.json'),
              'trace_sha256': sha(FOLDER / 'trace.log'), 'inspection_sha256': sha(FOLDER / 'inspection/inspection.json'),
              'worker_seconds': record['elapsed_seconds'], 'one_use_spent': True,
              'frozen_files_and_excerpts_verified': True,
              'external_archive_runtime_unchanged': 'Recorded by root cycle pre-dispatch/post-reap checks; audit did not reread executable or interpreter.',
              'source_members': manifest['members'], 'methods': methods, 'excerpts': excerpts,
              'combined_excerpt_bytes': actual, 'neighborhoods': neighborhoods,
              'missing_named_methods': missing, 'truncated_excerpts': truncated,
              'facts': {
                  'first_hand': [
                      'Game:update_draw_to_hand calls draw_from_deck_to_hand first and returns if that function reports an early stop.',
                      'When hands_played and discards_used are both zero and facing_blind is true, it then dispatches first_hand_drawn=true to each current Joker.',
                      'Only afterward does it enqueue SELECTING_HAND, STATE_COMPLETE=false and blind:drawn_to_hand.',
                      'playing_card_joker_effects directly loops all current Jokers with playing_card_added=true and the same supplied cards marker table.'
                  ],
                  'perkeo': [
                      'The ending_shop Perkeo branch queues a callback only when the consumable inventory has a first card.',
                      'Within each queued callback it chooses from the then-current whole consumable pool, copies that card, replaces its edition with Negative, adds it to deck and emplaces it. Earlier copies can therefore enter a later queued callback pool.',
                      'copy_card sets the new center and base from the source, recursively copies ability tables, copies source edition/seal/debuff/pinned, and aliases source params while replacing params.playing_card.',
                      'set_edition replaces the previous edition; Negative is exactly negative=true/type=negative. A new not-yet-added copy gains capacity when add_to_deck runs, not twice.',
                      'add_to_deck increments consumable capacity once for a Negative card with ability.consumeable; remove_from_deck removes that capacity on ordinary removal.',
                      'set_edition calls set_cost. Negative adds5 to the edition surcharge alongside inflation; discount, Astronomer, rental, extra resale and shop-only coupons retain their explicit source rules.',
                      'copy_table preserves false and other scalar values recursively, including metatables.'
                  ],
                  'main_menu': [
                      'Full198-line method calls prep_stage(MAIN_MENU,MENU,true) and resets selected_back to Red.',
                      'It queues controller input unlock and a later set_main_menu_UI callback, with contextual presentation delays.',
                      'It contains no STATE_COMPLETE assignment; previous readiness blockers cannot be dismissed by assuming main_menu sets that latch true.',
                      'Profile/unlock/tally calls appear in source but were not executed or backed by player data during this inspection.'
                  ]
              },
              'limits': [
                  'Source text only; all nine named methods are complete, but one broad Perkeo neighborhood ends220bytes before its requested bound. The focused ending_shop branch is complete.',
                  'The128/52-front registry, constructor/set_ability details, copied-consumable public identity registration and general modded metadata are not newly established by these named excerpts.',
                  'Calling normal draw before first_hand_drawn does not itself execute queued events; final queue timing relies on separately grounded event semantics.',
                  'A homogeneous consumable effect can make random identity choice irrelevant only after proving that all copied fields, prices, capacity and subsequent use/hold alternatives are equivalent.',
                  'No Perkeo copying callback, Certificate generation, game startup transition, search, simulation, terminal result or live UI action executed. No win odds, achievement or adapter qualification follow.'
              ], 'source_execution': False, 'native_search': False, 'player_file_access': False, 'qualification': False}
    with (FOLDER / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({'status': result['status'], 'worker_seconds': record['elapsed_seconds'], 'methods': len(methods),
                      'bytes': actual, 'truncated': truncated, 'audit_sha256': sha(FOLDER / 'audit.json')}))


if __name__ == '__main__':
    main()
