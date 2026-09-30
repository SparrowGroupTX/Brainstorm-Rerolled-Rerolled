"""Bind manufactured evidence and carry forward explicitly closed experiment records."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p): return {'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)}
def write(p, text):
    with p.open('x', encoding='utf-8') as f: f.write(text)

assert sha(HERE/'test_duplicates.lua') == 'f43ce861975a461eaff0465d7580f849783f2fcc4ebfca81f7d4495f6a042e33'
assert sha(ROOT/'tests/advisor_consumable_duplicates.lua') == sha(HERE/'test_duplicates.lua')
assert sha(HERE/'fixture_receipt3.json') == 'e5b92f5b3e16006870b565a9227281810f46e4e36bc4686a3faa5c232a5ed6bf'
assert sha(HERE/'comparison_receipt1.json') == 'b7e04705a9fe97df1e8ba6d6c8bd4babe987c82459ee1a97eec537a14beb9728'
candidate = EVAL/'runs/duplicates334_candidate/validation/report.json'
assert read(candidate)['passed']
prior = EVAL/'development333/release_final/context.json'
value = read(prior)
for key in ('release_validation', 'prepared_context_preserved'):
    value.pop(key, None)
value.update(
    release=334, created_at_utc=datetime.now(timezone.utc).isoformat(),
    previous_checkpoint_context=ref(prior), counts_scope='historical_closed_cycle',
    release_counts={key: 0 for key in value['counts']},
    preparation_status='passed_candidate_exact_installed_validation_bound_separately',
    summary='Remove redundant complete play comparisons for adjacent identical owned consumables. The general hand planner keeps the earliest physical representative for each contiguous group with equal full public metadata except its top-level ID. All targets, retained inventory counts/order, Negative capacity and Perkeo/Observatory preservation remain represented. Existing upgrade-then-targeted-use sequences use the reduced candidate set with their original index shifting. No scoring budget was increased.',
    outcome_summary='Release 334 uses manufactured fixtures and routine regression only. Its ten-identical-Negative-Death fixture measures 24,852 baseline score calls covering only 12 distinct targets, versus 6,104 candidate calls covering all 28 target pairs, within the unchanged 25,000 cap. These are instrumented mock-scorer invocation counts, not live timing or a complete game. The new fixture passes 209 checks including real-scorer Planet/Tarot sequences, exact action indices, whole Perkeo copying probabilities, Negative capacity, input immutability, metadata distinctions and conservative fallbacks. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331; they are not 334 validation.',
    limits_summary='Only contiguous fully equivalent visible supported cards are merged. Separated copies, edition/ability/price/copy-metadata differences, nested IDs and unknown or unbounded metadata retain separate comparisons. This is equivalence inside current modeled mechanics, not arbitrary external callbacks that inspect physical IDs. The existing planner still searches only bounded upgrade-then-targeted-consumable pairs, not general multi-Tarot sequences. Every actual use removes one card; all remaining copies remain available for later advice and Perkeo. The earlier 333 callback-growth repair is preserved, but its activation and restored live FPS remain unconfirmed. No live FPS, terminal rescue, numerical win odds, achievement completion or stronger-than-human performance follows from this fixture. Preserve all logs, current settings, native dependencies and dirty/untracked work.',
    budget_summary='All experiment allowances remain CLOSED. Release 334 runs zero source components, captured-state policy replays, searches and complete attempts. It reads no source executable archive, player saves or profiles, and does not control the game. Only manufactured Lua fixtures and relevant full regressions run, with 60-second per-suite caps. Historical loss328 used four public pairs and six source attempts, 1,200 seconds reserved and 685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed. No worker, source attempt, search or scheduled continuation is pending. Activation waits for the user normal restart.',
)
value['diagnostic_evidence'] = {name: ref(path) for name, path in {
    'previous_checkpoint': prior,
    'before_module': HERE/'before/consumables.lua',
    'manufactured_fixture': HERE/'test_duplicates.lua',
    'fixture_receipt': HERE/'fixture_receipt3.json',
    'comparison_fixture': HERE/'compare_death.lua',
    'comparison_receipt': HERE/'comparison_receipt1.json',
    'integration': HERE/'integration.json',
    'candidate_validation': candidate,
}.items()}
out = HERE/'release_context'
out.mkdir(exist_ok=False)
write(out/'context.json', json.dumps(value, indent=2)+'\n')

component = (HERE/'notes/COMPONENT_DRAFT.md').read_text(encoding='utf-8')
component = component.replace('This draft describes the source change and its bounds.', 'This note describes the completed source change and its bounds.')
component = component.replace("Root's production fixture map and finalized release records supply measured\ncandidate counts, selected-action checks and exact-installed regression results.\nThis draft makes no claim about their completion or totals.",
    'Production regression: `tests/advisor_consumable_duplicates.lua` passes 209 checks.\nThe candidate and exact-installed receipts listed below bind all complete-suite\ncounts and frozen hashes; final verification records installation and preservation.')
component += '''
## Measured manufactured evidence and release records

`development334/comparison_receipt1.json` records the ten-Negative-Death
workload using instrumented mock scores: baseline 24,852 calls / 114 physical
candidate comparisons / 12 distinct targets, truncated by the 25,000 cap;
candidate 6,104 calls / 28 complete distinct targets, with no truncation.
The source snapshot remains unchanged. This is a work-count measurement and
coverage check, not a wall-time benchmark or gameplay result.

`development334/fixture_receipt3.json` records 209 passing checks, including
real-scorer upgrade/Tarot sequences in both inventory orders, repeated public
decisions, all retained copying probabilities, actual one-card removals,
Negative capacity and metadata/visibility/depth/cycle fallback boundaries.
Earlier passing fixture receipts remain separately preserved.

Full evidence: `runs/duplicates334_candidate/validation/report.json`,
`runs/duplicates334_installed/record.json` and `policy/`,
`runs/duplicates334_installed_validation/report.json`, and
`runs/duplicates334_final/final_verification.json`.
'''
write(EVAL/'EQUIVALENT_CONSUMABLES_334.md', component)
priorities = (HERE/'notes/PRIORITIES_DRAFT.md').read_text(encoding='utf-8')
priorities = priorities.replace('this draft supplies no pending work or authority.', 'this navigation grants no experiment authority.')
write(out/'priorities.md', priorities)
architecture = (HERE/'notes/ARCHITECTURE_DRAFT.md').read_text(encoding='utf-8')
architecture += '\nProduction fixture: `tests/advisor_consumable_duplicates.lua` (209 checks). Component: `EQUIVALENT_CONSUMABLES_334.md`. No new runtime module or source adapter wiring is needed.\n'
write(out/'architecture.md', architecture)
objective = (EVAL/'development333/release_context/objective.md').read_text(encoding='utf-8')
write(out/'objective.md', 'Avoid repeated work on equivalent owned copies while preserving useful distinct actions, exact inventory and complete bounded comparisons.\n\n'+objective)
print(json.dumps(ref(out/'context.json')))
