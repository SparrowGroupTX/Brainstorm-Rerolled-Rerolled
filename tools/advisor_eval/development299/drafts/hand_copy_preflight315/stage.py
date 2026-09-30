"""Root-only prospective staging. Default/--check is strictly read-only.

No installation, versioning, regression, game/source execution or registration.
All prior bytes are backed up before any requested root-file write.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
MANIFEST = HERE / 'integration_manifest.json'
STAGING = HERE / 'staging_manifest.json'
SOURCE_MANIFEST_SHA = '1fae3c305b75189aa8940974842f467beaaadf58f14a395ab66c1baf63a44156'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def plan():
    assert sha(MANIFEST.read_bytes()) == SOURCE_MANIFEST_SHA, 'Reviewed integration manifest changed'
    manifest = json.loads(MANIFEST.read_text())
    staging = json.loads(STAGING.read_text())
    assert staging['source_manifest_sha256'] == SOURCE_MANIFEST_SHA
    for name, expected in manifest['files'].items():
        assert sha((HERE / name).read_bytes()) == expected, f'Reviewed draft changed: {name}'
    for name, expected in staging['files'].items():
        assert sha((HERE / name).read_bytes()) == expected, f'Staging input changed: {name}'
    changes = []
    for name in ('hand_copy_preflight.lua', 'search.lua', 'decision.lua', 'runtime.lua'):
        target = ROOT / 'Brainstorm/Advisor' / name
        assert target.resolve().is_relative_to(ROOT.resolve())
        before = target.read_bytes() if target.exists() else None
        after = (HERE / name).read_bytes()
        mode = 'exact_reviewed_file'
        if name == 'hand_copy_preflight.lua':
            assert before is None, 'New module target already exists; preserve/review it separately'
        elif name == 'runtime.lua' and sha(before) != manifest['base_hashes']['Brainstorm/Advisor/runtime.lua']:
            anchor = b"A.phase_copy = module('phase_copy')"
            addition = b"A.hand_copy_preflight = module('hand_copy_preflight')"
            assert before.count(anchor) == 1 and addition not in before
            newline = b'\r\n' if b'\r\n' in before else b'\n'
            after = before.replace(anchor, anchor + newline + addition, 1)
            assert after.replace(newline + addition, b'', 1) == before
            mode = 'preserve_newer_runtime_add_one_load'
        else:
            assert sha(before) == manifest['base_hashes']['Brainstorm/Advisor/' + name], f'Current base changed: {name}'
        changes.append((target, before, after, mode))
    fixture = ROOT / 'tests/advisor_hand_copy_preflight.lua'
    assert not fixture.exists(), 'New fixture target already exists; preserve/review it separately'
    after = (HERE / fixture.name).read_bytes()
    for forbidden in (b'development299', b'drafts/', b'runs/', b'probe_policy'):
        assert forbidden not in after, 'Production fixture depends on development artifacts'
    assert b"local P='Brainstorm/Advisor/'" in after
    changes.append((fixture, None, after, 'new_production_path_fixture'))
    return changes


def receipt(changes):
    return [{'file': str(path.relative_to(ROOT)).replace('\\', '/'),
             'before_sha256': None if before is None else sha(before),
             'after_sha256': sha(after), 'mode': mode}
            for path, before, after, mode in changes]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--stage', action='store_true')
    parser.add_argument('--expected-staging-manifest')
    args = parser.parse_args()
    changes = plan()
    result = dict(schema=1, source_manifest_sha256=SOURCE_MANIFEST_SHA,
                  staging_manifest_sha256=sha(STAGING.read_bytes()), changes=receipt(changes),
                  installed=False, original_source_execution=False, experiment_registration=False)
    if not args.stage:
        result['status'] = 'checked_read_only_not_staged'
        print(json.dumps(result, indent=2))
        return
    assert args.expected_staging_manifest == result['staging_manifest_sha256'], 'Explicit reviewed staging manifest hash required'
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    backup = HERE / 'staging_backups' / token
    backup.mkdir(parents=True, exist_ok=False)
    # Preserve every existing root byte before any mutation, including newer
    # runtime additions. Never copy old settings, saves, DLLs or dependencies.
    for path, before, after, mode in changes:
        if before is not None:
            saved = backup / path.relative_to(ROOT)
            saved.parent.mkdir(parents=True, exist_ok=True)
            with saved.open('xb') as stream:
                stream.write(before)
    result.update(status='staging_started', backup=str(backup.relative_to(ROOT)),
                  stage_time_utc=datetime.now(timezone.utc).isoformat())
    journal = backup / 'record.json'
    journal.write_text(json.dumps(result, indent=2) + '\n')
    for path, before, after, mode in changes:
        current = path.read_bytes() if path.exists() else None
        assert current == before, f'Concurrent root change; stop without overwriting {path}'
        if before is None:
            with path.open('xb') as stream:
                stream.write(after)
        else:
            with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + '.staging-', delete=False) as stream:
                stream.write(after)
                temporary = Path(stream.name)
            os.replace(temporary, path)
        assert sha(path.read_bytes()) == sha(after)
    result['status'] = 'staged_not_installed'
    journal.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
