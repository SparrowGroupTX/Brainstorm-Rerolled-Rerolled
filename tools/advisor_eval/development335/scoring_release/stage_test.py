"""Stage an independent production fixture without changing production or tests."""
from pathlib import Path
import hashlib

HERE = Path(__file__).resolve().parent
COMPONENT = HERE.parent / 'scoring_component'
source = (COMPONENT / 'test_scoring_reuse.lua').read_bytes()
assert hashlib.sha256(source).hexdigest() == '0ca66e94cade5acaf8174e30e33c389c6f3b6bfa8d823f03dd244b7456e582c7'
text = source.decode('utf-8')
text = text.replace("local folder='tools/advisor_eval/development335/scoring_component/'",
                    "local before_path='tests/fixtures/advisor_scoring_reuse336/scoring_before.lua'\n"
                    "local candidate_path='Brainstorm/Advisor/scoring.lua'")
text = text.replace("folder..'scoring_before.lua'", 'before_path')
text = text.replace("folder..'scoring.lua'", 'candidate_path')
assert 'development335' not in text and 'folder' not in text
data = text.encode('utf-8')
destination = HERE / 'advisor_scoring_reuse.lua'
if destination.exists():
    prior = destination.read_bytes()
    assert hashlib.sha256(prior).hexdigest() == 'c4f90beee2cafbbf3039d1af4131ef6c27db3135d9c2c5c58f059fe36f346740'
    with (HERE / 'before_nominal_advisor_scoring_reuse.lua').open('xb') as stream:
        stream.write(prior)
destination.write_bytes(data)
print(hashlib.sha256(data).hexdigest())
