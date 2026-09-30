from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / 'Brainstorm/Advisor/scoring.lua'
baseline = SOURCE.read_bytes()
text = baseline.decode('utf-8')
constants = [
    ('enhancement_effects', re.search(r"\{\['Stone Card'\]='m_stone'.*?\['Lucky Card'\]='m_lucky'\}", text, re.S).group()),
    ('score_blind_names', re.search(r"\{bl_psychic='The Psychic'.*?bl_hook='The Hook'\}", text).group()),
    ('classification_suits', "{'Spades','Hearts','Clubs','Diamonds'}"),
    ('seeing_double_suits', "{'Clubs','Diamonds','Spades','Hearts'}"),
    ('flower_pot_suits', "{'Hearts','Diamonds','Spades','Clubs'}"),
]
for name, literal in constants:
    assert text.count(literal) == 1, name
    text = text.replace(literal, name)
    text = text.replace('(' + name + ')[', name + '[')
declarations = '-- Immutable lookup data; no card, row or score results are retained.\r\n'
declarations += '\r\n'.join('local ' + name + '=' + literal for name, literal in constants) + '\r\n'
text = text.replace('local M = {}\r\n', 'local M = {}\r\n' + declarations, 1)
scan = "    for _,ci in ipairs(held) do local c=hand[ci]; if enh(c)~='m_stone' and rank(c)<=lowest_rank then lowest,lowest_rank=ci,rank(c) end end"
assert text.count(scan) == 1
text = text.replace(scan, "    -- Only an active Raised Fist route consumes the lowest held-card result.\r\n"
                         "    -- Copy routes require that same nondebuffed source in the row flags.\r\n"
                         "    if f['Raised Fist'] then\r\n" + scan.replace('    for', '        for', 1) + '\r\n    end')
candidate = text.encode('utf-8')
for name, content in [('scoring_before.lua', baseline), ('scoring.lua', candidate)]:
    with (HERE / name).open('xb') as stream:
        stream.write(content)
manifest = {
    'source': str(SOURCE),
    'baseline_sha256': hashlib.sha256(baseline).hexdigest(),
    'candidate_sha256': hashlib.sha256(candidate).hexdigest(),
    'changes': ['Hoist five immutable enhancement/blind/suit lookup tables.',
                'Skip lowest-held-card scan unless existing flags contain active Raised Fist.'],
    'cache_scope': 'No new state cache; every lookup reads current inputs.',
    'constant_literals': dict(constants),
}
with (HERE / 'candidate_manifest.json').open('x', encoding='utf-8') as stream:
    json.dump(manifest, stream, indent=2)
    stream.write('\n')
print(json.dumps({key: value for key, value in manifest.items() if key != 'constant_literals'}, indent=2))
