"""M24 source-byte inspection only. Never import/execute Lua or policy code."""
from pathlib import Path
import json
import time
import zipfile
from source_lexer import excerpt, sha

MEMBERS = ('engine/ui.lua', 'functions/button_callbacks.lua', 'engine/moveable.lua')
METHODS = (
    ('ui_box_init', 'engine/ui.lua', r'function\s+UIBox:init\s*\('),
    ('ui_box_remove', 'engine/ui.lua', r'function\s+UIBox:remove\s*\('),
    ('ui_box_get_by_id', 'engine/ui.lua', r'function\s+UIBox:get_UIE_by_ID\s*\('),
    ('ui_element_init', 'engine/ui.lua', r'function\s+UIElement:init\s*\('),
    ('cash_out', 'functions/button_callbacks.lua', r'G\.FUNCS\.cash_out\s*=\s*function\b'),
    ('moveable_remove', 'engine/moveable.lua', r'function\s+Moveable:remove\s*\('),
)
EXCERPT_CAP = 33000
TOTAL_CAP = 40000


def inspect(archive, output):
    output.mkdir(exist_ok=False)
    result = dict(schema=1, job='M24', status='incomplete_explicit', qualification=False,
                  scope='ZIP-byte cash-out UI ownership and cleanup inspection; no Lua/policy/native execution',
                  maximum_members=3, maximum_methods=6, output_cap_bytes=TOTAL_CAP,
                  source_excerpt_cap_bytes=EXCERPT_CAP, members={}, methods=[])
    sources = {}
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        assert len(entries) <= 20000, 'Archive entry limit exceeded'
        for name in MEMBERS:
            matches = [e for e in entries if e.filename.replace('\\', '/').lower() == name.lower()]
            if len(matches) != 1:
                result['members'][name] = dict(status='missing' if not matches else 'ambiguous')
                continue
            entry = matches[0]
            assert entry.file_size <= 4*1024*1024, 'Source member exceeds4MiB read cap'
            raw = z.read(entry)
            sources[name] = raw
            result['members'][name] = dict(status='read', archive_member=entry.filename,
                                            bytes=len(raw), sha256=sha(raw))
    remaining = EXCERPT_CAP
    for label, member, pattern in METHODS:
        meta, body = excerpt(sources.get(member, b''), pattern, 1000000)
        complete = meta.get('status') == 'found' and not meta.get('truncated', False)
        admitted = complete and len(body) <= remaining
        if admitted:
            with (output / (label+'.lua')).open('xb') as stream:
                stream.write(body)
            remaining -= len(body)
            meta['excerpt_file'] = label+'.lua'
        else:
            meta['omission_reason'] = ('complete method exceeds remaining output allowance' if complete else
                                       'missing, ambiguous or incomplete method boundary')
        meta.update(name=label, source_member=member, declaration_pattern=pattern,
                    complete_method=admitted, shown_bytes=len(body) if admitted else 0,
                    excerpt_sha256=sha(body) if admitted else None,
                    truncated=False if admitted else meta.get('truncated', False))
        result['methods'].append(meta)
    result['output_bytes'] = EXCERPT_CAP-remaining
    result['complete_methods'] = sum(m['complete_method'] for m in result['methods'])
    if result['complete_methods'] == len(METHODS):
        result['status'] = 'complete'
    encoded = (json.dumps(result, separators=(',', ':'))+'\n').encode('utf-8')
    assert len(encoded) <= 6000, 'Manifest exceeds reserved metadata cap'
    with (output/'inspection.json').open('xb') as stream:
        stream.write(encoded)
    return result


def main():
    folder = Path(__file__).resolve().parent
    registration_bytes = (folder/'registration.json').read_bytes()
    registration = json.loads(registration_bytes)
    spent = json.loads((folder/'spent.json').read_text())
    assert folder.name == registration['job'] == spent['job'] == 'M24'
    assert spent['one_use'] is True and spent['registration_sha256'] == sha(registration_bytes)
    assert registration['timeout_seconds'] == 30
    metadata = registration['metadata']
    assert metadata['kind'] == 'cashout_ui_ownership_source_inspection_v1'
    assert metadata['maximum_members'] == 3 and metadata['maximum_methods'] == 6
    assert metadata['combined_output_cap_bytes'] == TOTAL_CAP
    assert metadata['policy_execution'] is False and metadata['source_execution'] is False
    assert metadata['lua_runtime_loaded'] is False and metadata['native_search'] is False
    for name in ('inspect_source.py', 'source_lexer.py'):
        assert sha((folder/name).read_bytes()) == registration['files'][name]
    assert not (folder/'record.json').exists() and not (folder/'inspection').exists()
    archive = Path(metadata['source_archive']).resolve()
    assert registration['external_files'][str(archive)] == metadata['expected_source_sha256']
    # The one-use parent runner verifies full external hashes immediately before
    # launch. This worker only opens the three declared members from that ZIP.
    started = time.perf_counter()
    result = inspect(archive, folder/'inspection')
    summary = json.dumps(dict(job='M24', elapsed_seconds=time.perf_counter()-started,
                              status=result['status'], complete_methods=result['complete_methods'],
                              output_bytes=result['output_bytes'], source_execution=False,
                              policy_execution=False, lua_runtime_loaded=False, native_search=False,
                              game_or_save_access=False, inspection_file='inspection/inspection.json'))
    assert len(summary.encode('utf-8')) < 1000
    print(summary, flush=True)


if __name__ == '__main__':
    main()
