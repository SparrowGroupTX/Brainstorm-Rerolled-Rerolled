"""Prospective M23 ZIP-byte input dispatch inspection. Never execute Lua/game."""
from pathlib import Path
import json,time,zipfile
from source_lexer import excerpt,sha
MEMBERS=('main.lua','engine/controller.lua','game.lua','engine/ui.lua')
METHODS=(
 ('mousepressed','main.lua',r'function\s+love\.mousepressed\s*\('),
 ('mousereleased','main.lua',r'function\s+love\.mousereleased\s*\('),
 ('mousemoved','main.lua',r'function\s+love\.mousemoved\s*\('),
 ('keypressed','main.lua',r'function\s+love\.keypressed\s*\('),
 ('queue_L_cursor_press','engine/controller.lua',r'function\s+Controller:queue_L_cursor_press\s*\('),
 ('queue_R_cursor_press','engine/controller.lua',r'function\s+Controller:queue_R_cursor_press\s*\('),
 ('L_cursor_press','engine/controller.lua',r'function\s+Controller:L_cursor_press\s*\('),
 ('button_press_update','engine/controller.lua',r'function\s+Controller:button_press_update\s*\('),
 ('save_settings','game.lua',r'function\s+Game:save_settings\s*\('),
 ('ui_element_click','engine/ui.lua',r'function\s+UIElement:click\s*\('),
 ('controller_update','engine/controller.lua',r'function\s+Controller:update\s*\('),
 ('key_press_update','engine/controller.lua',r'function\s+Controller:key_press_update\s*\('),
)
CAP=40000 # Reserve9k for manifest and1k for bounded stdout under50k total.
def inspect(archive,output):
    output.mkdir(exist_ok=False)
    result=dict(schema=1,job='M23',scope='Read-only source input callback inspection; no source/policy execution',
      maximum_members=4,maximum_methods=12,output_cap_bytes=50000,source_excerpt_cap_bytes=CAP,
      members={},methods=[],qualification=False)
    sources={}
    with zipfile.ZipFile(archive)as z:
        entries=z.infolist();assert len(entries)<=20000,'Archive entry limit exceeded'
        for name in MEMBERS:
            matches=[e for e in entries if e.filename.replace('\\','/').lower()==name.lower()]
            if len(matches)!=1:
                result['members'][name]=dict(status='missing'if not matches else'ambiguous');continue
            entry=matches[0];assert entry.file_size<=4*1024*1024,'Source member exceeds4MiB read cap'
            raw=z.read(entry);sources[name]=raw
            result['members'][name]=dict(status='read',archive_member=entry.filename,bytes=len(raw),sha256=sha(raw))
    remaining=CAP
    for label,member,pattern in METHODS:
        meta,body=excerpt(sources.get(member,b''),pattern,1000000)
        # Exact full method boundaries/hash come from the reviewed byte lexer.
        # Preserve completeness unless the global50k bound forces truncation.
        complete_before_cap=not meta.get('truncated',False)
        shown=body[:remaining]
        if body:
            remaining-=len(shown)
            if shown:
                with(output/(label+'.lua')).open('xb')as out:out.write(shown)
                meta['excerpt_file']=label+'.lua'
        meta.update(name=label,source_member=member,declaration_pattern=pattern,
          truncated=not complete_before_cap or len(shown)!=len(body),shown_bytes=len(shown),
          excerpt_sha256=sha(shown),complete_method=meta.get('status')=='found'and complete_before_cap and len(shown)==len(body))
        result['methods'].append(meta)
    result['output_bytes']=CAP-remaining
    result['complete_methods']=sum(m['complete_method']for m in result['methods'])
    result['status']='complete'if all(m['complete_method']for m in result['methods'])else'incomplete_explicit'
    encoded=(json.dumps(result,separators=(',',':'))+'\n').encode('utf-8')
    assert len(encoded)<=9000,'Manifest exceeds reserved metadata cap'
    with(output/'inspection.json').open('xb')as out:out.write(encoded)
    return result
def main():
    folder=Path(__file__).resolve().parent;registration=json.loads((folder/'registration.json').read_text())
    spent=json.loads((folder/'spent.json').read_text())
    assert registration['job']==spent['job']=='M23'and registration['timeout_seconds']==30
    assert registration['metadata']['kind']=='startup_input_source_inspection_v1'
    assert spent['registration_sha256']==sha((folder/'registration.json').read_bytes())
    archive=Path(registration['metadata']['source_archive'])
    assert str(archive.resolve())in registration['external_files']
    assert registration['external_files'][str(archive.resolve())]==registration['metadata']['expected_source_sha256']
    started=time.perf_counter();result=inspect(archive,folder/'inspection')
    summary=json.dumps(dict(job='M23',elapsed_seconds=time.perf_counter()-started,source_execution=False,
      game_or_save_access=False,status=result['status'],complete_methods=result['complete_methods'],
      output_bytes=result['output_bytes'],inspection_file='inspection/inspection.json'))
    assert len(summary.encode())<1000;print(summary,flush=True)
if __name__=='__main__':main()
