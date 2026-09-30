"""Register a fresh finite evaluation authorized by the user's latest request."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil,sqlite3,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,digest,file_digest

def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
    with Path(p).open('x',encoding='utf-8') as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def pick(rows,n):return sorted(rows,key=lambda x:hashlib.sha256(('429:'+str(x['sequence'])).encode()).hexdigest())[:n]

for name in ('frozen','ledger','results'): (HERE/name).mkdir(exist_ok=False)
sources={}
old=read(EVAL/'development427/analysis/decisions.json')
new=read(EVAL/'development428/analysis/decisions.json')
flags=read(EVAL/'development427/suspects/report.json')['flags']
unused={v['anchors']['request']['sequence'] for v in flags if v['rule']=='unused_discards_at_clear'}
assert len(unused)==60
selected=[('old_unused',x)for x in old if x['sequence'] in unused]
short=[x for x in old if (x.get('action') or {}).get('kind')=='discard' and len(x['action']['indices'])<5]
full=[x for x in old if (x.get('action') or {}).get('kind')=='discard' and len(x['action']['indices'])==5]
selected += [('old_short_control',x)for x in pick(short,40)]
selected += [('old_full_control',x)for x in pick(full,20)]
current={443,488,621,731,3661,3839,4008}
selected += [('current_reported',x)for x in new if x['sequence'] in current]
assert len(selected)==127
paths={'old':EVAL/'development427/captures/001/events.sqlite3','current':EVAL/'development428/captures/001/events.sqlite3'}
db={k:sqlite3.connect('file:'+str(v)+'?mode=ro',uri=True) for k,v in paths.items()}
cases={}
for group,x in selected:
    cohort='current' if group=='current_reported' else 'old'
    raw=db[cohort].execute('SELECT data FROM events WHERE seq=?',(x['observation_sequence'],)).fetchone()[0]
    event=json.loads(raw);s=event['context']['snapshot'];ident=cohort+'-'+str(x['sequence'])
    assert s['phase']=='hand' and s['teacher_profile']=='perkeo_yorick_win_v1'
    history=old if cohort=='old' else new
    past=[y for y in history if y['sequence']<x['sequence'] and y['run']==x['run'] and
        (y.get('before') or {}).get('round')==s.get('round') and (y.get('action') or {}).get('kind')=='discard']
    cases[ident]={'id':ident,'group':group,'run':x['run'],'request_sequence':x['sequence'],
        'observation_sequence':x['observation_sequence'],'event_sha256':hashlib.sha256(raw.encode()).hexdigest(),
        'recorded_action':x['action'],'snapshot':s,'round_key':cohort+':'+str(x['run'])+':'+str(s.get('round')),
        'prefix_discards':len(past),'prefix_cards_discarded':sum(len(y['action']['indices']) for y in past),
        'prefix_count_matches':len(past)==s.get('discards_used',0)}
for c in db.values():c.close()
save(HERE/'cases.json',cases)

def visible(s):
    if (s.get('blind') or {}).get('key') not in ('bl_small','bl_big'):return False
    if s.get('drawpile_identity_redacted_for_concealment'):return False
    ids=set()
    for area in ('hand','deck'):
        for c in s.get(area,[]):
            if c.get('unknown') or c.get('identity_redacted') or not c.get('id') or c['id'] in ids:return False
            if area=='hand' and c.get('face_down'):return False
            ids.add(c['id'])
    return bool(s.get('deck')) and all(not c.get('face_down') and not c.get('identity_redacted') for c in s.get('jokers',[]))

eligible=[c for c in cases.values() if c['group'] in ('old_unused','current_reported') and visible(c['snapshot'])]
eligible.sort(key=lambda x:hashlib.sha256(('429-round:'+x['id']).encode()).hexdigest())
round_cases=[];seen=set()
for c in eligible:
    if c['round_key'] not in seen:round_cases.append(c);seen.add(c['round_key'])
    if len(round_cases)==12:break
jobs={};order={'decision':[],'continuation':[]}
for index,c in enumerate(cases.values()):
    roles=('baseline','candidate') if index%2==0 else ('candidate','baseline')
    for role in roles:
        key='D-'+c['id']+'-'+role
        jobs[key]={'mode':'decision','case':c['id'],'policy':role,'snapshot':c['snapshot']};order['decision'].append(key)
for index,c in enumerate(round_cases):
    for world,sort in ((1,'rank'),(2,'suit')):
        keybase='R-'+c['id']+'-'+str(world)
        world_seed=int(hashlib.sha256(keybase.encode()).hexdigest()[:8],16)
        population=[v['id'] for v in c['snapshot']['deck']]
        ordered=sorted(population,key=lambda v:hashlib.sha256((keybase+':'+v).encode()).digest())
        roles=('baseline','candidate') if (index+world)%2==0 else ('candidate','baseline')
        for role in roles:
            key=keybase+'-'+role
            jobs[key]={'mode':'continuation','case':c['id'],'policy':role,'snapshot':c['snapshot'],
                'world':world,'world_seed':world_seed,'world_order':ordered,'sorting':sort,'action_cap':8}
            order['continuation'].append(key)
save(HERE/'jobs.json',jobs)

policies={}
for role,revision in [('baseline',426),('candidate',428)]:
    base=EVAL/f'runs/repair{revision}_candidate1';freeze=read(base/'freeze.json')
    hashes=policy_hashes(base/'policy');assert hashes==freeze['candidate_policy_files']
    if role=='candidate':assert policy_hashes(ROOT)==hashes
    policies[role]={'digest':digest(hashes),'version':freeze['candidate_version'],
        'modules':{Path(k).stem:str((base/'policy'/k).resolve()) for k in hashes if k.startswith('Brainstorm/Advisor/') and k.endswith('.lua')},
        'all_files':{str((base/'policy'/k).resolve()):h for k,h in hashes.items()}}
runtime=(ROOT/'Brainstorm/Advisor/runtime.lua').read_text(encoding='utf-8')
wiring=runtime[runtime.index('A.snapshot,'):runtime.index('function A.defaults()')]
excluded=[];kept=[]
for line in wiring.splitlines():
    if line.startswith(('A.execution =','A.opening =','A.jokerless_opening =','A.retry_memory,','A.retry_generation,','A.acorn_public_hooks=')):
        excluded.append(line)
    else:kept.append(line)
wiring='\n'.join(kept)+"\nA.player_journal=module('player_journal')\n"
(HERE/'frozen/module_setup.lua').write_text(wiring,encoding='utf-8')
shutil.copy2(HERE/'driver.lua',HERE/'frozen/driver.lua')
shutil.copy2(EVAL/'captured_snapshot_pair.py',HERE/'frozen/literal.py')
runtime_dll=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
shutil.copy2(runtime_dll,HERE/'frozen/lua51.dll')

# Invented test input. No copied run is used by preflight.
def card(i,r,key='c_base'):
    names={'c_base':('Default Base','Base'),'m_mult':('Mult','Mult Card'),'m_glass':('Glass Card','Glass Card')}
    name,effect=names[key];n=11 if r==14 else min(r,10)
    return {'id':i,'rank':r,'suit':'Clubs','nominal':n,'base':{'id':r,'nominal':n},'key':key,'name':name,'enhancement':key,
        'ability':{'name':name,'set':'Default' if key=='c_base' else 'Enhanced','effect':effect,'bonus':0,
            'mult':4 if key=='m_mult' else 0,'x_mult':2 if key=='m_glass' else 1,'h_mult':0,'h_x_mult':0,
            'h_dollars':0,'p_dollars':0,'t_mult':0,'t_chips':0,**({'extra':4}if key=='m_glass' else {})}}
def joker(key,name):
    return {'key':key,'id':key,'blueprint_compat':True,'ability':{'name':name,'set':'Joker','effect':'','mult':0,'x_mult':1,
        'bonus':0,'t_mult':0,'t_chips':0,'h_mult':0,'h_x_mult':0,'h_dollars':0,'p_dollars':0,'h_size':0,'d_size':0}}
s={'phase':'hand','teacher_profile':'perkeo_yorick_win_v1','ante':5,'win_ante':8,'hand_size':8,'hand_limit':5,
    'hands_left':3,'hands_played':0,'discards_left':3,'discards_used':0,'chips':0,'dollars':30,'current_round':{},'modifiers':{},
    'probabilities':{'normal':1},'consumable_limit':2,'joker_limit':5,'blind':{'key':'bl_big','name':'Big Blind','chips':900},
    'hand':[card('made:h'+str(i),r,'m_glass' if i==0 else 'm_mult' if i==1 else 'c_base')for i,r in enumerate([13,13,2,4,6,8,10,12])],
    'deck':[card('made:d'+str(i),2+i%8)for i in range(24)],'consumeables':[],
    'hands':{'Pair':{'chips':30,'mult':5,'level':3,'l_chips':15,'l_mult':1,'played':9},'High Card':{'chips':5,'mult':1,'level':1,'l_chips':10,'l_mult':1,'played':0}},
    'jokers':[joker('j_yorick','Yorick'),joker('j_perkeo','Perkeo')]}
s['jokers'][0]['ability'].update(x_mult=4,yorick_discards=23,extra={'discards':23,'xmult':1})
s['playing_cards']=s['hand']+s['deck']
made=[]
for mode in ('decision','continuation'):
    for role in ('baseline','candidate'):
        made.append({'mode':mode,'case':'manufactured','policy':role,'snapshot':s,'world':1,'world_seed':429,
            'world_order':[c['id'] for c in s['deck']],'sorting':'rank','action_cap':8})
save(HERE/'manufactured.json',made)
files={str(p.resolve()):file_digest(p) for p in (HERE/'run.py',HERE/'driver.lua',HERE/'prepare.py',HERE/'jobs.json',HERE/'cases.json',HERE/'manufactured.json',Path(sys.executable))}
files.update({str(p.resolve()):file_digest(p) for p in (HERE/'frozen').iterdir() if p.is_file()})
for policy in policies.values():files.update(policy['all_files'])
source_files={str(p.resolve()):file_digest(p)for p in [*paths.values(),EVAL/'development427/analysis/decisions.json',EVAL/'development428/analysis/decisions.json',EVAL/'development427/suspects/report.json']}
manifest={'created_utc':datetime.now(timezone.utc).isoformat(),'kind':'evaluation429','qualification':False,
    'authorization':{'user_request':'So if you run the counterfactuals with the new discard policy, does it increase the number of discards used per round and cards discarded per discard? You can also run some simulations to try new runs in the background if you\'d like.',
        'interpretation':'Fresh bounded offline public counterfactual and modeled round evaluation; does not reopen historical budgets.'},
    'caps':{'serial_workers':1,'cpu_priority':'below_normal','gpu':False,'paid_compute_cost':0,'decision_seconds':660,'continuation_seconds':240,
        'total_seconds':900,'decision_worker_seconds':10,'continuation_worker_seconds':20,'continuation_actions':8,'retries':0,'replacements':0},
    'policies':policies,'python_version':sys.version,'files':files,'source_files':source_files,'job_order':order,
    'selection':{'decision_pairs':len(cases),'old_unused':'all60 settled unused-discard clears','short_controls':40,'full_controls':20,
        'control_rule':'lowest SHA256 of429:request_sequence','current_reported':sorted(current),'continuation_rounds':[c['id'] for c in round_cases],
        'continuation_rule':'first12 distinct visible simple-blind unused-clear rounds by SHA256(429-round:caseID); chosen before evaluation'},
    'runtime_wiring_excluded':excluded,'retry':'disabled_clean','worlds':'two hypothetical composition permutations; explicit rank/suit sorting; no actual future draws',
    'unsupported':'censored separately; never counted as failure or dropped','full_runs':0,'original_source_execution':False,'live_game_control':False,'save_access':False}
save(HERE/'manifest.json',manifest)
save(HERE/'PRESERVATION.json',{'installed':read(EVAL/'SESSION_RESET_426.json')['policy_digest'],'candidate':policies['candidate']['digest'],
    'prior_files':{str(p.resolve()):file_digest(p)for folder in (EVAL/'development428',EVAL/'development427') for p in folder.rglob('*') if p.is_file()},
    'installed_files':read(EVAL/'SESSION_RESET_426.json')['policy_files']})
print(json.dumps({'decision_pairs':len(cases),'continuation_rounds':len(round_cases),'continuation_branches':len(order['continuation']),'manifest':file_digest(HERE/'manifest.json')}))
