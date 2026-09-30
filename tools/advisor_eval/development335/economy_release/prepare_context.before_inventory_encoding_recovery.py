"""Root-only: bind passed cash338 candidate and preserve closed 337 authority.
Preparation only creates context/navigation; final installed counts belong to the
root binder/finalizer. No installation, source work, saves or game control.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json
HERE=Path(__file__).resolve().parent
DEV=HERE.parent
EVAL=DEV.parent
ROOT=EVAL.parents[1]
COMPONENT=DEV/'economy_component'

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,text):
    with p.open('x',encoding='utf-8') as f:f.write(text)
def main():
    fixture=COMPONENT/'test_economy_reuse.lua'
    fixture_receipt=COMPONENT/'fixture_receipt2.json'
    comparison_receipt=COMPONENT/'comparison_receipt1.json'
    failed=COMPONENT/'fixture_failure1.json'
    unit=read(fixture_receipt);comparison=read(comparison_receipt)
    assert unit['exit_code']==0 and unit['fixture_sha256']==sha(fixture)
    assert '47 checks passed' in unit['output']
    assert comparison['exit_code']==0 and 'cases=144 old_strategy_previews=2302 new_strategy_previews=714' in comparison['output']
    for name in ('compare.lua','before_economy.lua','economy.lua','consumables.lua'):
        assert sha(COMPONENT/name)==comparison['files'][name],name
    # The real strategy baseline used in component evidence predates 337; bind
    # its preserved exact bytes without requiring the current strategy to regress.
    strategy_before=DEV/'inventory_release/payload/tests/fixtures/inventory337/strategy.base.lua'
    assert sha(strategy_before)==comparison['files']['strategy.lua']
    failure=read(failed)
    assert failure['kind']=='manufactured_fixture_assertion_error' and failure['exit_code']==1
    assert sha(COMPONENT/'test_economy_reuse.failed1.lua')==failure['fixture_sha256']
    candidate=EVAL/'runs/cash338_candidate/validation/report.json'
    report=read(candidate)
    assert report['passed'] and report['policy_unchanged'] and report['tests_unchanged']
    integration=read(HERE/'integration.json')
    assert report['policy_digest']==integration['policy_digest']
    for relative,hashes in integration['files'].items():assert sha(ROOT/relative)==hashes['after'],relative
    production_fixture=ROOT/'tests/advisor_economy_reuse.lua'
    expected_fixture=fixture.read_text(encoding='utf-8').replace(
      'tools/advisor_eval/development335/economy_component/economy.lua','Brainstorm/Advisor/economy.lua').replace(
      'tools/advisor_eval/development335/economy_component/consumables.lua','Brainstorm/Advisor/consumables.lua')
    assert 'development335' not in expected_fixture
    assert production_fixture.read_text(encoding='utf-8')==expected_fixture
    tests={key.replace('\\','/'):value for key,value in report['test_files'].items()}
    assert tests['tests/advisor_economy_reuse.lua']==sha(production_fixture)
    prior=DEV/'inventory_release/release_final/context.json'
    value=read(prior)
    assert value['release']==337 and value['status']=='CLOSED'
    previous_policy=read(EVAL/'runs/inventory337_installed/record.json')['policy']
    assert integration['previous_policy_digest']==previous_policy['policy_digest']
    before_consumables=HERE/'before/Brainstorm/Advisor/consumables.lua'
    assert sha(before_consumables)==previous_policy['policy_files']['Brainstorm/Advisor/consumables.lua']
    original=before_consumables.read_text(encoding='utf-8')
    anchor='local function joker_name(j)'
    assert original.count(anchor)==1 and 'M.equivalent_owned=' not in original
    expected=original.replace(anchor,'-- Shared by the shop cash planner; no grouping mutates the actual inventory.\nM.equivalent_owned=equivalent_owned\n'+anchor)
    assert (ROOT/'Brainstorm/Advisor/consumables.lua').read_text(encoding='utf-8')==expected
    for key in ('release_validation','prepared_context_preserved'):value.pop(key,None)
    value.update(
      release=338,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
      counts_scope='historical_closed_cycle',release_counts={key:0 for key in value['counts']},
      preparation_status='passed_candidate_exact_installed_validation_bound_separately',
      summary='Complete the current four-part redundancy audit: 335 journal work, 336 score helpers, 337 per-decision starting inventory/profile reuse, and 338 adjacent cash-copy previews. The cash planner retains one physical first-use representative per contiguous fully equivalent Hermit/Temperance group plus the full copy count. Same-group and cross-group two-use previews remain explicit. The existing equality helper is exported on top of verified 337 consumables; prior inventory reuse remains in place.',
      outcome_summary='Release 338 uses manufactured fixtures and routine regression only. The cash fixture passes 47 checks; ten adjacent equivalent Negative Hermits use two measured strategy previews for the first and second physical uses. The old loop requires 10 plus 10 times 9 previews, or 100 by static source count, not a separately measured value. Across 144 manufactured states using real strategy ratings, complete outputs match and measured strategy previews fall from 2,302 to 714. The preserved fixture_failure1 records an incorrect expected uncapped Temperance action: a $30 payout was below the $50 cap. The fixture was corrected to a capped payout and runtime code was unchanged; this was a manufactured harness assertion, not a strategic loss. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331; they are not 338 validation.',
      limits_summary='Grouping is limited to adjacent full-public-metadata equivalents, ignoring only top-level physical ID. Only positive valid first uses enter the existing candidate list; copy multiplicity retains a second use when legal. Physical removal/order, Negative capacity, cash caps, Perkeo/source preservation, Luxury Tax and Vagabond protections are recomputed after each distinct use. Metadata-distinct and separated copies remain separate. Prior journal, scoring and inventory work remains intact. Execution/publication freshness checks and existing recorder validation were deliberately retained; no cross-frame or cross-decision cache was added. User activation and live FPS remain unconfirmed. No complete win, terminal rescue, win odds, achievement completion or superiority over human play follows. Preserve logs, settings, native dependencies and dirty/untracked work.',
      budget_summary='All experiment allowances remain CLOSED. Release 338 starts zero source components, captured-state policy replays, searches and complete attempts. It reads no source executable archive, player saves or profiles, and does not control the game. Only manufactured Lua fixtures and relevant full regressions run, with 60-second per-suite caps. Historical loss328 used four public pairs and six source attempts, 1,200 seconds reserved and 685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed. No worker, source attempt, search or scheduled continuation is pending. Activation waits for the user normal restart.')
    entries={
      'previous_checkpoint':prior,'integration':HERE/'integration.json','candidate_validation':candidate,
      'before_economy':HERE/'before/Brainstorm/Advisor/economy.lua','before_consumables_337':before_consumables,
      'manufactured_fixture':production_fixture,'component_fixture':fixture,'fixture_receipt':fixture_receipt,
      'comparison_fixture':COMPONENT/'compare.lua','comparison_receipt':comparison_receipt,
      'comparison_strategy_baseline':strategy_before,'preserved_fixture_assertion':failed,
      'preserved_failed_fixture':COMPONENT/'test_economy_reuse.failed1.lua',
      'journal_audit':DEV/'runtime_component/findings.md','scoring_audit':DEV/'scoring_component/findings.md',
      'inventory_component':EVAL/'INVENTORY_REUSE_337.md'}
    value['diagnostic_evidence']={name:ref(path) for name,path in entries.items()}
    value['manufactured_work_counts']={'release':338,'scope':'current_release_manufactured_fixtures',
      'checks':47,'real_strategy_cases':144,
      'strategy_previews':{'before':2302,'after':714},
      'ten_equivalent_hermit_previews':{'before_static':100,'after_measured':2},'measured_live_fps':False}
    out=HERE/'release_context'
    assert not out.exists() and not (EVAL/'CASH_COPY_REUSE_338.md').exists()
    # All evidence checks finish before new context/navigation is written.
    component=(HERE/'COMPONENT_DRAFT.md').read_text(encoding='utf-8')
    priorities=(HERE/'PRIORITIES_DRAFT.md').read_text(encoding='utf-8')
    architecture=(HERE/'ARCHITECTURE_DRAFT.md').read_text(encoding='utf-8')
    objective=(HERE/'OBJECTIVE_DRAFT.md').read_text(encoding='utf-8')
    previous_objective=(DEV/'inventory_release/release_context/objective.md').read_text(encoding='utf-8')
    out.mkdir(exist_ok=False)
    write(out/'context.json',json.dumps(value,indent=2)+'\n')
    write(EVAL/'CASH_COPY_REUSE_338.md',component)
    write(out/'priorities.md',priorities)
    write(out/'architecture.md',architecture)
    write(out/'objective.md',objective+'\n'+previous_objective)
    print(json.dumps(ref(out/'context.json')))
if __name__=='__main__':main()
