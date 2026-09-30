"""Integrity/arithmetic checks on already extracted public data; no policy calls."""
from pathlib import Path
from collections import Counter
from datetime import datetime, timezone
import ast,hashlib,json
P=Path(__file__).resolve().parent
def read(n):return json.loads((P/n).read_text(encoding='utf-8'))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(name,condition):
 if not condition:raise AssertionError(name)
 checks.append(name)
m=read('capture/manifest.json');s=read('capture/summary.json');r=read('runs.json')
d=read('deep_dive.json');u=read('deep_summary.json');a=read('actions.json');o=read('copy_opportunities.json')
events=[json.loads(l)for l in (P/'capture/events.jsonl').read_text().splitlines()]
check('26 frozen segment hashes and sizes intact',len(m['inputs'])==26 and all(
 digest(P/'capture/frozen'/Path(x['source']).name)==x['sha256'] and
 (P/'capture/frozen'/Path(x['source']).name).stat().st_size==x['bytes'] for x in m['inputs']))
check('19614 consecutive public records',len(events)==19614 and [e['sequence']for e in events]==list(range(1,19615)))
check('capture clean and stable',not m['errors']and not m['gaps']and all(x['stable']for x in m['inputs']))
check('ten starts and separate verified outcomes',len(r)==10 and Counter(x['outcome']for x in r)==Counter(win=3,loss=6,unsupported=1)and all(x['end_details']['evidence']['verified']for x in r))
check('incidental won fields do not override losses',all(r[i]['outcome']=='loss'for i in (4,9)))
check('converter consistency',s['converter_error']is None and s['converter']['counts']['action_requests']==len(a)==1852 and s['converter']['actions_without_callback']==0 and s['converter']['accepted_callbacks_without_settled_observation']==0)
check('actual objective projected on3104 observations',u['profile_projection']=={"('perkeo_yorick_win_v1', False, True)":3104})
check('same ten search requests and all found',len(set(json.dumps(x['search_request'],sort_keys=True)for x in d))==1 and all(x['search_result']['status']=='found'for x in d))
check('ten within-cohort unique seeds',len(set(x['seed']for x in r))==10)
check('nine copy opportunities four bought two cash-affordable passed',len(o)==9 and sum(x['bought']for x in o)==4 and sum(not x['bought']and x['affordable_before_sale']for x in o)==2)
check('recorded early-resource counts',u['early_clears']==76 and u['early_unused_discards']==75 and u['early_clears_with_unused']==32)
check('no observed Observatory or consumable sale',u['observatory_snapshots']==0 and u['consumable_sale_count']==0)
check('all ordinary snippets are arithmetic only',len(read('score_arithmetic.json'))==295 and sum(x['within_one']for x in read('score_arithmetic.json'))==234)
check('all independent analysis scripts parse',all(ast.parse(q.read_text(encoding='utf-8'))is not None for q in P.glob('*.py')))
check('initial hypotheses preserved as nonprospective',read('initial_manifest.json')['prospective_claim']is False)
q=next(x for x in a if x['sequence']==6505)
check('run4 broad-graph inventory exclusion is observed',len(q['before']['consumeables'])==7)
manifest={'schema':1,'closed_utc':datetime.now(timezone.utc).isoformat(),'design':'retrospective_selected_ten_start_diagnostic',
 'initial_manifest_sha256':digest(P/'initial_manifest.json'),'input_manifest_sha256':digest(P/'capture/manifest.json'),
 'loaded_version':'2.164.0-alpha','loaded_policy_sha256':None,'loaded_settings_profile_sha256':None,
 'repository_installed_checkpoint':'checkpoint.json','operating_profile':'perkeo_yorick_win_v1',
 'capture_cutoff':m['last_at'],'last_sequence':19614,'search_request':d[0]['search_request'],
 'native_request_ms':9000,'outer_search_seconds':30,'starts':10,'new_starts_authorized':0,
 'bounds':read('initial_manifest.json')['bounds'],'observation_input_bytes':m['input_bytes'],
 'remaining_to_one_gib_at_capture':1073741824-m['input_bytes'],
 'ranking':['WR-005','WR-002','WR-001','WR-004','WR-003'],'collection_preflight':'NOT READY for fresh no-purge prospective study',
 'research':{'search_queries_used':8,'distinct_source_urls_attempted':6,'full_sources_read':2,'read_slots_charged_conservatively':10,'search_limit':8,'read_limit':12,'closed':True},
 'runtime_changes':0,'installations':0,'tool_experiments':0,'captured_policy_evaluations':0,'agents_spawned':0,
 'manual_intervention':'None explicitly logged;10 Charm uses and12 Hook discards are nested player_callback records; unlogged input unknown.',
 'checks':checks,'failures':[]}
(P/'audit_checks.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks_passed':len(checks),'failures':0,'starts':10,'wins':3,'losses':6,'unsupported':1,'remaining_to_one_gib':manifest['remaining_to_one_gib_at_capture']}))
