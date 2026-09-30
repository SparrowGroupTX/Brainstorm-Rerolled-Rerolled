"""Inert Lua module doubles only. Never initializes source or evaluates a decision."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import importlib.util
import json
import subprocess
import sys
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run(policy_root, output):
    policy_root = Path(policy_root).resolve(); policy_root.relative_to(ROOT)
    output = Path(output).resolve(); output.relative_to(HERE)
    assert not output.exists(), 'Never replace a prior graph receipt'
    spec = importlib.util.spec_from_file_location('c07_benchmark_inert', HERE / 'benchmark.py')
    helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
    hashes = helper.policy_hashes(policy_root)
    fixture_names = ('engine_run.lua', 'policy_wiring.lua', 'test_wiring.lua', 'check_graph.py')
    fixture_hashes = {name: sha(HERE / name) for name in fixture_names}
    scratch = HERE / 'graph_checks' / uuid.uuid4().hex
    scratch.mkdir(parents=True, exist_ok=False)
    raw = scratch / 'raw.json'; wrapper = scratch / 'run.lua'
    def quote(value):
        # Paths are forward slashes, so the only escaped bytes are ordinary JSON/Lua quotes.
        value = str(value).replace('\\', '/')
        assert all(32 <= ord(c) < 127 for c in value), 'Fixture paths must be plain ASCII'
        return json.dumps(value)
    wrapper.write_text('C07_ADAPTER_PATH=' + quote(HERE.as_posix() + '/') + '\n' +
                       'C07_POLICY_PATH=' + quote(policy_root.as_posix() + '/') + '\n' +
                       'C07_GRAPH_REPORT=' + quote(raw) + '\n' +
                       'dofile(' + quote(HERE / 'test_wiring.lua') + ')\n')
    command = [sys.executable, '-B', str(ROOT / 'tests/run_lua_tests.py'), str(wrapper)]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=15, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    (scratch / 'stdout.log').write_text(result.stdout)
    assert result.returncode == 0, result.stdout
    graph = json.loads(raw.read_text())
    assert graph['passed'] and graph['source_initialized'] is False and graph['policy_decisions'] == 0
    assert hashes == helper.policy_hashes(policy_root), 'Policy changed during inert check'
    assert fixture_hashes == {name: sha(HERE / name) for name in fixture_names}, 'Adapter changed during check'
    report = {'kind': 'c07_complete_installed_graph_check', 'timestamp_utc': datetime.now(timezone.utc).isoformat(),
              'passed': True, 'policy_root': str(policy_root), 'policy_files': hashes,
              'policy_digest': helper.digest(hashes), 'adapter_files': fixture_hashes, 'graph': graph,
              'raw_report_sha256': sha(raw), 'stdout_sha256': sha(scratch / 'stdout.log'),
              'scratch': str(scratch), 'source_initializations': 0, 'policy_decisions': 0}
    with output.open('x') as stream: json.dump(report, stream, indent=2); stream.write('\n')
    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--policy-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True); args = parser.parse_args()
    report = run(args.policy_root, args.output)
    print(json.dumps({'passed': True, 'checks': report['graph']['checks'], 'modules': len(report['graph']['modules']),
                      'edges': len(report['graph']['connections']), 'policy_digest': report['policy_digest'],
                      'receipt_sha256': sha(args.output)}))
