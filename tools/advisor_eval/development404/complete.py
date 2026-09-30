"""Record the completed exact-installed gate and preserve release navigation."""
from datetime import datetime,timezone
from pathlib import Path
import json,re,shutil,subprocess,sys

EVAL=Path(__file__).resolve().parents[1]
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance

def save(path,value):
    assert not path.exists(),path
    path.write_text(json.dumps(value,indent=2)+'\n')

def prepend(path,text):
    old=path.read_bytes();path.write_bytes(text.replace('\n','\r\n').encode()+old)

def main():
    dev=EVAL/'development404';candidate=EVAL/'runs/repair404_candidate2'
    final=EVAL/'runs/repair404_installed'
    frozen=json.loads((candidate/'freeze.json').read_text())
    gates=[json.loads((p/'validation/report.json').read_text()) for p in (candidate,final)]
    expected=frozen['candidate_policy_files'];counts=[]
    for directory,gate in zip((candidate,final),gates):
        assert gate['passed'] and gate['provenance_unchanged']
        assert gate['policy_files']==expected and gate['test_files']==frozen['test_files']==test_manifest()
        assert gate['validation_provenance']==frozen['validation_provenance']==provenance()
        lua=re.search(r'(\d+)/(\d+) fixtures passed',(directory/'validation/lua.log').read_text())
        assert lua and lua.group(1)==lua.group(2)
        python=sum(int(re.search(r'Ran (\d+) tests', (directory/'validation'/name).read_text()).group(1))
                   for name in ('python.log','python_1.log','python_2.log'))
        counts.append({'lua_fixtures':int(lua.group(1)),'python_tests':python})
    assert counts[0]==counts[1]=={'lua_fixtures':269,'python_tests':406}
    record=json.loads((final/'record.json').read_text());installed=Path(record['installed'])
    base=json.loads((EVAL/'SESSION_RESET_400.json').read_text())
    assert policy_hashes(ROOT)==policy_hashes(installed.parent)==policy_hashes(final/'policy')==policy_hashes(candidate/'policy')==expected
    assert policy_hashes(dev/'before')==base['policy_files']
    previous=json.loads((EVAL/'runs/copydeath400_candidate2/freeze.json').read_text())
    for rel,sha in previous['test_files'].items():assert file_digest(dev/'before'/rel)==sha
    old_audit=json.loads((EVAL/'development403/final_verification.json').read_text())
    for rel,sha in old_audit['artifact_hashes'].items():assert file_digest(ROOT/rel)==sha,rel
    backup=Path(record['installation']['backup'])
    deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
    deployed={r['path'].replace('\\','/'):r['after'].lower() for r in deployment['files']}
    assert len(deployed)==93
    for row in deployment['files']:
        rel=row['path'].replace('\\','/')
        assert file_digest(installed/rel)==row['after'].lower()==expected['Brainstorm/'+rel]
        assert row['before'].lower()==base['deployment_files'][rel]==file_digest(backup/rel)
    confirmation=dev/'normal_exit_confirmation.json'
    subprocess.run([sys.executable,str(dev/'verify_release.py'),'--installed','--output',str(dev/'installed_verification.json'),
        '--normal-exit-confirmation',str(confirmation)],cwd=ROOT,check=True)
    verify=json.loads((dev/'installed_verification.json').read_text())
    assert verify['installed_config_sha256']==record['config_sha256']
    for rel,sha in frozen['test_files'].items():
        target=candidate/'test_sources'/rel;target.parent.mkdir(parents=True,exist_ok=True)
        assert not target.exists();shutil.copy2(ROOT/rel,target);assert file_digest(target)==sha
    checkpoint={'version':'2.195.0-alpha','installed_at':record['installation']['installedAt'],
        'installed':str(installed),'backup':str(backup),'policy_digest':digest(expected),'policy_files':expected,
        'deployment_files':deployed,'config_sha256':record['config_sha256'],
        'native_files_preserved':record['native_files_preserved'],'runtime_file_count':109,'deployment_file_count':93,
        'candidate_validation':str(candidate/'validation/report.json'),'installed_validation':str(final/'validation/report.json'),
        'validation_counts':counts[0],'frozen_test_file_count':312,
        'latest_public_loaded_label':'2.194.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
        'latest_public_capture_last_sequence':24223,'latest_public_capture_complete_batch':True,
        'latest_public_manifest_sha256':verify['public_manifest_sha256'],'latest_public_starts':10,
        'latest_public_endings':{'win':5,'loss':4,'unsupported':1},
        'normal_exit_confirmation_sha256':file_digest(confirmation),
        'activation':'Unconfirmed; awaits next normal user game start; no2.195 outcomes',
        'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False}
    save(EVAL/'SESSION_RESET_404.json',checkpoint)
    summary='''# Installed checkpoint404 — 2.195.0-alpha

Installed after the user explicitly confirmed normal exit of the latest ten-run
session. Exact machine receipt: `SESSION_RESET_404.json`; final evidence:
`development404/final_verification.json`. Candidate history:
`CANDIDATE_CHECKPOINT_404.md`; behavior/review: `development404/REPORT.md` and
`REVIEW.md`; navigation: `NEXT_PRIORITIES_404.md`, `ARCHITECTURE_MAP_404.md`.

Digest `6a7281852e571cbf4b3ff9bedf742fc5bfbe80a8374192aac80cc408cd855cea`.
109 runtime dependencies,93 deployment files,312 frozen test files. Full
candidate and exact-installed gates each pass269 Lua fixtures and406 Python
tests with unchanged runtime/test/provenance hashes. The15-file combined
repair is installed; all93 replaced runtime paths have verified old backups at
`deployment-backups/advisor-20260926-133801`. Settings and all7 DLLs are unchanged.

Supported fixes: consistent copy-pack endpoints, conservative temporary-core
bridge, complete bounded Hook floors, Acorn vanilla edition metadata,
complete-collection win-first query, settled/new-draw visibility, diagnostic
copy/Death/fishing receipts and final action display. No blanket purchase,
discard-first rule, score-cap increase or globally optimal strategy is claimed.

The latest public cohort remains loaded-label2.194:5 wins,4 losses,1 nonterminal
unsupported/10 starts. No2.195 loaded activation, win benefit or established50%
rate exists. Activation awaits the user's next normal game start. No release,
review or implementation remains pending for this delivery; stop here.
All prior execution, preservation and closed-experiment boundaries remain.
'''
    path=EVAL/'SESSION_RESET_404.md';assert not path.exists();path.write_text(summary)
    header='''CURRENT INSTALLED CHECKPOINT404 — 2026-09-26
2.195.0-alpha installed after explicit normal-exit confirmation for the latest
ten-run session. Read tools/advisor_eval/SESSION_RESET_404.md/.json,
NEXT_PRIORITIES_404.md, ARCHITECTURE_MAP_404.md and development404/REPORT.md.
Digest6a7281852e571cbf4b3ff9bedf742fc5bfbe80a8374192aac80cc408cd855cea;
109 runtime dependencies/93 deployment/312 test files verified. Full candidate
and exact-installed gates each pass269 Lua fixtures and406 Python tests;
runtime/test/validation provenance unchanged. Settings,7 DLLs and all28 public
journals preserved; verified backup deployment-backups/advisor-20260926-133801.
Combined repair and bounded independent review are complete. Earlier candidate
pending-install/normal-exit-unconfirmed notes below are historical. No further
implementation, review or release remains for this slice; stop after delivery.
Activation awaits the next normal user start. Latest public outcomes remain
loaded-label2.194:5 wins/4 losses/1 nonterminal unsupported across10 starts.
No2.195 gameplay gain or population50% win rate is established. All existing
execution, preservation, budget, release and closed-experiment boundaries remain.

'''
    for name in ('ADVISOR_START_HERE.md','ADVISOR_RESUME_PROMPT.md','ADVISOR_HANDOFF.md'):prepend(ROOT/name,header)
    for name in ('CANDIDATE_CHECKPOINT_404.md','NEXT_PRIORITIES_404.md','ARCHITECTURE_MAP_404.md','FRESH_CHAT_HANDOFF_399.md'):
        prepend(EVAL/name,'Installed404 update: release completed; read SESSION_RESET_404.md/.json.\nCandidate2 and exact-installed gates pass269 Lua/406 Python; digest6a7281852e571cbf4b3ff9bedf742fc5bfbe80a8374192aac80cc408cd855cea.\nEarlier pending-release wording below is preserved history. Activation and\nloaded2.195 outcomes remain unconfirmed; no further slice is authorized here.\n\n')
    prepend(EVAL/'WIN_RATE_RESEARCH.md','Installed404 update (2026-09-26): the documented2.195 repairs are now installed\nafter latest-session normal-exit confirmation; exact-installed gate269 Lua/406\nPython passed. SESSION_RESET_404.json binds bytes. No2.195 loaded outcome or\ncausal win gain exists; preceding cohorts and all unresolved hypotheses remain.\n\n')
    prepend(dev/'REPORT.md','Release completed:2.195 installed after explicit latest-session normal exit.\nFull candidate and exact-installed gates each pass269 Lua/406 Python; settings\nand7 DLLs unchanged. See ../SESSION_RESET_404.json. The initial release wrapper\nstopped on uppercase/lowercase hash formatting after a successful install;\nindependent byte verification confirmed no config change, and only verification/\nfreezing resumed. Original wrapper/failure/log are retained; no reinstall occurred.\nNo2.195 activation or gameplay benefit is established.\n\n')
    status=subprocess.run(['git','status','--porcelain=v1','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True)
    (dev/'git_status_after.txt').write_text(status.stdout)
    paths=list(dev.glob('*.md'))+list(dev.glob('*.py'))+list(dev.glob('*.log'))+list(dev.glob('*verification.json'))+[
       EVAL/'SESSION_RESET_404.json',EVAL/'SESSION_RESET_404.md',EVAL/'CANDIDATE_CHECKPOINT_404.md',
       EVAL/'NEXT_PRIORITIES_404.md',EVAL/'ARCHITECTURE_MAP_404.md',EVAL/'WIN_RATE_RESEARCH.md',
       EVAL/'FRESH_CHAT_HANDOFF_399.md',ROOT/'ADVISOR_START_HERE.md',ROOT/'ADVISOR_RESUME_PROMPT.md',ROOT/'ADVISOR_HANDOFF.md',
       candidate/'freeze.json',candidate/'validation/report.json',final/'record.json',final/'validation/report.json',confirmation]
    result={'verified_utc':datetime.now(timezone.utc).isoformat(),'status':'installed_validated_delivery_complete',
       'policy_digest':digest(expected),'runtime_files':109,'deployment_files':93,'frozen_test_files':312,
       'candidate_and_installed_counts':counts,'config_sha256':record['config_sha256'],
       'native_files_preserved':record['native_files_preserved'],'normal_exit_confirmed':True,
       'public_segments_preserved':len(verify['public_files']),'audit403_artifacts_unchanged':len(old_audit['artifact_hashes']),
       'baseline_runtime_and_tests_preserved':True,'backup_before_and_after_hashes_verified':True,
       'original_failures_preserved':True,'new_experiments':False,'game_control':False,'save_or_profile_access':False,
       'activation':checkpoint['activation'],'artifact_hashes':{str(p.relative_to(ROOT)).replace('\\','/'):file_digest(p) for p in paths}}
    save(dev/'final_verification.json',result)
    print(json.dumps({k:result[k] for k in ('status','policy_digest','candidate_and_installed_counts','public_segments_preserved','audit403_artifacts_unchanged')}))

if __name__=='__main__':main()
