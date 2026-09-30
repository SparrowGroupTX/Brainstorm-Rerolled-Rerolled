"""Prepare detached nine-card admission; no policy/source execution."""
from pathlib import Path
import difflib
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
source=(ROOT/'Brainstorm/Advisor/concealed_belief.lua').read_bytes();before=source.decode()
assert before.count('#s.hand>8')==1 and before.count('#state.hand>8')==1
after=before.replace('#s.hand>8','#s.hand>9').replace('#state.hand>8','#state.hand>9')
after=after.replace('at most eight held cards and a bounded deck.','at most nine held cards and a bounded deck.')
for name,data in [('baseline.lua',source),('concealed_belief.lua',after.encode())]:
    with (HERE/name).open('xb') as stream:stream.write(data)
patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/Brainstorm/Advisor/concealed_belief.lua',tofile='b/Brainstorm/Advisor/concealed_belief.lua'))
with (HERE/'concealed_belief.patch').open('x',encoding='utf-8',newline='') as stream:stream.write(patch)
print('Prepared detached bounded nine-card admission')
