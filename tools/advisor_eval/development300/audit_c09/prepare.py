"""Prepare pure C09 audit adaptation only; never run its audit or any worker."""
from pathlib import Path
import ast
import hashlib
import json

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'audit_c07'
origins={}
for name in ('audit.py','validation.py','mechanics.py'):
    original=(SOURCE/name).read_bytes();text=original.decode('utf-8')
    if name=='audit.py':
        text=text.replace('C07','C09').replace('exact frozen320','exact frozen321').replace('C01/C02/C04/C06','C01/C02/C04/C06/C07')
        text=text.replace('e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966','fd5c42031000f79ecba48ceee72f000aa3d1b7a0c51ed54895d36cfab53e4da5')
    elif name=='validation.py':
        text=text.replace("== 'C07'","== 'C09'").replace('2.120.0-alpha','2.121.0-alpha').replace("== 320","== 321")
        text=text.replace('prior_C04_registration.json','source_C07_registration.json').replace('Original S04/C04','Original S04/C07')
    else:
        start=text.index('def verify_graph_receipt(');end=text.index('\ndef card_summary(',start)
        text=text[:start]+"from graph_binding import verify_graph_receipt\n"+text[end:]
        text=text.replace('Read-only C07','Read-only C09')
    ast.parse(text,filename=name)
    with (HERE/name).open('x',encoding='utf-8',newline='\n') as stream:stream.write(text)
    origins[name]={'source':str(SOURCE/name),'source_sha256':hashlib.sha256(original).hexdigest(),'created_sha256':hashlib.sha256((HERE/name).read_bytes()).hexdigest()}
with (HERE/'origins.json').open('x',encoding='utf-8') as stream:json.dump(origins,stream,indent=2);stream.write('\n')
print(json.dumps({'prepared':True,'files':origins,'audit_executed':False},indent=2))
