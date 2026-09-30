from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put_new(p,bytes):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(bytes)
def relocation(text):
    return text.replace('tools/advisor_eval/development344/tarot_hold_component/fixture_support.lua','tests/fixtures/gold_tarot_hold_support.lua')
# Existing promoted v1 is retained in its sealed staging component.
revision=HERE/'acquisition_component/revision2'
assert sha(ROOT/'Brainstorm/Advisor/gold_acquisition.lua')=='96630da01936ef730ce45f4af5016dbefd2270515974ff93b0adfce54a6348ea'
record=json.loads((revision/'result_final.json').read_text())
for row in record['files']:
    p=ROOT/row['staged_path'];assert sha(p)==row['sha256']
    text=p.read_text(encoding='utf-8')
    text=relocation(text).replace('tools/advisor_eval/development344/acquisition_component/revision2/Brainstorm/Advisor/gold_acquisition.lua','Brainstorm/Advisor/gold_acquisition.lua')
    if p.name=='advisor_gold_acquisition_runtime.lua':
        text=text.replace("A.gold_acquisition=dofile(ACQUISITION_TEST_MODULE or 'Brainstorm/Advisor/gold_acquisition.lua')\n",'')
    target=ROOT/row['destination']
    if target.exists():target.write_text(text,encoding='utf-8',newline='\n')
    else:put_new(target,text.encode())
journal=HERE/'log_diagnostics_component';record=json.loads((journal/'component_report.json').read_text())
target=ROOT/record['runtime_file'];assert sha(target)==record['runtime_before_sha256']
staged=journal/record['runtime_file'];assert sha(staged)==record['runtime_staged_sha256']
put_new(HERE/'root_component/before/Brainstorm/Advisor/player_journal.lua',target.read_bytes())
target.write_bytes(staged.read_bytes())
p=journal/record['test_file'];assert sha(p)==record['test_sha256'];put_new(ROOT/record['test_file'],p.read_bytes())
p=HERE/'tarot_hold_component/snapshot_hook_fixture.lua'
put_new(ROOT/'tests/advisor_gold_tarot_capture.lua',relocation(p.read_text()).encode())
print('Promoted reviewed revision2, current-only journal diagnostics and actual snapshot fixture.')
