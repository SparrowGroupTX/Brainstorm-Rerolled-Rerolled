"""One-use, frozen clean source attempts for the explicitly authorized 271 push.

No save IO, executable launch, live control, hidden-state policy input or checkpoint restores.
The adapter remains experimental; selected development seeds are never a rate cohort.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import shutil
import sys

HERE=Path(__file__).resolve().parent
# Frozen runner copies live next to their separately frozen adapter. Resolve
# imports there so a later source/tool repair cannot rewrite an earlier audit.
if (HERE.parent/'adapter'/'benchmark.py').is_file():
    sys.path.insert(0,str(HERE.parent/'adapter'))

from benchmark import ORDINARY_START, digest, file_digest, policy_hashes
from engine_probe import applied_retry_context, profile_spec, retry_context_spec, selection_record, jokerless_recipe_record
from paired_policy_audit import ADAPTER_FILES, collect, freeze_product, write_json
from development_report import parse_trace, episode_record

AUDITORS=('jokerless_push.py','paired_policy_audit.py','development_report.py')

def now(): return datetime.now(timezone.utc)

def admission(authorization, directory, mechanical=False):
    authorization=Path(authorization).resolve()
    spec=json.loads(authorization.read_text(encoding='utf-8'))
    cap=spec['allowances']['source_adapter_agent']
    deadline=datetime.fromisoformat(spec['worker_deadline_utc'])
    if spec['kind']!='new_user_authorized_jokerless_push' or spec['retry_evaluation'] is not False:
        raise ValueError('Unknown authorization or unsupported retry experiment')
    parent=authorization.parent/('source_probes' if mechanical else 'source_attempts')
    count_key='source_mechanical_workers' if mechanical else 'complete_attempt_workers'
    timeout_key='per_mechanical_seconds' if mechanical else 'per_attempt_seconds'
    total_key='mechanical_seconds_total' if mechanical else 'attempt_seconds_total'
    parent.mkdir(exist_ok=True)
    registrations=sorted(parent.glob('*/registration.json'))
    if len(registrations)>=cap[count_key]:
        raise ValueError('All requested worker leases are already registered')
    previous=[]
    for path in registrations:
        record=json.loads(path.read_text(encoding='utf-8'));unsigned=dict(record);claimed=unsigned.pop('registration_digest',None)
        if digest(unsigned)!=claimed or record.get('timeout_seconds')!=cap[timeout_key]:
            raise ValueError('An existing immutable lease is inconsistent; no allowance is renewed')
        previous.append(record)
    spent=sum(record['timeout_seconds'] for record in previous)
    timeout=cap[timeout_key]
    if timeout>(15 if mechanical else 180) or spent+timeout>cap[total_key] or (deadline-now()).total_seconds()<timeout+5:
        raise ValueError('No complete worker lease fits the remaining cap/deadline')
    if directory.parent!=parent or directory.exists():
        raise ValueError('Attempt needs a fresh direct child of the authorized worker directory')
    return spec,timeout,registrations

# These modules participate in hand observations, scoring or action selection.
# Version stamps, UI, search wrappers, installer changes and adapter repairs alone
# cannot admit a repeated complete attempt under this protocol.
HAND_POLICY_NAMES=frozenset(('search','decision','snapshot','scoring','draws','sampled_outcomes',
    'blind_finishing','two_hand_finish','resource_finish','multi_discard','growth','finish_rewards','hand_ordering',
    'ordering','boss_rescue','mixed_rescue','concealed_belief','score_cache','policy_weights','consumables','blind_prep'))

def hand_policy_changes(before,after):
    return {key:{'before':before.get(key),'after':after.get(key)} for key in sorted(set(before)|set(after))
        if key.startswith('Brainstorm/Advisor/') and Path(key).stem in HAND_POLICY_NAMES and before.get(key)!=after.get(key)}

def checked_dependency_artifacts(prior,previous):
    prior=Path(prior).resolve()
    old=json.loads((prior/'record.json').read_text(encoding='utf-8'))
    raw=json.loads((prior/'raw_record.json').read_text(encoding='utf-8'))
    trace=prior/'attempt.log'
    if (old.get('registration_digest')!=previous['registration_digest'] or
            old.get('provenance_verified') is not True or old.get('audit_errors') or
            old.get('outcome') not in ('loss','unsupported','timeout') or
            old.get('trace_digest')!=file_digest(trace) or raw.get('trace_digest')!=file_digest(trace) or
            old.get('command')!=previous['command'] or raw.get('command')!=previous['command']):
        raise ValueError('Dependent comparison requires an unchanged audited prior failure and raw trace')
    actual=episode_record(trace,previous['challenge'],previous['seed'],old['exit_code'],old['elapsed_seconds'],old['command'])
    if any(actual.get(k)!=old.get(k) for k in ('outcome','reason','terminal','provenance','trace_digest')):
        raise ValueError('Prior failure disagrees with its complete trace reaudit')
    return old,{'record_digest':file_digest(prior/'record.json'),'raw_record_digest':file_digest(prior/'raw_record.json'),
        'trace_digest':file_digest(trace)}

def dependent_comparison(prior,product,seed,profile,recipe,evidence):
    prior=Path(prior).resolve();previous=verify(prior)
    if (previous.get('seed')!=seed or previous.get('challenge')!='c_jokerless_1' or
            previous.get('full_episode_requested') is not True or previous.get('profile_spec')!=profile or
            previous.get('retry_context_spec')!=retry_context_spec() or previous.get('jokerless_opening')!=recipe):
        raise ValueError('Dependent complete comparison must preserve seed, challenge, profile, recipe and clean retry context')
    changed=hand_policy_changes(previous['policy_files'],product['policy_files'])
    if not changed:
        raise ValueError('A changed hand-policy module is required; version, UI or adapter changes alone are insufficient')
    if not evidence or not Path(evidence).is_file() or not Path(evidence).stat().st_size:
        raise ValueError('A concrete detached hand-policy repair evidence artifact is required')
    old,artifacts=checked_dependency_artifacts(prior,previous)
    return {'schema':1,'kind':'dependent_current_hand_policy_comparison','qualification':False,
        'path':str(prior),'registration_digest':previous['registration_digest'],**artifacts,
        'prior_policy_digest':previous['policy_digest'],'prior_adapter_digest':previous['adapter_digest'],
        'prior_outcome':old['outcome'],'new_policy_digest':product['policy_digest'],'changed_hand_modules':changed,
        'repair_evidence_digest':file_digest(evidence),'repair_evidence_source':str(Path(evidence).resolve()),
        'execution':'fresh_original_initialization_no_replay_or_restore','independent_rate_sample':False,
        'budget':'new_single_use_180_second_lease_inside_existing_shared_count_and_deadline'}

def freeze(args):
    directory=args.output.resolve();authorization=args.authorization.resolve()
    mechanical=bool(getattr(args,'first_decision_only',False))
    _,timeout,earlier=admission(authorization,directory,mechanical=mechanical)
    if mechanical and not args.opening_recipe:
        raise ValueError('This mechanical lease only validates declared opening initialization')
    if args.seed and not args.selection_evidence:
        raise ValueError('A selected development seed needs its prospective selection-evidence reference')
    directory.mkdir()
    product=freeze_product(args.policy_root.resolve(),directory/'policy')
    adapter=directory/'adapter';adapter.mkdir()
    files={name:file_digest(HERE/name) for name in ADAPTER_FILES}
    for name in files: shutil.copyfile(HERE/name,adapter/name)
    auditors=directory/'auditors';auditors.mkdir()
    audit_files={name:file_digest(HERE/name) for name in AUDITORS}
    for name in audit_files: shutil.copyfile(HERE/name,auditors/name)
    seed=args.seed or ''.join(secrets.choice('123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(8))
    if not seed.isalnum() or len(seed)>32: raise ValueError('Invalid development seed')
    def earlier_seed(path):
        record=json.loads(path.read_text(encoding='utf-8'))
        if record.get('seed') is not None:return record['seed']
        command=record.get('command',[])
        return command[command.index('--seed')+1] if '--seed' in command else None
    repeated=[p for p in earlier if earlier_seed(p)==seed]
    predecessor=None
    dependent=None
    if repeated and getattr(args,'dependent_attempt',None):
        prior=args.dependent_attempt.resolve()
        if mechanical or prior/'registration.json' not in repeated or getattr(args,'prior_failed_probe',None):
            raise ValueError('Dependent complete comparison needs an actual prior complete attempt from this shared directory')
        current_recipe=jokerless_recipe_record(args.opening_recipe,seed)
        dependent=dependent_comparison(prior,product,seed,profile_spec(args.unlock_profile),current_recipe,args.repair_evidence)
        shutil.copyfile(args.repair_evidence,directory/'repair_evidence.bin')
        if file_digest(directory/'repair_evidence.bin')!=dependent['repair_evidence_digest']:
            raise ValueError('Repair evidence changed during freeze')
    elif repeated:
        prior=getattr(args,'prior_failed_probe',None)
        if not mechanical or not prior or len(repeated)!=1 or prior.resolve()/('registration.json')!=repeated[0]:
            raise ValueError('This seed already has a registered source attempt; dependent replay needs a separate protocol')
        previous=verify(prior)
        old=json.loads((prior/'record.json').read_text(encoding='utf-8'))
        if (old.get('outcome')!='error' or old.get('exit_code')!=2 or old.get('startup') or old.get('actions') or
                old.get('terminal') or old.get('provenance') or file_digest(prior/'attempt.log')!=old.get('trace_digest')):
            raise ValueError('Only an explicitly recorded pre-initialization argument error permits this mechanical dependency')
        predecessor={'registration_digest':previous['registration_digest'],'record_digest':file_digest(prior/'record.json'),
            'path':str(prior.resolve()),'relationship':'changed_adapter_after_argument_parse_error_no_source_actions'}
    elif getattr(args,'dependent_attempt',None) or getattr(args,'repair_evidence',None):
        raise ValueError('Dependent comparison does not identify a repeated registered request')
    elif getattr(args,'prior_failed_probe',None):
        raise ValueError('Mechanical predecessor does not identify the repeated request')
    install=args.install.resolve()
    command=[sys.executable,'-u',str(adapter/'engine_probe.py'),'--episode','--install',str(install),
        '--policy-root',str(directory/'policy'),'--challenge','c_jokerless_1','--seed',seed,
        '--unlock-profile',args.unlock_profile,'--debug-decisions']
    selection=None
    if args.seed:
        source=Path(args.selection_evidence).resolve()
        source_hash=file_digest(source)
        shutil.copyfile(source,directory/'selection_source.json')
        if file_digest(directory/'selection_source.json')!=source_hash:raise ValueError('Selection evidence changed during freeze')
        selection_spec={'schema':1,'kind':'declared_selected_development_seed','seed':seed,'qualification':False,
            'source_evidence_digest':source_hash,'source_evidence_path':str(source),'hypothesis':args.hypothesis}
        if dependent:selection_spec['dependent_current_policy_comparison']=dependent
        write_json(directory/'selection_evidence.json',selection_spec)
        selection=selection_record(directory/'selection_evidence.json',seed)
        command+=['--seed-selection-evidence',str(directory/'selection_evidence.json')]
    recipe=None
    if args.opening_recipe:
        if not selection:raise ValueError('An opening recipe requires a disclosed selected seed')
        shutil.copyfile(args.opening_recipe,directory/'opening_recipe.json')
        recipe=jokerless_recipe_record(directory/'opening_recipe.json',seed)
        command+=['--jokerless-opening-recipe',str(directory/'opening_recipe.json')]
    if mechanical:command+=['--stop-at-decision','blind']
    registration={'schema':1,'kind':'single_clean_development_attempt','qualification':False,
        'authorization':str(authorization),'authorization_digest':file_digest(authorization),
        'created_utc':now().isoformat(),'deadline_utc':json.loads(authorization.read_text(encoding='utf-8'))['worker_deadline_utc'],
        'lease_index':len(earlier)+1,'timeout_seconds':timeout,'challenge':'c_jokerless_1','seed':seed,
        'seed_origin':'prospective_cryptographic_unseen_request' if args.seed is None else 'declared_selected_development_seed',
        'selection_evidence':args.selection_evidence,'hypothesis':args.hypothesis,
        'adapter_files':files,'adapter_digest':digest(files),'auditor_files':audit_files,
        'rules_digest':file_digest(install/'Balatro.exe'),'runtime_digest':file_digest(install/'lua51.dll'),
        **product,'profile_spec':profile_spec(args.unlock_profile),
        'profile_spec_digest':digest(profile_spec(args.unlock_profile)),
        'retry_context_spec':retry_context_spec(),'retry_context_spec_digest':digest(retry_context_spec()),
        'start_distribution':({'kind':'ordinary','seed_selection':'declared_development_selection',
            'selection_evidence_digest':selection['evidence_digest']} if selection else dict(ORDINARY_START)),
        'command':command,'full_episode_requested':not mechanical,
        'lease_kind':'mechanical_opening_initialization' if mechanical else 'complete_attempt',
        'adapter_action_cap':500,'game_control':'none','save_access':'none'}
    if selection:registration['seed_selection']=selection
    if recipe:
        registration.update(kind='autonomous_declared_opening_development_attempt',jokerless_opening=recipe,
            start_distribution={'kind':'jokerless_coupon_blue_v1','seed_selection':'declared_development_selection',
                'selection_evidence_digest':selection['evidence_digest'],'recipe_digest':recipe['recipe_digest']})
    if dependent:
        registration.update(dependent_current_policy_comparison=dependent,seed_origin='dependent_selected_development_seed',
            kind='dependent_current_policy_complete_attempt')
    if predecessor:registration['mechanical_predecessor']=predecessor
    if mechanical:
        registration.update(kind='original_source_mechanical_probe',source_worker_index=len(earlier)+1,
            scenario='declared_opening_initialization',expected_decisions_executed=0)
    registration['registration_digest']=digest(registration)
    write_json(directory/'registration.json',registration)
    verify(directory)
    return registration

def verify(directory):
    directory=Path(directory)
    r=json.loads((directory/'registration.json').read_text(encoding='utf-8'))
    unsigned=dict(r);claimed=unsigned.pop('registration_digest')
    if digest(unsigned)!=claimed: raise ValueError('Immutable registration changed')
    if policy_hashes(directory/'policy')!=r['policy_files']: raise ValueError('Frozen product changed')
    for folder,field in [('adapter','adapter_files'),('auditors','auditor_files')]:
        if any(file_digest(directory/folder/name)!=value for name,value in r[field].items()):
            raise ValueError('Frozen '+folder+' changed')
    if file_digest(r['authorization'])!=r['authorization_digest']: raise ValueError('Authorization changed')
    if r.get('mechanical_predecessor'):
        predecessor=r['mechanical_predecessor'];prior=Path(predecessor['path'])
        if (prior.resolve().parent!=directory.resolve().parent or
                file_digest(prior/'record.json')!=predecessor['record_digest'] or
                verify(prior)['registration_digest']!=predecessor['registration_digest']):
            raise ValueError('Frozen mechanical predecessor changed')
    if r.get('dependent_current_policy_comparison'):
        dependency=r['dependent_current_policy_comparison'];prior=Path(dependency['path'])
        previous=verify(prior)
        if (prior.resolve().parent!=directory.resolve().parent or previous['lease_index']>=r['lease_index'] or
                previous['registration_digest']!=dependency['registration_digest'] or
                file_digest(directory/'repair_evidence.bin')!=dependency['repair_evidence_digest'] or
                r['policy_digest']!=dependency['new_policy_digest'] or
                hand_policy_changes(previous['policy_files'],r['policy_files'])!=dependency['changed_hand_modules'] or
                r['profile_spec']!=previous['profile_spec'] or r.get('jokerless_opening')!=previous.get('jokerless_opening')):
            raise ValueError('Dependent current-policy comparison changed its frozen inputs')
        _,artifacts=checked_dependency_artifacts(prior,previous)
        if any(artifacts[k]!=dependency[k] for k in artifacts):
            raise ValueError('Dependent comparison prior evidence changed')
    if r.get('seed_selection'):
        selection=selection_record(directory/'selection_evidence.json',r['seed'])
        if selection!=r['seed_selection'] or file_digest(directory/'selection_source.json')!=selection['spec']['source_evidence_digest']:
            raise ValueError('Frozen selected-seed evidence changed')
    if r.get('jokerless_opening') and jokerless_recipe_record(directory/'opening_recipe.json',r['seed'])!=r['jokerless_opening']:
        raise ValueError('Frozen opening recipe changed')
    install=Path(r['command'][r['command'].index('--install')+1])
    for file,field in [('Balatro.exe','rules_digest'),('lua51.dll','runtime_digest')]:
        if file_digest(install/file)!=r[field]: raise ValueError('Original source/runtime changed')
    return r

def execute(directory):
    directory=Path(directory).resolve();r=verify(directory)
    if (datetime.fromisoformat(r['deadline_utc'])-now()).total_seconds()<r['timeout_seconds']+5:
        raise ValueError('Registered worker no longer fits its outer deadline; lease stays spent')
    with (directory/'execution.json').open('x',encoding='utf-8') as f:
        json.dump({'started_utc':now().isoformat(),'registration_digest':r['registration_digest'],
                   'one_use':True,'timeout_seconds':r['timeout_seconds']},f)
    record=collect(r['command'],directory/'attempt.log',r,r['timeout_seconds'])
    write_json(directory/'raw_record.json',record)
    errors=[]
    try:
        verify(directory)
        rows,parse_errors=parse_trace(directory/'attempt.log')
        provenance=record['provenance']
        keys=('challenge','seed','policy_files','policy_digest','rules_digest','runtime_digest',
            'adapter_digest','start_distribution','profile_spec','profile_spec_digest',
            'retry_context_spec','retry_context_spec_digest')
        if any(provenance.get(k)!=r[k] for k in keys): raise ValueError('Trace differs from frozen registration')
        if provenance.get('seed_selection')!=r.get('seed_selection'):raise ValueError('Selected-seed provenance changed')
        if provenance.get('jokerless_opening')!=r.get('jokerless_opening'):raise ValueError('Opening recipe provenance changed')
        if sum(row.get('type')=='engine_probe_provenance' for row in rows)!=1: raise ValueError('Nonunique provenance')
        if provenance.get('counterfactual') or provenance.get('followed_advice') is False or provenance.get('opening_policy_loaded') is not bool(r.get('jokerless_opening')):
            raise ValueError('Source action/activation differs from declared autonomous policy')
        receipts=[x for x in rows if x.get('type')=='engine_jokerless_opening_initialized']
        if r.get('jokerless_opening'):
            if (len(receipts)!=1 or receipts[0].get('recipe_digest')!=r['jokerless_opening']['recipe_digest'] or
                    receipts[0].get('policy_module_loaded') is not True or receipts[0].get('source_catalog_prediction_matched') is not True or
                    receipts[0].get('policy_module_digest')!=r['policy_files'].get('Brainstorm/Core/jokerless_opening.lua')):
                raise ValueError('Missing or inconsistent applied opening receipt')
            if rows.index(receipts[0])>=next((i for i,x in enumerate(rows) if x.get('type')=='engine_episode_decision_started'),len(rows)):
                raise ValueError('Opening activated after its first decision')
        elif receipts:raise ValueError('Undeclared opening receipt')
        record['retry_context']=applied_retry_context(rows,provenance,r['retry_context_spec'])
        profile=record['unlock_profile']
        if not profile or profile.get('declared_scope_verified') is not True or profile.get('profile_spec')!=r['profile_spec']:
            raise ValueError('Applied source unlock profile missing or inconsistent')
    except (ValueError,KeyError,TypeError) as error: errors.append(str(error))
    if errors and record['outcome'] in ('win','loss','censored'):
        record.update(observed_outcome=record['outcome'],observed_reason=record['reason'],
            outcome='error',reason='frozen_provenance_audit_failed')
    record.update(registration_digest=r['registration_digest'],audit_errors=errors,
        provenance_verified=not errors,qualification=False,selected_development=True)
    write_json(directory/'record.json',record)
    return record

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--authorization',type=Path);p.add_argument('--output',type=Path)
    p.add_argument('--policy-root',type=Path);p.add_argument('--hypothesis');p.add_argument('--seed')
    p.add_argument('--selection-evidence');p.add_argument('--execute',type=Path)
    p.add_argument('--opening-recipe',type=Path)
    p.add_argument('--prior-failed-probe',type=Path)
    p.add_argument('--dependent-attempt',type=Path,help='Explicit prior failure for a changed hand-policy experiment; consumes a new shared lease')
    p.add_argument('--repair-evidence',type=Path,help='Concrete detached behavioral repair evidence for --dependent-attempt')
    p.add_argument('--first-decision-only',action='store_true',
        help='Use one15-second mechanical lease and stop before the first chosen blind action')
    p.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    p.add_argument('--unlock-profile',default='all_unlocked_discovered_v1')
    args=p.parse_args()
    if args.execute:
        r=execute(args.execute)
        print(json.dumps({k:r[k] for k in ('outcome','reason','elapsed_seconds','audit_errors','trace')}))
    else:
        if not all((args.authorization,args.output,args.policy_root,args.hypothesis)):p.error('Registration fields missing')
        r=freeze(args);print(json.dumps({k:r[k] for k in ('registration_digest','seed','policy_digest','adapter_digest','timeout_seconds')}))

if __name__=='__main__':main()
