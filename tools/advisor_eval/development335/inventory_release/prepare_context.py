"""Root-only: bind passed candidate evidence and carry closed context to release 337."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json
HERE=Path(__file__).resolve().parent
EVAL=HERE.parents[1]
ROOT=EVAL.parents[1]

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,text):
    with p.open('x',encoding='utf-8') as f:f.write(text)
def main():
    manifest=read(HERE/'payload_manifest.json')
    for relative,expected in manifest['files'].items():assert sha(ROOT/relative)==expected,relative
    for relative,expected in manifest['evidence'].items():assert sha(ROOT/relative)==expected,relative
    candidate=EVAL/'runs/inventory337_candidate/validation/report.json'
    report=read(candidate)
    assert report['passed'] and report['policy_unchanged'] and report['tests_unchanged']
    tests={key.replace('\\','/'):value for key,value in report['test_files'].items()}
    for relative,expected in manifest['files'].items():
        if relative.startswith('tests/'):assert tests[relative]==expected,relative
    prior=EVAL/'development335/scoring_release/release_final/context.json'
    value=read(prior)
    assert value['release']==336 and value['status']=='CLOSED'
    for key in ('release_validation','prepared_context_preserved'):value.pop(key,None)
    value.update(
      release=337,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
      counts_scope='historical_closed_cycle',release_counts={key:0 for key in value['counts']},
      preparation_status='passed_candidate_exact_installed_validation_bound_separately',
      summary='Reuse the original profile and whole original inventory value once within each owned-consumable suggestion, including the bounded clearing-development branch. Every retained inventory is still valued under the original profile, and every distinct target development and complete scoring comparison remains intact. The context is discarded before subsequent advice or executed actions. Existing duplicate grouping and score budgets are preserved.',
      outcome_summary='Release 337 uses manufactured fixtures and routine regression only. The new fixture passes 257 checks, including exact recommendation, diagnostic, development and preservation outputs; copying and Observatory guards; actual target effects; both bounded Planet/Tarot sequence orders; legacy strategy APIs; and fresh profiles after same-table public-state changes. In the ten-Negative-Death fixture, profile builds fall from 56 to 1 and original inventory valuations from 28 to 1, while all 28 retained valuations and all 6,104 score calls remain. Mixed Perkeo/Blueprint/Brainstorm/Observatory drops from 84 to 1 profile builds and 42 to 1 original-pool valuations with 42 retained valuations and 1,302 scores unchanged. These are manufactured work counts, not measured live speed or game outcomes. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331; they are not 337 validation.',
      limits_summary='Only unchanged starting work is shared within one suggestion. Retained inventory, after-state target gains, counts/order, Negative capacity, last useful copy-source guards, bounded sequence scope and all complete play calls remain unchanged. Context is neither returned nor persisted, and an actual action requires fresh advice. Existing custom strategies without the new optional API retain prior argument counts. Prior callback, journal and scoring repairs remain preserved; live activation and responsiveness require the user normal restart and fresh observations. No terminal rescue, win odds, achievement completion or stronger-than-human performance follows. Preserve all logs, settings, native dependencies and dirty/untracked work.',
      budget_summary='All experiment allowances remain CLOSED. Release 337 starts zero source components, captured-state policy replays, searches and complete attempts. It reads no source executable archive, player saves or profiles, and does not control the game. Only manufactured Lua fixtures and relevant full regressions run, with 60-second per-suite caps. Historical loss328 used four public pairs and six source attempts, 1,200 seconds reserved and 685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed. No worker, source attempt, search or scheduled continuation is pending. Activation waits for the user normal restart.')
    entries={'previous_checkpoint':prior,'payload_manifest':HERE/'payload_manifest.json','integration':HERE/'integration.json',
      'manufactured_fixture':ROOT/'tests/advisor_inventory_reuse.lua',
      'preserved_docs_encoding_failure':HERE/'context_encoding_failure1/record.json',
      'preserved_partial_context':HERE/'release_context/context.json',
      'before_consumables':ROOT/'tests/fixtures/inventory337/consumables.base.lua',
      'before_strategy':ROOT/'tests/fixtures/inventory337/strategy.base.lua',
      'fixture_receipt':EVAL/'development335/inventory_component/fixture_receipt4.json',
      'existing_fixture_receipt':EVAL/'development335/inventory_component/existing_receipt2.json',
      'prepared_fixture_receipt':HERE/'payload_fixture_receipt1.json','candidate_validation':candidate}
    value['diagnostic_evidence']={name:ref(path) for name,path in entries.items()}
    value['manufactured_work_counts']={'release':337,'scope':'current_release_manufactured_fixtures',
      'checks':257,'death_profile_builds':{'before':56,'after':1},
      'death_original_inventory_valuations':{'before':28,'after':1},
      'death_retained_inventory_valuations':{'before':28,'after':28},
      'death_score_calls':{'before':6104,'after':6104},'measured_live_fps':False}
    out=HERE/'release_context_v2';out.mkdir(exist_ok=False)
    write(out/'context.json',json.dumps(value,indent=2)+'\n')
    component=(HERE/'COMPONENT_DRAFT.md').read_text(encoding='utf-8')
    component=component.replace('This prepared slice','This slice')
    write(EVAL/'INVENTORY_REUSE_337.md',component)
    write(out/'priorities.md',(HERE/'PRIORITIES_DRAFT.md').read_text(encoding='utf-8'))
    write(out/'architecture.md',(HERE/'ARCHITECTURE_DRAFT.md').read_text(encoding='utf-8'))
    prior_objective=EVAL/'development335/scoring_release/release_context/objective.md'
    write(out/'objective.md','Avoid repeated starting-state work while preserving complete candidate valuation and scoring.\n\n'+prior_objective.read_text(encoding='utf-8'))
    print(json.dumps(ref(out/'context.json')))
if __name__=='__main__':main()
