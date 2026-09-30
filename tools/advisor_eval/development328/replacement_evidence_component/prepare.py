"""Prepare a detached one-line evidence-forwarding component, no evaluation."""
from pathlib import Path
import difflib
import hashlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
source=(ROOT/'Brainstorm/Advisor/strategy.lua').read_bytes()
before=source.decode('utf-8')
old="        replacement={utility_gain=sale.gain,cash_after_purchase=sale.remaining_cash}}"
new="        scoring_evidence=sale.scoring_evidence,\n"+old
assert before.count(old)==1
after=before.replace(old,new)
for name,data in [('baseline.lua',source),('strategy.lua',after.encode())]:
    with (HERE/name).open('xb') as stream:stream.write(data)
patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/Brainstorm/Advisor/strategy.lua',tofile='b/Brainstorm/Advisor/strategy.lua'))
with (HERE/'strategy.patch').open('x',encoding='utf-8',newline='') as stream:stream.write(patch)
print('prepared baseline '+hashlib.sha256(source).hexdigest())
