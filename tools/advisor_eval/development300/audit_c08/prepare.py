"""Create detached read-only C08 audit tooling from exact C07 helpers."""
from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'audit_c07'
origins = {}
for name in ('audit.py', 'validation.py', 'mechanics.py'):
    original = (SOURCE / name).read_bytes()
    text = original.decode('utf-8').replace('C07', 'C08').replace('M4BVSY11', 'S7PXV521')
    if name == 'audit.py':
        text = text.replace('original S04 fixed-target recipe previously used by C01/C02/C04/C06',
                            'original S05 OR-copy recipe previously used by C03/C05')
    if name == 'validation.py':
        text = text.replace('S04', 'S05').replace('prior_C04_registration.json', 'prior_C05_registration.json').replace('S05/C04', 'S05/C05')
        # Lowercase schema names intentionally remain c07: C08 registered the
        # same exact source adapter/graph, not a newly relabelled graph run.
        anchor = "    expected_binaries = {'balatro.exe', 'lua51.dll', Path(metadata['python_executable']).name.lower()}"
        assert anchor in text
        extra = """    prior_source = read('source_C07_registration.json')
    graph = read('installed_graph_check.json')
    same_graph_files = set(graph.get('adapter_files', {})) | {'installed_graph_check.json', 'inert_graph_raw.json', 'inert_graph_stdout.log', 'check_graph.py'}
    check(all(registration['files'].get(name) == prior_source['files'].get(name) for name in same_graph_files), 'Registered graph reuse differs from exact C07 adapter/checker/receipt bytes')
    check(metadata.get('product_execution_ui_bypassed') is True, 'Source adapter UI boundary differs')
"""
        text = text.replace(anchor, extra + anchor)
    ast.parse(text, filename=name)
    with (HERE / name).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(text)
    origins[name] = {'source': str(SOURCE / name), 'source_sha256': hashlib.sha256(original).hexdigest(),
                     'created_sha256': hashlib.sha256((HERE / name).read_bytes()).hexdigest()}
with (HERE / 'origins.json').open('x', encoding='utf-8') as stream:
    json.dump({'scope': 'Prepare and AST-parse read-only audit helpers only; no source, policy, adapter or game execution.',
               'files': origins}, stream, indent=2); stream.write('\n')
print(json.dumps({'prepared': True, 'files': origins}, indent=2))
