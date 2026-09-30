"""Bind the corrected imported helper explicitly; preserve prior audit artifacts."""
from pathlib import Path
import ast
import json
import hashlib

HERE = Path(__file__).resolve().parent
source = (HERE / 'audit_final.py').read_text()
text = source.replace("output = FOLDER / 'audit_final.json'", "output = FOLDER / 'audit_verified.json'").replace("Path(__file__).with_name('mechanics.py')", "Path(__file__).with_name('mechanics_final.py')")
assert text != source
ast.parse(text)
with (HERE / 'audit_verified.py').open('x', encoding='utf-8', newline='\n') as stream:
    stream.write(text)
with (HERE / 'helper_binding_correction.json').open('x', encoding='utf-8') as stream:
    json.dump({'reason': 'The corrected auditor imported mechanics_final.py but its descriptive helper hash map still named mechanics.py. Correct the hash map without changing outcome/receipt checks. Preserve both preceding outputs.',
               'prior_auditor_sha256': hashlib.sha256((HERE / 'audit_final.py').read_bytes()).hexdigest(),
               'selected_auditor_sha256': hashlib.sha256((HERE / 'audit_verified.py').read_bytes()).hexdigest(),
               'corrected_helper_sha256': hashlib.sha256((HERE / 'mechanics_final.py').read_bytes()).hexdigest()}, stream, indent=2)
    stream.write('\n')
