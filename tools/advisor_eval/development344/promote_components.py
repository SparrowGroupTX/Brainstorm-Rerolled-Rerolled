"""Promote sealed manufactured-tested modules and relocate fixture imports."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def put(path,contents):
    p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f: f.write(contents)
def module(component,relative,digest):
    b=(HERE/component/relative).read_bytes()
    assert hashlib.sha256(b).hexdigest()==digest
    put('Brainstorm/Advisor/'+Path(relative).name,b)
module('acquisition_component','Brainstorm/Advisor/gold_acquisition.lua','96630da01936ef730ce45f4af5016dbefd2270515974ff93b0adfce54a6348ea')
helper=HERE/'tarot_hold_component'
assert hashlib.sha256((ROOT/'Brainstorm/Advisor/gold_tarot_hold.lua').read_bytes()).hexdigest()=='0d831d99900f4a19bae3bc3643d65779b29a0896f840ea0241a141d9a1508522'
support=(helper/'fixture_support.lua').read_text(encoding='utf-8').replace('tools/advisor_eval/development344/tarot_hold_component/gold_tarot_hold.lua','Brainstorm/Advisor/gold_tarot_hold.lua')
put('tests/fixtures/gold_tarot_hold_support.lua',support.encode())
fixture=(helper/'fixture.lua').read_text(encoding='utf-8').replace('tools/advisor_eval/development344/tarot_hold_component/fixture_support.lua','tests/fixtures/gold_tarot_hold_support.lua')
put('tests/advisor_gold_tarot_hold.lua',fixture.encode())
fixture=(HERE/'acquisition_component/tests/advisor_gold_acquisition.lua').read_text(encoding='utf-8').replace('tools/advisor_eval/development344/acquisition_component/Brainstorm/Advisor/gold_acquisition.lua','Brainstorm/Advisor/gold_acquisition.lua').replace('tools/advisor_eval/development344/tarot_hold_component/fixture_support.lua','tests/fixtures/gold_tarot_hold_support.lua')
put('tests/advisor_gold_acquisition.lua',fixture.encode())
