"""Bind a comment-only accuracy correction without overwriting sealed evidence."""
from pathlib import Path
import hashlib
import json

revision = Path(__file__).resolve().parent
root = revision.parents[4]
path = revision / 'Brainstorm/Advisor/gold_acquisition.lua'
before = revision / 'before_comment_gold_acquisition.lua'
old = before.read_bytes()
expected = old.replace(b'-- Shop yields between score calls. Lua 5.1 cannot yield through pcall;\n'
                       b"    -- unexpected errors retain the runtime worker's ordinary error handling.",
                       b'-- Avoid requiring yieldable protected calls; Shop yields between score\n'
                       b"    -- calls. Unexpected errors retain the runtime worker's error handling.")
assert expected != old and path.read_bytes() == expected
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
prior = revision / 'result.json'
result = json.loads(prior.read_text(encoding='utf-8'))
for item in result['files']:
    if item['destination'] == 'Brainstorm/Advisor/gold_acquisition.lua':
        item['sha256'] = digest(path)
result['comment_only_correction'] = {'preserved_previous_module': str(before.relative_to(root)),
                                    'before_sha256': digest(before), 'after_sha256': digest(path),
                                    'previous_result_sha256': digest(prior),
                                    'reason': 'Describe avoiding a portability requirement without claiming the installed runtime cannot yield through pcall; the preserved baseline passed.',
                                    'functional_bytes_unchanged_except_two_comment_lines': True}
with (revision / 'result_final.json').open('x', encoding='utf-8') as stream:
    json.dump(result, stream, indent=2)
    stream.write('\n')
print(json.dumps({'module_sha256': digest(path), 'result_sha256': digest(revision / 'result_final.json')}))
