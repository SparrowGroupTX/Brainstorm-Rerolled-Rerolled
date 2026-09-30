"""M13 bounded ZIP read-only startup/controller gate inspection. No Lua run."""
from pathlib import Path
import json
import re
import time
import zipfile
from source_lexer import excerpt, sha

MEMBERS = ('game.lua', 'globals.lua', 'engine/controller.lua', 'main.lua',
           'functions/button_callbacks.lua', 'functions/misc_functions.lua', 'functions/common_events.lua')
METHODS = (
    ('controller_init', 'engine/controller.lua', r'function\s+Controller:init\s*\(', 240),
    ('controller_update', 'engine/controller.lua', r'function\s+Controller:update\s*\(', 320),
    ('game_update', 'game.lua', r'function\s+Game:update\s*\(', 220),
    ('exit_overlay', 'functions/button_callbacks.lua', r'G\.FUNCS\.exit_overlay_menu\s*=\s*function\b', 60),
    ('overlay_menu', 'functions/button_callbacks.lua', r'G\.FUNCS\.overlay_menu\s*=\s*function\b', 100),
)
PATTERNS = (
    ('saving_loading', rb'\b(?:SAVING|LOADING)\b', 28),
    ('frame_locks', rb'locks\s*(?:\.\s*(?:frame_set|frame)|\[\s*[\x27\x22](?:frame_set|frame))', 20),
    ('controller_locked', rb'(?:self|CONTROLLER)\s*\.\s*locked\b', 20),
    ('controller_update_call', rb'CONTROLLER\s*:\s*update\s*\(', 8),
    ('menu_state', rb'STAGES\s*\.\s*MAIN_MENU|STATES\s*\.\s*MENU', 20),
    ('state_complete', rb'STATE_COMPLETE\s*=', 28),
)


def inspect(archive, output):
    output.mkdir(exist_ok=False)
    manifest = {'schema': 1, 'job': 'M13', 'status': 'complete', 'members': {}, 'methods': [],
        'neighborhoods': [], 'scope': 'Original executable ZIP read only. No Lua execution, native search, process control or player-file access.',
        'qualification': False, 'combined_output_cap_bytes': 280000,
        'neighborhood_lines_before': 6, 'neighborhood_lines_after': 8}
    sources = {}
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        assert len(entries) <= 20000, 'Archive entry cap exceeded'
        for name in MEMBERS:
            matches = [entry for entry in entries if entry.filename.replace('\\', '/').lower() == name.lower()]
            if len(matches) != 1:
                manifest['members'][name] = {'status': 'missing' if not matches else 'ambiguous'}
                continue
            entry = matches[0]
            assert entry.file_size <= 4*1024*1024, 'Source member exceeds read cap'
            raw = z.read(entry); sources[name] = raw
            manifest['members'][name] = {'status': 'read', 'archive_member': entry.filename,
                                         'bytes': len(raw), 'sha256': sha(raw)}
    total = 0
    for label, member, pattern, cap in METHODS:
        metadata, raw = excerpt(sources.get(member, b''), pattern, cap)
        metadata.update(name=label, source_member=member, declaration_pattern=pattern)
        if raw:
            total += len(raw); assert total <= 280000, 'Combined excerpt cap exceeded'
            metadata['excerpt_file'] = label+'.lua'; (output/metadata['excerpt_file']).write_bytes(raw)
        manifest['methods'].append(metadata)
    for member, raw in sources.items():
        lines = raw.splitlines(keepends=True)
        for label, pattern, cap in PATTERNS:
            hits = [i for i, line in enumerate(lines) if re.search(pattern, line)]
            entry = {'source_member': member, 'name': label, 'pattern': pattern.decode('ascii'),
                'matches': len(hits), 'shown_matches': min(cap, len(hits)), 'truncated': len(hits) > cap, 'excerpts': []}
            # Preserve matching line numbers and exact source bytes. Nearby
            # contexts may overlap, but no omitted hit is claimed inspected.
            for number, index in enumerate(hits[:cap], 1):
                low, high = max(0, index-6), min(len(lines), index+9)
                body = b''.join(lines[low:high]); total += len(body)
                assert total <= 280000, 'Combined excerpt cap exceeded'
                filename = member.replace('/', '_').replace('.lua', '')+'__'+label+'_'+str(number)+'.lua'
                (output/filename).write_bytes(body)
                entry['excerpts'].append({'match_line': index+1, 'start_line': low+1, 'end_line': high,
                    'sha256': sha(body), 'excerpt_file': filename})
            manifest['neighborhoods'].append(entry)
    manifest['combined_output_bytes'] = total
    with (output/'inspection.json').open('x', encoding='utf-8') as stream:
        json.dump(manifest, stream, indent=2); stream.write('\n')
    return manifest


def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder/'registration.json').read_text(encoding='utf-8'))
    spent = json.loads((folder/'spent.json').read_text(encoding='utf-8'))
    assert registration['job'] == spent['job'] == 'M13' and registration['timeout_seconds'] == 30
    assert spent['registration_sha256'] == sha((folder/'registration.json').read_bytes())
    archive = Path(registration['metadata']['source_archive'])
    assert str(archive.resolve()) in registration['external_files']
    started = time.perf_counter(); manifest = inspect(archive, folder/'inspection')
    print(json.dumps({'job': 'M13', 'status': manifest['status'], 'elapsed_seconds': time.perf_counter()-started,
        'members': manifest['members'], 'methods': manifest['methods'],
        'matching_neighborhoods': [{key: row[key] for key in ('source_member', 'name', 'matches', 'shown_matches', 'truncated')}
                                 for row in manifest['neighborhoods'] if row['matches']],
        'combined_output_bytes': manifest['combined_output_bytes'], 'source_execution': False}), flush=True)


if __name__ == '__main__':
    main()
