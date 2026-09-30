"""Bind scoring336 candidate evidence and carry forward the closed335 context.

Root executes this only after candidate validation. The final binder separately
attaches complete candidate and exact-installed suite counts. No experiments.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parents[1]
ROOT = EVAL.parents[1]
COMPONENT = HERE.parent / 'scoring_component'
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes
from finalize_runtime_checkpoint import experiment_context

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def ref(path): return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}
def write(path, text):
    with path.open('x', encoding='utf-8') as stream: stream.write(text)

candidate_sha = 'f625c294eb5ba9cf0b6da5eb8f871c58be0835aecf92396c09151becef1c80e9'
fixture_sha = '9bbe84a8b4119c82bb788792789d1cbd3896ce179c484586da8f0fd94a998fee'
baseline_sha = 'b77a211cf2480d55008dc96e993b66d380a92e4e466d44f58b25a9e9bc0a11cf'
fixture = ROOT / 'tests/advisor_scoring_reuse.lua'
baseline = ROOT / 'tests/fixtures/advisor_scoring_reuse336/scoring_before.lua'
assert sha(COMPONENT / 'scoring.lua') == sha(ROOT / 'Brainstorm/Advisor/scoring.lua') == candidate_sha
assert sha(HERE / 'advisor_scoring_reuse.lua') == sha(fixture) == fixture_sha
assert sha(COMPONENT / 'scoring_before.lua') == sha(baseline) == baseline_sha
integration = read(HERE / 'integration.json')
candidate = EVAL / 'runs/scoring336_candidate/validation/report.json'
validation = read(candidate)
assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
assert validation['policy_digest'] == integration['policy_digest']
assert validation['policy_files'] == policy_hashes(ROOT)
test_hashes = {key.replace('\\', '/'): value for key, value in validation['test_files'].items()}
assert test_hashes[fixture.relative_to(ROOT).as_posix()] == fixture_sha
assert test_hashes[baseline.relative_to(ROOT).as_posix()] == baseline_sha
component_receipt = COMPONENT / 'fixture_receipt3.json'
standalone_receipt = HERE / 'standalone_validation2/receipt.json'
assert read(component_receipt)['exit_code'] == read(standalone_receipt)['exit_code'] == 0
assert read(component_receipt)['sha256']['scoring.lua'] == candidate_sha
assert read(standalone_receipt)['files']['tests/advisor_scoring_reuse.lua'] == fixture_sha

prior = EVAL / 'development335/journal_release/release_final/context.json'
experiment_context(prior)  # Validate preserved authority/budget/outcome references.
value = read(prior)
assert value['release'] == 335 and value['status'] == 'CLOSED'
previous_installed = EVAL / 'runs/journal335_installed/record.json'
assert read(previous_installed)['version'] == '2.135.0-alpha'
assert read(previous_installed)['policy']['policy_digest'] == integration['previous_policy_digest']
assert ref(previous_installed) == integration['previous_installed_record']
for key in ('release_validation', 'prepared_context_preserved'):
    value.pop(key, None)
value.update(
    release=336, created_at_utc=datetime.now(timezone.utc).isoformat(),
    previous_checkpoint_context=ref(prior), counts_scope='historical_closed_cycle',
    release_counts={key: 0 for key in value['counts']},
    preparation_status='passed_candidate_exact_installed_validation_bound_separately',
    summary='Remove repeated scoring-intrinsic work while retaining every complete scoring call. Five private constant lookup tables are built once; explicit numeric nominal values skip unused rank defaults and fallback resolves rank once; the lowest-held scan runs only when existing row flags contain active Raised Fist. Exact lookup precedence, ordered scoring and copy routing are preserved. No new state/result cache, scoring budget or sampling change is introduced.',
    outcome_summary='Release 336 uses manufactured fixtures and routine regression only. Its independent scoring fixture passes 3,402 checks across 476 complete comparison cases, retaining all 2,217 full scorer invocations. Instrumented constant-table constructions decrease from 88,706 to five module-load tables, rank helper calls from 41,945 to 11,914, enhancement helper calls from 97,041 to 57,556, and lowest-held visits from 11,232 to 1,778. All 7,765 nominal lookups remain. Comparisons preserve complete expected/floor/ceiling outputs, uncertainty, ordered transitions, inventory order and population effects. These are manufactured work counts, not live timing or gameplay results. Previous journal335 measurements and historical complete-attempt outcomes remain attributed to their own releases.',
    limits_summary='This slice reuses immutable intrinsic lookup data and removes provably unused helper work only. Current state is read on each scoring call, including in-place card/row/value changes; preexisting prepared caches still require detached immutable decision scopes. Numeric nominal zero, NaN and infinities, nonnumeric/false fallback precedence, Ace/Stone cases, copy/debuff/unknown routes, retained consumable ordering and Glass/Lucky effects are covered. No full-score partial-key cache is added. Prior journal335 and callback fixes are preserved, but activation and restored live responsiveness remain unconfirmed until the user normal restart and observation. No live FPS, terminal rescue, numerical win odds, achievement completion or stronger-than-human performance follows from the fixture. Preserve logs, settings, native dependencies and all dirty/untracked work.',
    budget_summary='All experiment allowances remain CLOSED. Release 336 runs zero source components, captured-state policy replays, searches and complete attempts. It reads no source executable archive, player save or profile, and does not control the game. Only manufactured Lua fixtures and relevant full regressions run, with 60-second per-suite caps. Historical source authority, outcomes, budget usage and unused closed capacity are carried forward unchanged through the previous finalized335 context and its original evidence references. No worker, source attempt, search or scheduled continuation is pending. Activation waits for the user normal restart.',
)
value['diagnostic_evidence'] = {name: ref(path) for name, path in {
    'previous_checkpoint': prior,
    'previous_installed_record': previous_installed,
    'before_module': HERE / 'before/Brainstorm/Advisor/scoring.lua',
    'candidate_module': COMPONENT / 'scoring.lua',
    'manufactured_component_fixture': COMPONENT / 'test_scoring_reuse.lua',
    'component_receipt': component_receipt,
    'independent_production_fixture': fixture,
    'frozen_test_baseline': baseline,
    'standalone_receipt': standalone_receipt,
    'integration': HERE / 'integration.json',
    'candidate_validation': candidate,
}.items()}
out = HERE / 'release_context'
out.mkdir(exist_ok=False)
write(out / 'context.json', json.dumps(value, indent=2)+'\n')
experiment_context(out / 'context.json')
component = (HERE / 'notes/COMPONENT_DRAFT.md').read_text(encoding='utf-8')
component = component.replace('Their existence and verified\ncounts determine completion; this draft does not assert they have run.',
    'Candidate validation passed. The final binder and exact-installed records\nsupply complete suite counts and installation state separately.')
write(EVAL / 'SCORING_REUSE_336.md', component)
write(out / 'priorities.md', (HERE / 'notes/PRIORITIES_DRAFT.md').read_text(encoding='utf-8'))
write(out / 'architecture.md', (HERE / 'notes/ARCHITECTURE_DRAFT.md').read_text(encoding='utf-8'))
prior_objective = EVAL / 'development335/journal_release/release_context/objective.md'
write(out / 'objective.md',
      'Remove demonstrated redundant computations while preserving complete bounded comparisons, current-state reads and exact ordered outcomes.\n\n' +
      prior_objective.read_text(encoding='utf-8'))
print(json.dumps(ref(out / 'context.json')))
