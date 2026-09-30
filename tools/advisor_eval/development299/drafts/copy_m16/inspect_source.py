"""Prospective M16: four bounded ZIP members; never execute source or Lua.

The production entry point requires root-frozen matching M16 registration and
spent receipts. Tests call inspect() with manufactured temporary ZIPs only.
"""
from pathlib import Path
import json
import re
import time
import zipfile
from source_lexer import excerpt, sha

MEMBERS = ('game.lua', 'card.lua', 'functions/common_events.lua', 'functions/misc_functions.lua')
CAP = 160000
MEMBER_CAP = 4 * 1024 * 1024
METHODS = (
    ('update_draw_to_hand', ('game.lua',), r'function\s+Game:update_draw_to_hand\s*\(', 240, 16000),
    ('main_menu', ('game.lua',), r'function\s+Game:main_menu\s*\(', 220, 10000),
    ('playing_card_joker_effects', ('functions/misc_functions.lua', 'functions/common_events.lua'),
     r'function\s+playing_card_joker_effects\s*\(', 180, 14000),
    ('copy_card', ('functions/common_events.lua', 'functions/misc_functions.lua'), r'function\s+copy_card\s*\(', 220, 16000),
    ('set_edition', ('card.lua',), r'function\s+Card:set_edition\s*\(', 240, 16000),
    ('set_cost', ('card.lua',), r'function\s+Card:set_cost\s*\(', 160, 10000),
    ('add_to_deck', ('card.lua',), r'function\s+Card:add_to_deck\s*\(', 180, 12000),
    ('remove_from_deck', ('card.lua',), r'function\s+Card:remove_from_deck\s*\(', 140, 8000),
    ('copy_table', ('functions/misc_functions.lua', 'functions/common_events.lua'),
     r'function\s+copy_table\s*\(', 100, 6000),
)
# These raw neighborhoods include comments/strings. They are explicitly source
# text, not an assertion that a branch executes. Balanced methods use the lexer.
NEIGHBORHOODS = (
    ('perkeo', 'card.lua', rb'Perkeo|j_perkeo', 3, 35, 90, 7000),
    ('ending_shop', 'card.lua', rb'ending_shop|end_of_shop', 3, 16, 30, 3000),
    ('first_hand_dispatch', 'game.lua', rb'first_hand_drawn', 4, 24, 30, 3000),
    ('playing_card_effects', 'functions/misc_functions.lua', rb'playing_card_joker_effects|playing_cards_created', 4, 16, 24, 3000),
)


def inspect(archive, output):
    output.mkdir(exist_ok=False)
    manifest = {'schema': 1, 'job': 'M16', 'status': 'complete', 'members': {},
                'methods': [], 'neighborhoods': [], 'qualification': False,
                'combined_output_cap_bytes': CAP, 'member_read_cap_bytes': MEMBER_CAP,
                'source_execution': False, 'native_search': False, 'player_file_access': False,
                'scope': 'Four exact ZIP members; first-hand dispatch and Perkeo copy/capacity/price source text only.'}
    sources = {}
    with zipfile.ZipFile(archive) as archive_file:
        entries = archive_file.infolist()
        if len(entries) > 20000:
            raise ValueError('Archive entry count exceeds20000; no members read')
        for member in MEMBERS:
            found = [entry for entry in entries if entry.filename.replace('\\', '/').lower() == member.lower()]
            if len(found) != 1:
                manifest['members'][member] = {'status': 'missing' if not found else 'ambiguous', 'matches': len(found)}
                continue
            entry = found[0]
            if entry.file_size > MEMBER_CAP:
                manifest['members'][member] = {'status': 'read_cap_exceeded', 'archive_member': entry.filename,
                                                'declared_bytes': entry.file_size, 'read_bytes': 0}
                continue
            with archive_file.open(entry) as stream:
                raw = stream.read(MEMBER_CAP + 1)
            if len(raw) > MEMBER_CAP:
                manifest['members'][member] = {'status': 'read_cap_exceeded', 'archive_member': entry.filename,
                                                'declared_bytes': entry.file_size, 'read_bytes': len(raw)}
                continue
            sources[member] = raw
            manifest['members'][member] = {'status': 'read', 'archive_member': entry.filename,
                                            'bytes': len(raw), 'sha256': sha(raw)}

    total = 0

    def save(filename, body, metadata):
        nonlocal total
        available = max(0, CAP - total)
        if len(body) > available:
            body = body[:available]
            metadata['truncated'] = True
            metadata['output_budget_exhausted'] = True
        metadata['shown_bytes'] = len(body)
        metadata['shown_lines'] = len(body.splitlines())
        metadata['excerpt_sha256'] = sha(body)
        if body:
            with (output / filename).open('xb') as stream:
                stream.write(body)
            total += len(body)
            metadata['excerpt_file'] = filename

    for label, members, pattern, line_limit, byte_limit in METHODS:
        candidates = []
        for member in members:
            try:
                metadata, body = excerpt(sources.get(member, b''), pattern, line_limit)
            except ValueError as error:
                metadata, body = {'status': 'lexer_error', 'reason': str(error)}, b''
            metadata.update(source_member=member)
            candidates.append((metadata, body))
        found = [(metadata, body) for metadata, body in candidates if metadata['status'] != 'not_found']
        if len(found) == 1:
            metadata, body = found[0]
            metadata = dict(metadata)
        else:
            metadata, body = {'status': 'not_found' if not found else 'ambiguous',
                              'matches_in_members': len(found)}, b''
        metadata.update(name=label, searched_members=list(members), declaration_pattern=pattern,
                        byte_limit=byte_limit, searched_statuses=[item for item, _ in candidates])
        if body:
            if len(body) > byte_limit:
                metadata['truncated'] = True
            save(label + '.lua', body[:byte_limit], metadata)
        manifest['methods'].append(metadata)

    for label, member, pattern, limit, before, after, byte_limit in NEIGHBORHOODS:
        lines = sources.get(member, b'').splitlines(keepends=True)
        hits = [index for index, line in enumerate(lines) if re.search(pattern, line)]
        item = {'name': label, 'source_member': member, 'pattern': pattern.decode('ascii'),
                'status': 'found' if hits else 'not_found', 'matches': len(hits), 'shown_matches': 0,
                'match_limit': limit, 'lines_before': before, 'lines_after': after,
                'byte_limit_per_excerpt': byte_limit, 'truncated': len(hits) > limit, 'excerpts': []}
        for ordinal, index in enumerate(hits[:limit], 1):
            low, high = max(0, index - before), min(len(lines), index + after + 1)
            full = b''.join(lines[low:high])
            metadata = {'match_line': index + 1, 'start_line': low + 1, 'requested_end_line': high,
                        'full_neighborhood_bytes': len(full), 'full_neighborhood_sha256': sha(full),
                        'truncated': len(full) > byte_limit}
            filename = member.replace('/', '_').replace('.lua', '') + '__' + label + '_' + str(ordinal) + '.lua'
            save(filename, full[:byte_limit], metadata)
            item['shown_matches'] += int(metadata['shown_bytes'] > 0)
            item['excerpts'].append(metadata)
            item['truncated'] = item['truncated'] or metadata['truncated']
        manifest['neighborhoods'].append(item)
    manifest['combined_output_bytes'] = total
    manifest['source_text_incomplete'] = any(item['status'] != 'read' for item in manifest['members'].values()) or any(
        item['status'] != 'found' or item.get('truncated', False) for item in manifest['methods'] + manifest['neighborhoods'])
    with (output / 'inspection.json').open('x', encoding='utf-8') as stream:
        json.dump(manifest, stream, indent=2)
        stream.write('\n')
    return manifest


def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder / 'registration.json').read_text(encoding='utf-8'))
    spent = json.loads((folder / 'spent.json').read_text(encoding='utf-8'))
    if (registration.get('job') != 'M16' or spent.get('job') != 'M16' or registration.get('timeout_seconds') != 30 or
            spent.get('registration_sha256') != sha((folder / 'registration.json').read_bytes())):
        raise RuntimeError('Root-frozen matching one-use M16 spent receipt required')
    archive = Path(registration['metadata']['source_archive'])
    if str(archive.resolve()) not in registration['external_files']:
        raise ValueError('Archive not frozen in external provenance')
    started = time.perf_counter()
    result = inspect(archive, folder / 'inspection')
    print(json.dumps({'job': 'M16', 'status': result['status'], 'elapsed_seconds': time.perf_counter() - started,
                      'combined_output_bytes': result['combined_output_bytes'], 'members': result['members'],
                      'methods': [{key: value.get(key) for key in ('name', 'status', 'source_member', 'truncated')}
                                  for value in result['methods']], 'source_text_incomplete': result['source_text_incomplete'],
                      'source_execution': False, 'native_search': False, 'player_file_access': False}), flush=True)


if __name__ == '__main__':
    main()
