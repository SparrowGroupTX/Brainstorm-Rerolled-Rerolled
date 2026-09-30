"""Registered M11 ZIP-member inspection only. Never execute original Lua/code.

The lexer locates balanced functions while preserving exact byte excerpts.
All output is bounded and written only beneath the registered worker folder.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
import time
import zipfile

MEMBERS = ('game.lua', 'functions/misc_functions.lua', 'functions/common_events.lua',
           'functions/UI_definitions.lua', 'functions/button_callbacks.lua')
SPECS = [
    ('update_game_over', ('game.lua',), r'function\s+Game:update_game_over\s*\(', 160),
    ('win_game', ('functions/misc_functions.lua', 'functions/common_events.lua'), r'function\s+win_game\s*\(', 140),
    ('game_over_ui', ('functions/UI_definitions.lua',), r'function\s+create_UIBox_game_over\s*\(', 220),
    ('win_ui', ('functions/UI_definitions.lua',), r'function\s+create_UIBox_win\s*\(', 160),
    ('exit_overlay_menu', ('functions/button_callbacks.lua',), r'G\.FUNCS\.exit_overlay_menu\s*=\s*function\b', 60),
    ('overlay_menu', ('functions/button_callbacks.lua',), r'G\.FUNCS\.overlay_menu\s*=\s*function\b', 100),
    ('start_run', ('functions/button_callbacks.lua',), r'G\.FUNCS\.start_run\s*=\s*function\b', 80),
    ('go_to_menu', ('functions/button_callbacks.lua',), r'G\.FUNCS\.go_to_menu\s*=\s*function\b', 60),
]
LONG = re.compile(r'\[(=*)\[')
WORD = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def tokens(text, start=0):
    """Yield Lua identifiers outside strings/comments without evaluating Lua."""
    i = start
    while i < len(text):
        if text.startswith('--', i):
            long = LONG.match(text, i+2)
            if long:
                end = text.find(']'+long.group(1)+']', long.end())
                if end < 0:
                    raise ValueError('Unterminated long comment')
                i = end + 2 + len(long.group(1))
            else:
                end = text.find('\n', i+2);i = len(text) if end < 0 else end+1
        elif text[i] in ('"', "'"):
            quote = text[i];i += 1
            while i < len(text) and text[i] != quote:
                i += 2 if text[i] == '\\' else 1
            if i >= len(text):
                raise ValueError('Unterminated quoted string')
            i += 1
        else:
            long = LONG.match(text, i)
            if long:
                end = text.find(']'+long.group(1)+']', long.end())
                if end < 0:
                    raise ValueError('Unterminated long string')
                i = end+2+len(long.group(1))
                continue
            word = WORD.match(text, i)
            if word:
                yield word.group(), i, word.end();i = word.end()
            else:
                i += 1

def function_end(text, function_start):
    stack = []
    for word, start, end in tokens(text, function_start):
        if word == 'function':
            stack.append(['function', False])
        elif not stack:
            raise ValueError('The matched declaration does not begin a function')
        elif word in ('if', 'for', 'while', 'repeat'):
            stack.append([word, word in ('for', 'while')])
        elif word == 'do':
            if stack[-1][1]:
                stack[-1][1] = False
            else:
                stack.append(['do', False])
        elif word == 'end':
            if stack[-1][0] == 'repeat':
                raise ValueError('Repeat block closes with end')
            stack.pop()
            if not stack:
                return end
        elif word == 'until':
            if stack[-1][0] != 'repeat':
                raise ValueError('Unexpected until token')
            stack.pop()
    raise ValueError('No balanced function end found')

def excerpt(raw, pattern, maximum_lines):
    # Latin1 maps every original byte one-to-one, preserving offsets/hashes.
    text = raw.decode('latin1')
    functions = {start for word, start, end in tokens(text) if word == 'function'}
    declarations = []
    for candidate in re.finditer(r'(?m)^[ \t]*'+pattern, text):
        position = text.find('function', candidate.start(), candidate.end())
        if position in functions:
            declarations.append((candidate, position))
    if len(declarations) != 1:
        return {'status': 'not_found' if not declarations else 'ambiguous', 'matches': len(declarations)}, b''
    match, first = declarations[0]
    end = function_end(text, first)
    full = raw[match.start():end]
    lines = full.splitlines(keepends=True)
    shown = b''.join(lines[:maximum_lines])
    if len(shown) > 40000:
        shown = shown[:40000]
    start_line = text.count('\n', 0, match.start())+1
    return {'status': 'found', 'start_line': start_line,
            'end_line': text.count('\n', 0, end)+1, 'full_method_bytes': len(full),
            'full_method_sha256': sha(full), 'excerpt_sha256': sha(shown),
            'shown_lines': len(shown.splitlines()), 'line_limit': maximum_lines,
            'truncated': shown != full, 'encoding': 'original bytes; offsets located through Latin1 identity mapping'}, shown

def inspect(archive, output):
    output.mkdir(exist_ok=False)
    read = {};manifest = {'schema': 1, 'job': 'M11', 'status': 'complete', 'members': {}, 'methods': [],
        'scope': 'Original executable ZIP read only; no original Lua, policy, game process or player-file execution/access.',
        'qualification': False, 'method_maximum_bytes': 40000, 'combined_excerpt_limit_bytes': 120000}
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        if len(infos) > 20000:
            raise ValueError('Unexpected archive entry count')
        for member in MEMBERS:
            found = [info for info in infos if info.filename.replace('\\', '/').lower() == member.lower()]
            if len(found) != 1:
                manifest['members'][member] = {'status': 'missing' if not found else 'ambiguous'}
                continue
            info = found[0]
            if info.file_size > 4*1024*1024:
                raise ValueError('Source member exceeds bounded read: '+member)
            raw = z.read(info);read[member] = raw
            manifest['members'][member] = {'status': 'read', 'archive_member': info.filename,
                'bytes': len(raw), 'sha256': sha(raw)}
    total = 0
    for label, members, pattern, limit in SPECS:
        found = None;body = b''
        for member in members:
            if member not in read:
                continue
            candidate, exact = excerpt(read[member], pattern, limit)
            candidate.update(name=label, source_member=member, declaration_pattern=pattern)
            if candidate['status'] != 'not_found':
                found, body = candidate, exact
                break
        item = found or {'name': label, 'status': 'not_found', 'searched_members': list(members), 'declaration_pattern': pattern}
        if body:
            total += len(body)
            if total > 120000:
                raise ValueError('Combined excerpt size exceeded')
            name = label+'.lua';(output/name).write_bytes(body);item['excerpt_file'] = name
        manifest['methods'].append(item)
    # Only short Game:update call-site neighborhoods, never its complete body.
    raw = read.get('game.lua', b'');lines = raw.splitlines(keepends=True);sites = []
    for index, line in enumerate(lines):
        if b'self:update_game_over' in line:
            low = max(0, index-6);high = min(len(lines), index+7)
            body = b''.join(lines[low:high]);name = 'game_update_callsite_'+str(len(sites)+1)+'.lua'
            (output/name).write_bytes(body)
            sites.append({'start_line': low+1, 'end_line': high, 'sha256': sha(body), 'excerpt_file': name})
            if len(sites) == 4:
                break
    manifest['game_update_callsites'] = sites
    manifest['method_excerpt_bytes'] = total
    with (output/'inspection.json').open('x', encoding='utf-8') as stream:
        json.dump(manifest, stream, indent=2);stream.write('\n')
    return manifest

def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder/'registration.json').read_text())
    spent = json.loads((folder/'spent.json').read_text())
    if (registration.get('job') != 'M11' or registration.get('timeout_seconds') != 30 or spent.get('job') != 'M11' or
        spent.get('registration_sha256') != sha((folder/'registration.json').read_bytes())):
        raise RuntimeError('Matching root-dispatched M11 one-use receipt required')
    archive = Path(registration['metadata']['source_archive'])
    if str(archive.resolve()) not in registration['external_files']:
        raise ValueError('Archive is not frozen in the external provenance manifest')
    # cycle.py already verifies external bytes before dispatch and after reaping.
    started = time.perf_counter()
    result = inspect(archive, folder/'inspection')
    print(json.dumps({'job': 'M11', 'status': result['status'], 'elapsed_seconds': time.perf_counter()-started,
        'methods': [{k: value.get(k) for k in ('name', 'status', 'source_member', 'start_line', 'end_line', 'truncated')} for value in result['methods']],
        'source_execution': False, 'player_file_access': False}), flush=True)

if __name__ == '__main__':
    main()
