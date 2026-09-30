"""Stage source-backed row identities; reads preserved source, never executes it."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
target = 'Brainstorm/Advisor/gold_tarot_hold.lua'
goal_path = 'Brainstorm/Advisor/gold_goal.lua'
source_path = 'tools/advisor_eval/runs/roi247_catalog_source/source_probe.lua'
card_path = 'tools/advisor_eval/runs/chicot_order_source1/source/card.lua'
original = (ROOT / target).read_text(encoding='utf-8')
goal = (ROOT / goal_path).read_text(encoding='utf-8')
source = (ROOT / source_path).read_text(encoding='utf-8')
stable = set(re.search(r'for key in \(\[=\[(.*?)\]=\]\)', goal, re.S)[1].split())
stable.add('j_perkeo')
catalog = {}
for line_number, line in enumerate(source.splitlines(), 1):
    m = re.match(r'''^(j_\w+)=.*?\bname\s*=\s*(["'])(.*?)\2''', line)
    if m:
        catalog[m[1]] = {'name': m[3], 'line': line_number}
assert len(catalog) == 150
assert stable <= catalog.keys()
catalog_text = '\n'.join(f'{key}={catalog[key]["name"]}' for key in sorted(stable))
replacement = '''-- Exact source names for the existing Gold stable-retention family, plus
-- Perkeo. Source: preserved roi247_catalog_source/source_probe.lua centers.
-- In original Card:calculate_joker, ending_shop only creates cards through
-- Perkeo (including Blueprint/Brainstorm forwarding); these stable identities
-- do not read unused Tarot identities/counts for the first-hand score. The
-- ordinary Gold/Shop guards still qualify paid transitions, startup and score.
-- Keep this boundary synchronized with gold_goal.stable_card: the standalone
-- row fixture checks both directions against the preserved source catalog.
local row_names={}
for line in ([=[
''' + catalog_text + '''
]=]):gmatch('[^\\r\\n]+') do
  local key,label=line:match('^(j_[%w_]+)=(.+)$');row_names[key]=label
end
'''
changed, count = re.subn(r'local row_names=\{.*?\}\n(?=local function finite)', lambda _: replacement, original, count=1, flags=re.S)
assert count == 1
for relative in (target, goal_path):
    p = OUT / 'before' / relative
    p.parent.mkdir(parents=True, exist_ok=True)
    assert not p.exists()
    p.write_bytes((ROOT / relative).read_bytes())
destination = OUT / target
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(changed, encoding='utf-8', newline='\n')
catalog_output = OUT / 'source_catalog.json'
catalog_output.write_text(json.dumps(catalog, indent=2)+'\n', encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {'schema': 1, 'runtime_target': target, 'before_sha256': sha(ROOT / target),
 'staged_sha256': sha(destination), 'row_identity_count': len(stable),
 'source_files': {p: sha(ROOT / p) for p in (source_path, card_path, goal_path)},
 'source_lines': {'center_names': [167,316], 'copy_resolvers': [2303,2333], 'ending_shop': [2412,2428]},
 'authority': 'Read-only preserved source and manufactured fixtures; no source execution, captured replay or new worker lease.',
 'scope': 'Qualified fixed-hold unused Tarot score equivalence; existing stable row identities only.'}
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'rows': len(stable), 'staged': str(destination), 'sha256': manifest['staged_sha256']}))
