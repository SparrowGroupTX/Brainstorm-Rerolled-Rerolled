"""Independent read-only audit of the already-spent M15 inspection."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[5]
FOLDER=ROOT/'tools/advisor_eval/runs/gold299_20260914/M15'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))

def main():
    r=read(FOLDER/'record.json');reg=read(FOLDER/'registration.json');spent=read(FOLDER/'spent.json')
    m=read(FOLDER/'inspection/inspection.json')
    assert r['status']=='complete' and r['exit_code']==0 and r['one_use_spent']
    assert r['timeout_seconds']==reg['timeout_seconds']==30 and r['elapsed_seconds']<30
    assert r['frozen_files_unchanged'] and r['external_files_unchanged']
    assert r['registration_sha256']==spent['registration_sha256']==sha(FOLDER/'registration.json')
    assert r['trace_sha256']==sha(FOLDER/'trace.log')
    for file,digest in reg['files'].items():assert sha(FOLDER/file)==digest,file
    assert set(m['members'])=={'card.lua','functions/state_events.lua','functions/common_events.lua'}
    methods={};excerpts={};truncated=[];missing=[]
    for item in m['methods']:
        if item['status']!='found':missing.append(item['name']);continue
        path=FOLDER/'inspection'/item['excerpt_file']
        assert sha(path)==item['excerpt_sha256']
        if not item['truncated']:assert sha(path)==item['full_method_sha256']
        else:truncated.append(item['excerpt_file'])
        methods[item['name']]={k:item[k] for k in ('source_member','start_line','end_line','full_method_sha256','excerpt_sha256','truncated')}
        excerpts[item['excerpt_file']]=sha(path)
    for group in m['neighborhoods']:
        assert group['shown_matches']==len(group['excerpts'])<=group['matches']
        for item in group['excerpts']:
            path=FOLDER/'inspection'/item['excerpt_file'];assert sha(path)==item['sha256']
            excerpts[item['excerpt_file']]=sha(path)
            if item['truncated']:truncated.append(item['excerpt_file'])
    actual=sum((FOLDER/'inspection'/name).stat().st_size for name in excerpts)
    assert actual==m['combined_output_bytes']<=m['combined_output_cap_bytes']==120000
    first=(FOLDER/'inspection/card__first_hand_1.lua').read_text()
    assert first.index('elseif context.first_hand_drawn')<first.index("self.ability.name == 'Certificate'")
    for exact in ("pseudoseed('cert_fr')","center = G.P_CENTERS.c_base}, G.hand",
                  "pseudoseed('certsl')","seal_type > 0.75","seal_type > 0.5",
                  "seal_type > 0.25","playing_card_joker_effects({true})"):
        assert exact in first,exact
    result={'schema':1,'job':'M15','status':'read_only_certificate_mechanics_verified',
        'record_sha256':sha(FOLDER/'record.json'),'registration_sha256':sha(FOLDER/'registration.json'),
        'trace_sha256':sha(FOLDER/'trace.log'),'inspection_sha256':sha(FOLDER/'inspection/inspection.json'),
        'worker_seconds':r['elapsed_seconds'],'one_use_spent':True,'frozen_files_and_excerpts_verified':True,
        'external_archive_runtime_unchanged':'Recorded by root cycle pre-dispatch/post-reap checks; this audit did not reread the executable.',
        'source_members':m['members'],'methods':methods,'excerpts':excerpts,'combined_excerpt_bytes':actual,
        'facts':[
            'Certificate responds to first_hand_drawn; it is not a setting_blind card generation callback.',
            'It queues an Event creating a c_base card using a front drawn from loaded G.P_CARDS with cert_fr, directly into G.hand.',
            'create_playing_card increments physical playing_card identity, inserts the card into G.playing_cards and emplaces in the requested area; this function contains no hand-size/capacity increment.',
            'A separate certsl pseudorandom value selects Red above0.75, Blue above0.5, Gold above0.25, Purple otherwise; exactly these four seal identities are in this branch.',
            'After sealing, the source refreshes blind debuff on the new card and sorts the hand.',
            'playing_card_joker_effects({true}) is invoked after scheduling the event, outside the queued creation function; its definition is not present in the inspected allowed members.',
            'The adjacent playing_card_added branch increments a non-Blueprint Hologram by the number of created-card markers when present and not getting_sliced.',
            'draw_from_deck_to_hand computes normal space as minimum of deck count and hand capacity minus current count, then queues draw_card events; active Serpent later draws use minimum(deck,3).',
            'Card:set_seal changes the seal and calls set_cost; the Certificate branch passes silent=true, so it does not acquire the ordinary visible seal-animation lock.'
        ],
        'missing':missing+['first_hand_drawn dispatch callsite','full loaded G.P_CARDS registry and c_base constructor template'],
        'truncated_excerpts':truncated,
        'limits':[
            'Only three preregistered ZIP members were read. No Lua callbacks were executed.',
            'Two broad Certificate neighborhoods were byte-truncated. The focused first-hand and seal branches and five found methods are complete.',
            'No first_hand_drawn dispatch callsite was found in state_events; this inspection alone does not prove whether that dispatch occurs before or after normal drawing.',
            'The four seal intervals are explicit; their exact probabilities and the52-front vanilla population require separately qualified random/front metadata, not just these source names.',
            'Purple discard Tarot outcomes, subsequent draws, full blind continuation and multi-Certificate/copier joint generation remain unqualified.',
            'Earlier C03 reported one nine-card initial hand with Certificate. That observation is development evidence, not a complete new projection or a rescued attempt.'
        ],'source_execution':False,'native_search':False,'player_file_access':False,'qualification':False}
    with (FOLDER/'audit.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
    print(json.dumps({'status':result['status'],'worker_seconds':r['elapsed_seconds'],
        'methods':len(methods),'missing':missing,'truncated_excerpts':truncated,'bytes':actual}))

if __name__=='__main__':main()
