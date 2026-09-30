"""Read-only delivery verification; --seal creates the first documentation receipt."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,json,re,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
    with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
args=argparse.ArgumentParser();args.add_argument('--seal',action='store_true');a=args.parse_args()
P=read(H/'prework.json');B=P['installed'];F=P['freeze'];final=H/'FINAL_VERIFICATION.json'
for rel,h in P['navigation_before'].items():assert file_digest(H/'before'/rel)==h,rel
for rel in P['navigation_before']:assert file_digest(R/rel)==file_digest(H/'replacements'/Path(rel).name),rel
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
assert policy_hashes(R)==policy_hashes(Path(B['installed']).parent)==policy_hashes(E/'runs/repair451_candidate1/policy')==B['policy_files']==F['candidate_policy_files']
assert test_manifest()==P['test_files']==F['test_files']and provenance()==P['provenance']==F['validation_provenance']
assert file_digest(E/'INSTALLATION_POLICY.md')==P['installation_policy_sha256']
assert file_digest(Path(B['installed'])/'config.lua')==P['config_sha256']
for root in(R/'Brainstorm',Path(B['installed'])):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for name in('candidate1','installed'):
    gate=read(E/('runs/repair451_'+name)/'validation/report.json')
    assert all(gate[k]for k in('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
    assert gate['policy_files']==B['policy_files']and gate['test_files']==F['test_files']
documents=[R/r for r in P['navigation_before']]
documents+=sorted(E.glob('*452.md'));documents+=[E/'NEW_CHAT_PROMPT_452.txt']
bad=[];links=0
for path in documents:
    for raw in re.findall(r'\]\(([^)]+)\)',path.read_text(encoding='utf-8')):
        target=raw.strip('<>').split('#',1)[0]
        if not target or re.match(r'^https?://',target):continue
        resolved=(path.parent/target).resolve();links+=1
        if not resolved.exists():bad.append({'document':str(path),'target':target})
assert not bad,bad
mandatory=[E/'FRESH_CHAT_HANDOFF_452.md',R/'ADVISOR_RESUME_PROMPT.md',E/'SIMULATOR_FIDELITY_PLAN_452.md']
metrics={'old_navigation_bytes':sum((H/'before'/r).stat().st_size for r in P['navigation_before']),
 'new_navigation_bytes':sum((R/r).stat().st_size for r in P['navigation_before']),
 'initial_three_document_bytes':sum(p.stat().st_size for p in mandatory),
 'initial_three_document_words':sum(len(p.read_text(encoding='utf-8').split())for p in mandatory),
 'new_document_count':len(documents),'local_links_checked':links,
 'all_new_document_bytes':sum(p.stat().st_size for p in documents),
 'note':'Bytes/whitespace words, not tokenizer counts or usage-credit estimates.'}
if a.seal:
    assert not final.exists()and(H/'REVIEW.md').is_file()
    K={'revision':452,'kind':'documentation_only_clean_context','created_utc':datetime.now(timezone.utc).isoformat(),
     'installed_revision':451,'installed_version':B['version'],'installed_policy_digest':B['policy_digest'],
     'runtime_unchanged':True,'tests_unchanged':True,'provenance_unchanged':True,'installation_performed':False,
     'training_runs':0,'simulator_episodes':0,'source_executions':0,'captured_policy_executions':0,'game_control':False,
     'new_experiment_budget':None,'user_direction':'Simulator fidelity accepted; concrete numerical execution caps not supplied.',
     'current_entry_point':'tools/advisor_eval/FRESH_CHAT_HANDOFF_452.md','initial_reading':[p.relative_to(R).as_posix()for p in mandatory],
     'fresh_prompt':'tools/advisor_eval/NEW_CHAT_PROMPT_452.txt','prior_files_preserved':len(P['prior_files']),
     'archive_files':{r:P['navigation_before'][r]for r in P['navigation_before']},'metrics':metrics,
     'current_release_validation':{'lua_fixtures':330,'python_tests':494,'runtime_dependencies':110,'frozen_test_files':383},
     'activation':'2.226 not observed loaded; no fresh game/process claim during documentation.',
     'latest_capture':'tools/advisor_eval/development451/install/captures/001',
     'latest_public_outcomes':{'starts':8,'terminal_endings':7,'wins':5,'losses':2,'unended':1},
     'review':'One read-only assessment and one focused recheck; exhausted.'}
    save(E/'SESSION_RESET_452.json',K)
    paths=documents+[E/'SESSION_RESET_452.json']+[p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
    # Console output only: no still-open redirected log enters this receipt.
    save(final,{**K,'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
if final.exists():
    for rel,h in read(final)['artifact_hashes'].items():assert file_digest(R/rel)==h,rel
print(json.dumps({'verified':True,'sealed':final.exists(),'prior_files':len(P['prior_files']),
 'installed_unchanged':B['version'],'metrics':metrics}))
