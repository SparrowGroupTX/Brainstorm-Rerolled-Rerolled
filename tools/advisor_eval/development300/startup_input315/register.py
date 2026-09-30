"""Root-only M23 read-only source inspection. --describe never reserves a job."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];RUNS=ROOT/'tools/advisor_eval/runs'
BASE=RUNS/'gold299_20260914';INSTALLED=RUNS/'copy315_installed'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def plan():
    record=read(INSTALLED/'record.json');final=RUNS/'copy315_final/final_verification.json'
    f=read(final);assert record['version']==f['version']=='2.115.0-alpha'
    assert record['policy']['policy_digest']==f['policy_digest']and f['installed_matches']and f['native_unchanged']
    assert read(HERE/'synthetic_fixture_report.json')['passed']
    files={name:HERE/name for name in ['inspect_source.py','source_lexer.py','spec.md','synthetic_fixture_report.json','test_inspector.py','register.py']}
    for name,expected in record['policy']['policy_files'].items():
        assert sha(INSTALLED/'policy'/name)==expected,name
        files['policy/'+name]=INSTALLED/'policy'/name
    files['installed_policy_record.json']=INSTALLED/'record.json';files['installed_final_verification.json']=final
    for job in ('M13','M16'):
        for name in ('registration.json','record.json','inspection/inspection.json'):
            files['prior_'+job+'/'+name]=BASE/job/name
    old=read(BASE/'M13/registration.json')
    assert sha(HERE/'source_lexer.py')==old['files']['source_lexer.py']
    archive=next(Path(p)for p in old['external_files']if Path(p).name.lower()=='balatro.exe')
    metadata=dict(kind='startup_input_source_inspection_v1',
      hypothesis='Original mouse/key queue dispatch and settings persistence may explain why explicit Start cancels or remains idle; inspect callbacks before making a causal claim.',
      source_archive=str(archive),expected_source_sha256=old['external_files'][str(archive)],
      policy_version=record['version'],policy_digest=record['policy']['policy_digest'],
      outer_cap_seconds=30,maximum_members=4,maximum_methods=12,combined_output_cap_bytes=50000,
      profile='none',native_search=False,source_execution=False,policy_execution=False,
      lua_runtime_loaded=False,game_process_access=False,player_file_access=False,
      runtime='Frozen Python standard-library ZIP/byte lexer only',
      source_member_provenance='M13 main.lua, engine/controller.lua and game.lua metadata; engine/ui.lua is explicit root-requested UIElement candidate.',
      limitations='Static source mechanics only; no live/version/cancellation observation. Missing/ambiguous/truncated methods remain incomplete.',
      prior_unregistered_canio_proposal='On hold, never reserved/run; different task and metadata, no lease/evidence relabel.',qualification=False)
    return files,metadata,[archive,Path(sys.executable)]
def main():
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--describe',action='store_true');mode.add_argument('--register',action='store_true');args=parser.parse_args()
    files,metadata,external=plan()
    if args.describe:print(json.dumps(dict(files=len(files),metadata=metadata,external=list(map(str,external))),indent=2));return
    assert sha(external[0])==metadata['expected_source_sha256'],'Original source archive changed'
    s=importlib.util.spec_from_file_location('cycle',ROOT/'tools/advisor_eval/development299/cycle.py')
    cycle=importlib.util.module_from_spec(s);s.loader.exec_module(cycle)
    print(cycle.register('M23',files,[sys.executable,'-B','-u','{job}/inspect_source.py'],metadata,external=external))
if __name__=='__main__':main()
