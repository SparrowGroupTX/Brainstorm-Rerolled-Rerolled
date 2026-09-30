"""One-use, frozen, bounded experiment launcher; never touches the game.

Caps count coordinator wall time, including all children. They are not claims
about summed CPU time. The manifest explicitly bounds parallelism separately.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'tools/advisor_eval/development355'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stamp():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def launch(job_id, module, arguments):
    manifest = json.loads((EVIDENCE / 'EXPERIMENT_355.json').read_text())
    spec = manifest['jobs'][job_id]
    if module != spec['module']:
        raise ValueError('Module is not registered for this job')
    if (EVIDENCE / 'CLOSED.json').exists():
        raise RuntimeError('Experiment closed; unused jobs cannot be renewed')
    directory = EVIDENCE / 'jobs' / job_id
    directory.mkdir(parents=True, exist_ok=False)  # Spent even on setup failure.
    record = {'job': job_id, 'status': 'reserved', 'started_utc': stamp(),
              'spec': spec, 'manifest_sha256': digest(EVIDENCE / 'EXPERIMENT_355.json'),
              'arguments': arguments, 'python': sys.executable}
    write_json(directory / 'receipt.json', record)
    started = time.monotonic()
    try:
        frozen = directory / 'frozen'
        package = frozen / 'tools/advisor_learning'
        package.mkdir(parents=True)
        for path in (ROOT / 'tools/advisor_learning').glob('*.py'):
            shutil.copy2(path, package / path.name)
        sim = EVIDENCE / 'external/jackdaw/jackdaw'
        shutil.copytree(sim, frozen / 'simulator/jackdaw',
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        hashes = {str(p.relative_to(frozen)).replace('\\', '/'): digest(p)
                  for p in frozen.rglob('*') if p.is_file()}
        write_json(directory / 'provenance.json', {
            'files': hashes, 'external_provenance_sha256': digest(EVIDENCE / 'external/provenance.json'),
            'simulator_qualified': False,
            'profile': 'isolated_simulator_default_catalog_not_player_profile',
            'runtime': sys.version, 'source_installation': 'untouched'})
        env = os.environ.copy()
        env.update({'PYTHONHASHSEED': '355', 'PYTHONDONTWRITEBYTECODE': '1',
                    'BRAINSTORM_LEARNING_SIM_PATH': str(frozen / 'simulator'),
                    'BRAINSTORM_LEARNING_JOB': str(directory),
                    'OMP_NUM_THREADS': '1', 'MKL_NUM_THREADS': '1'})
        command = [sys.executable, '-u', '-m', module, *arguments,
                   '--job-dir', str(directory), '--wall-seconds', str(spec['seconds']),
                   '--max-transitions', str(spec['transitions']),
                   '--max-episodes', str(spec['episodes'])]
        record.update(status='running', command=command, frozen_sha256=hashlib.sha256(
            json.dumps(hashes, sort_keys=True).encode()).hexdigest())
        write_json(directory / 'receipt.json', record)
        with (directory / 'stdout.log').open('wb') as out:
            process = subprocess.Popen(command, cwd=frozen, env=env, stdout=out,
                                       stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            record['pid'] = process.pid
            write_json(directory / 'receipt.json', record)
            remaining = max(0.1, spec['seconds'] - (time.monotonic() - started))
            try:
                record['returncode'] = process.wait(timeout=remaining)
                record['status'] = 'completed' if process.returncode == 0 else 'error'
            except subprocess.TimeoutExpired:
                record['status'] = 'timeout'
                # Only this job's process tree; never a game process/name.
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                               capture_output=True, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                process.wait(timeout=10)
    except BaseException as exc:
        record.update(status='error', error=repr(exc))
        raise
    finally:
        record['elapsed_seconds'] = time.monotonic() - started
        record['finished_utc'] = stamp()
        write_json(directory / 'receipt.json', record)
        print(json.dumps(record, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('job')
    parser.add_argument('module')
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    launch(args.job, args.module, args.arguments)
