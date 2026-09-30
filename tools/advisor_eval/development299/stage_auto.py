"""Stage the reviewed opt-in controller and product adapters; never activate."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[3]
draft=ROOT/'tools/advisor_eval/development299/drafts'
parts=[('auto_run/auto_run.lua','Brainstorm/Advisor/auto_run.lua','9d7b3734094ca7c4fd344cfe7d5be2970f3ae5c6876af2a705b17074e526a4bf'),
 ('auto_product/auto_terminal.lua','Brainstorm/Core/auto_terminal.lua','341f2c7e0163780aeafa6c37a727a16488402d33e1ee0abe7331a232b4fe7b00'),
 ('auto_product/auto_run_product.lua','Brainstorm/Core/auto_run_product.lua','5879f1e0732c105d7bc5477cfc24af2e17fec8ee5ae9b2dcfa1429587e834cdf')]
for name,target,expected in parts:
    data=(draft/name).read_bytes();assert hashlib.sha256(data).hexdigest()==expected,name
    with (ROOT/target).open('xb') as stream:stream.write(data)
for name in ('auto_run/advisor_auto_run.lua','auto_product/advisor_auto_terminal.lua','auto_product/advisor_auto_run_product.lua'):
    source=(draft/name).read_text()
    for old,new,_ in parts:
        source=source.replace('tools/advisor_eval/development299/drafts/'+old,new)
    with (ROOT/'tests'/Path(name).name).open('x',encoding='utf-8',newline='\n') as stream:stream.write(source)
print('Staged3runtime modules and3synthetic fixtures; no activation.')
