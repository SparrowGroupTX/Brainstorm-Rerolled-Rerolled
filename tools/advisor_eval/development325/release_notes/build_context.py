"""Build CLOSED release325 note inputs; no finalization or runtime mutation."""
from copy import deepcopy
from datetime import datetime,timezone
import hashlib
import importlib.util
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))


def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}


def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')


def main():
    previous_path=ROOT/'tools/advisor_eval/development324/release_notes/context.json'
    previous=read(previous_path)
    assert previous['status']=='CLOSED' and previous['counts_scope']=='historical_closed_cycle'
    assert not any(previous['release_counts'].values()) and previous['remaining_authority_seconds']==0
    for item in previous['evidence'].values():assert sha(ROOT/item['path'])==item['sha256']
    limits=deepcopy(read(ROOT/previous['evidence']['limits']['path']))
    limits['kind']='release325_closed_historical_limits'
    limits['prior_evidence']['release324_context']=ref(previous_path)
    limits['prior_evidence']['release324_final']=ref(ROOT/'tools/advisor_eval/runs/timing324_final/final_verification.json')
    limits['prior_evidence']['release324_reset']=ref(ROOT/'tools/advisor_eval/SESSION_RESET_324.json')
    limits['prior_release_validation_324']=limits.pop('release_validation')
    limits['prior_public_observations_324']=limits.pop('public_observations')
    limits['prior_public_observations_324']['reused_only_no_new_external_read_325']=True
    limits['release_scope']='Routine manufactured/regression validation and read-only repository review only. Release 325 adds zero source, captured, search or complete experiments and reads no new external player log, save/profile or executable.'
    limits['limits']='Historical C01 policy300 alone owns one selected synthetic win; later releases inherit none. There is no release 325 terminal result, numerical player win rate, unseen validation, verified Jokerless win, actual Completionist++ result or stronger-than-human result. Prior public observations remain separately scoped.'
    limits['release_activation']='Unknown until the user restarts normally; no release 325 live activation or loaded hashes attested.'
    limits['release_validation']={'scope':'Final combined candidate and exact-installed results belong to generated release records; no prediction in these inputs.'}
    limits['component']=ref(ROOT/'tools/advisor_eval/AUTO_RESUME_325.md')
    limits['product_resume_search_scope']='After an explicitly stopped native request has drained, user-clicked Resume authorizes a distinct new product search of at most 30 seconds within the same session/cursor/recipe. Old allocation remains spent. This is not a cumulative old deadline, renewed historical lease or authority for tool experiments.'
    limits['continuation_scope']='Stop/Resume is in-memory only. Session/run/action counters and hard clock anchors remain. Verified manual checkpoint continuation logs interruption and retains caps; restored won flags are not fresh terminal evidence.'
    limits['additional_external_reads_325']=0
    dump(HERE/'limits.json',limits)
    context=deepcopy(previous)
    context.update(release=325,created_at_utc=datetime.now(timezone.utc).isoformat())
    context['summary']='Release 325 adds non-stopping ordinary input, explicit Stop/Resume within the same in-memory auto-run session, and verified manual checkpoint continuation. A cancelled native search drains once; later user-clicked Resume authorizes a distinct new product search of at most 30 seconds while preserving session/cursor/recipe. No source, captured, search or complete-attempt experiment or new external log read occurred. Final validation and installation facts belong to generated records. The original gold299 cycle remains CLOSED; counts below are historical.'
    context['summary']+=' The first full candidate validation is preserved as failed (175/177 Lua fixtures and 341 Python passes): two legacy fixtures asserted the old input-stop behavior. A replacement validation must remain separate; these inputs do not claim a passing full candidate.'
    context['outcome_summary']='Historical complete-attempt outcomes remain one selected synthetic win (C01, frozen policy300), three losses (C03/C05/C08) and four timeouts (C02/C04/C06/C07), with zero errors, unsupported or separately labeled censored results. C01 won Red Gold final Cerulean Bell 705600/400000 in 172.14000000001397 seconds, with 225 actions, 28 exact plays and 13 preserved ordinary score-cap overruns. C07 retained all 163 shared C06 inputs/actions; C08 lost Pillar 592/600 with all 22 C05 inputs/actions unchanged. C09 was never registered, reserved or run. Policies 321 through 325 have no complete-attempt result. Prior passive logs remain separate: the loaded-321 review recorded a loss and ongoing prefix; the release-324 loaded-323 tail recorded two losses, including Amber Acorn 98808/400000 despite an incidental won flag. Its out-of-tail aggregate win remains unaudited. Release 325 adds no terminal observation.'
    context['limits_summary']='The original attempts are selected dependent synthetic all_unlocked_discovered_v1 development data, not player odds, representative cohorts, untouched holdouts, achievement completion or general adapter qualification. No complete Jokerless win, 50%/75% per-challenge target or human superiority is demonstrated. Prior logs declare loaded 2.123 without attesting module hashes; no new external log was read for 325. Activation waits for the user normal restart. Timing 324 still needs a fresh bounded measurement review to isolate the reported freezes; mixed action intervals and payload sizes do not establish CPU usage, causality or speedup. Invalid, truncated, unflushed and incomplete evidence must not be imputed. Resume never renews persistent retry counts or historical experiment authority.'
    context['budget_summary']='The original cycle expired on 2026-09-14 at 22:40 UTC and is CLOSED. Its 60 slots/5400 seconds of authority covered 38 spent jobs, 2340 seconds of registered caps and exactly 1012.71499999973457357 recorded worker seconds (closure float 1012.7149999997346). All 22 unused slots, including C09 and 3060 seconds, are closed. Historical job counts remain 18 source components, 6 captured-pair jobs/18 policy evaluations, 6 searches and 8 complete attempts. Every release-325 count is zero. Fresh tool experiments require concrete new authorization and frozen one-use provenance; user product Resume is a separate explicit control, not such authority.'
    context['evidence']['limits']=ref(HERE/'limits.json')
    assert context['counts']==previous['counts'] and context['complete_attempt_outcomes']==previous['complete_attempt_outcomes']
    dump(HERE/'context.json',context)
    spec=importlib.util.spec_from_file_location('release325_context_validation',ROOT/'tools/advisor_eval/finalize_runtime_checkpoint.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    validated=module.experiment_context(HERE/'context.json');session,budget=module.experiment_json(validated)
    assert session['new_experiments']==0 and session['complete_win'] is False and session['historical_verified_complete_win'] is True
    assert session['historical_counts']==previous['counts']
    assert all(budget[k]==0 for k in('new_source_components','captured_pair_jobs','captured_policy_evaluations','searches','complete_attempts'))
    dump(HERE/'validation.json',{'schema':1,'kind':'read_only_context_reference_validation','status':'passed',
      'context':ref(HERE/'context.json'),'historical_counts':context['counts'],'release_counts':context['release_counts'],
      'outcomes':context['complete_attempt_outcomes'],'new_experiments':0,'new_release_complete_win':False,
      'finalizer_main_executed':False,'runtime_tests_current_navigation_changed':False,'additional_external_reads':0})
    print(json.dumps({'context':ref(HERE/'context.json'),'validation':ref(HERE/'validation.json')}))


if __name__=='__main__':main()
