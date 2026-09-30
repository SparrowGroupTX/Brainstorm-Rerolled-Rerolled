"""Prospective M15: three ZIP members, bounded Certificate/first-draw excerpts.

No Lua interpreter, native function, process launch, or player-file access.
The entry point requires a root-frozen matching one-use M15 spent receipt.
"""
from pathlib import Path
import json,re,time,zipfile
from source_lexer import excerpt,sha

MEMBERS=('card.lua','functions/state_events.lua','functions/common_events.lua')
CAP=120000
METHODS=(
    ('draw_from_deck_to_hand','functions/state_events.lua',r'G\.FUNCS\.draw_from_deck_to_hand\s*=\s*function\b',260),
    ('draw_from_play_to_hand','functions/state_events.lua',r'G\.FUNCS\.draw_from_play_to_hand\s*=\s*function\b',80),
    ('create_playing_card','functions/common_events.lua',r'function\s+create_playing_card\s*\(',100),
    ('draw_card','functions/common_events.lua',r'function\s+draw_card\s*\(',130),
    ('playing_card_joker_effects','functions/common_events.lua',r'function\s+playing_card_joker_effects\s*\(',100),
    ('set_seal','card.lua',r'function\s+Card:set_seal\s*\(',100),
)
# Match counts include source strings/comments. These are byte neighborhoods,
# not proof of executed callbacks; the reader must inspect their context.
NEIGHBORHOODS=(
    ('certificate','card.lua',rb'Certificate|j_certificate',8,12,86),
    ('first_hand','card.lua',rb'first_hand_drawn',4,18,32),
    ('first_hand','functions/state_events.lua',rb'first_hand_drawn|cards_drawn|playing_card_added',6,16,28),
    ('generation_callback','functions/common_events.lua',rb'playing_card_added|playing_cards_created',6,12,20),
    ('seal_pool','card.lua',rb'certsl|cert_seal|P_SEALS',6,8,16),
)

def inspect(archive,output):
    output.mkdir(exist_ok=False)
    manifest={'schema':1,'job':'M15','status':'complete','members':{},'methods':[],
        'neighborhoods':[],'qualification':False,'combined_output_cap_bytes':CAP,
        'source_execution':False,'native_search':False,'player_file_access':False,
        'scope':'Three exact ZIP members; Certificate generation and first-draw source text only.'}
    sources={}
    with zipfile.ZipFile(archive) as z:
        entries=z.infolist();assert len(entries)<=20000,'Archive entry cap exceeded'
        for member in MEMBERS:
            found=[e for e in entries if e.filename.replace('\\','/').lower()==member.lower()]
            if len(found)!=1:
                manifest['members'][member]={'status':'missing' if not found else 'ambiguous'};continue
            entry=found[0];assert entry.file_size<=4*1024*1024,'Member read cap exceeded'
            raw=z.read(entry);sources[member]=raw
            manifest['members'][member]={'status':'read','archive_member':entry.filename,
                'bytes':len(raw),'sha256':sha(raw)}
    total=0
    def save(filename,body):
        nonlocal total
        assert total+len(body)<=CAP,'Combined excerpt output cap exceeded'
        with (output/filename).open('xb') as f:f.write(body)
        total+=len(body)
    for label,member,pattern,line_limit in METHODS:
        metadata,body=excerpt(sources.get(member,b''),pattern,line_limit)
        metadata.update(name=label,source_member=member,declaration_pattern=pattern)
        if body:
            # Global budget remains explicit; retain full-method hash from the
            # lexer even when the local byte cap truncates its returned text.
            if len(body)>12000:
                body=body[:12000];metadata['truncated']=True
                metadata['excerpt_sha256']=sha(body);metadata['shown_lines']=len(body.splitlines())
            metadata['excerpt_file']=label+'.lua';metadata['byte_limit']=12000
            save(metadata['excerpt_file'],body)
        manifest['methods'].append(metadata)
    for label,member,pattern,limit,before,after in NEIGHBORHOODS:
        lines=sources.get(member,b'').splitlines(keepends=True)
        hits=[i for i,line in enumerate(lines) if re.search(pattern,line)]
        item={'name':label,'source_member':member,'pattern':pattern.decode('ascii'),
            'matches':len(hits),'shown_matches':0,'match_limit':limit,
            'lines_before':before,'lines_after':after,'truncated':len(hits)>limit,'excerpts':[]}
        for ordinal,index in enumerate(hits[:limit],1):
            low,high=max(0,index-before),min(len(lines),index+after+1)
            body=b''.join(lines[low:high]);complete_body_bytes=len(body)
            # Preserve a bounded prefix and exact original byte hash; never
            # silently claim the rest of a long neighborhood was inspected.
            body=body[:6000]
            if total+len(body)>CAP:
                item['truncated']=True;item['output_budget_exhausted']=True;break
            name=member.replace('/','_').replace('.lua','')+'__'+label+'_'+str(ordinal)+'.lua'
            save(name,body);item['shown_matches']+=1
            item['excerpts'].append({'match_line':index+1,'start_line':low+1,
                'requested_end_line':high,'shown_lines':len(body.splitlines()),
                'truncated':len(body)!=complete_body_bytes,'sha256':sha(body),'excerpt_file':name})
        manifest['neighborhoods'].append(item)
    manifest['combined_output_bytes']=total
    with (output/'inspection.json').open('x',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
    return manifest

def main():
    folder=Path(__file__).resolve().parent
    registration=json.loads((folder/'registration.json').read_text(encoding='utf-8'))
    spent=json.loads((folder/'spent.json').read_text(encoding='utf-8'))
    assert registration['job']==spent['job']=='M15' and registration['timeout_seconds']==30
    assert spent['registration_sha256']==sha((folder/'registration.json').read_bytes())
    archive=Path(registration['metadata']['source_archive'])
    assert str(archive.resolve()) in registration['external_files']
    started=time.perf_counter();result=inspect(archive,folder/'inspection')
    print(json.dumps({'job':'M15','status':result['status'],'elapsed_seconds':time.perf_counter()-started,
        'combined_output_bytes':result['combined_output_bytes'],'members':result['members'],
        'methods':result['methods'],'source_execution':False,'player_file_access':False}),flush=True)

if __name__=='__main__':main()
