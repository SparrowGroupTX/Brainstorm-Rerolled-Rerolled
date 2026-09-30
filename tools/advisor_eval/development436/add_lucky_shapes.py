"""Copy detached literal metadata; no game component or policy is evaluated."""
from pathlib import Path
import re
p=Path('Brainstorm/Advisor/scoring.lua');s=p.read_text(encoding='utf-8')
start=s.index('local lucky_owned_keys=');end=s.index('function M.sampled_lucky_plan',start)
keys=re.findall(r'(j_\w+)=',s[start:end]);lines=Path('tests/fixtures/joker_centers421.lua').read_text().splitlines()
shapes={}
for line in lines:
 m=re.search(r'key="(j_\w+)".*?,ability=(.*),rarity=',line)
 if m:shapes[m[1]]=m[2]
assert len(keys)==len(set(keys))and all(k in shapes for k in keys)
replacement='local lucky_owned_shapes={\n'+''.join('    '+k+'='+shapes[k]+',\n'for k in keys)+'}\n'
s=s[:start]+replacement+s[end:]
s=s.replace("not lucky_owned_keys[j.key] or name(j)~=lucky_owned_keys[j.key]", "not lucky_owned_shapes[j.key] or name(j)~=lucky_owned_shapes[j.key].name")
p.write_text(s,encoding='utf-8',newline='\n')
print('Copied',len(keys),'literal canonical ability shapes')
