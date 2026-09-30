"""Preserve the first audit; correct its C07-only duplicate metadata expectation."""
from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
before = (HERE / 'mechanics.py').read_text()
old = """    check(required.get('files') == registration['metadata'].get('reviewed_feature_files')
          and all(registered.get(name) == value for name, value in required.get('files', {}).items()),
          'Reviewed exact feature bytes differ')"""
new = """    source_registration = read('source_C07_registration.json')
    check(registration['files'].get('required_features.json') == sha(folder / 'required_features.json')
          and registration['files'].get('source_C07_registration.json') == sha(folder / 'source_C07_registration.json')
          and required.get('files') == source_registration['metadata'].get('reviewed_feature_files')
          and all(registered.get(name) == value for name, value in required.get('files', {}).items()),
          'Reviewed exact feature bytes differ')"""
assert old in before
files = {'mechanics_final.py': before.replace(old, new),
         'audit_final.py': (HERE / 'audit.py').read_text().replace('from mechanics import', 'from mechanics_final import').replace("output = FOLDER / 'audit.json'", "output = FOLDER / 'audit_final.json'")}
hashes = {}
for name, text in files.items():
    ast.parse(text, filename=name)
    with (HERE / name).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(text)
    hashes[name] = hashlib.sha256((HERE / name).read_bytes()).hexdigest()
with (HERE / 'metadata_projection_correction.json').open('x', encoding='utf-8') as stream:
    json.dump({'reason': 'The first audit inherited a C07-only duplicate metadata map requirement. C08 freezes the same reviewed feature file and exact whole policy, but does not duplicate that map in metadata. Verify the registered file hash, frozen source C07 reviewed map and exact frozen policy instead.',
               'first_audit_preserved': 'runs/gold299_20260914/C08/audit.json',
               'first_audit_sha256': 'd49d1841add47ef73238df606b63d75f20870e82b599a0dc23b1bf56994ce4ea',
               'new_files': hashes, 'source_evaluations': 0, 'policy_evaluations': 0}, stream, indent=2)
    stream.write('\n')
print(json.dumps(hashes, indent=2))
