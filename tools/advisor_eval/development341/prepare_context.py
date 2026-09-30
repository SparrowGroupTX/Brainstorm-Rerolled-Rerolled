"""Document a verified terminal-screen repair without renewing experiment authority."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def ref(path): return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
def write(path, text):
    with path.open('x', encoding='utf-8') as stream: stream.write(text)

candidate = EVAL / 'runs/terminal341_candidate/validation/report.json'
result = read(candidate)
integration = read(HERE / 'integration.json')
assert result['passed'] and result['policy_unchanged'] and result['tests_unchanged']
assert result['policy_digest'] == integration['policy_digest']
for name, hashes in integration['changed_runtime'].items(): assert ref(ROOT / name)['sha256'] == hashes['after']
prior = EVAL / 'development340/release_final/context.json'
value = read(prior)
assert value['release'] == 340 and value['status'] == 'CLOSED'
for key in ('release_validation', 'prepared_context_preserved', 'manufactured_work_counts'):
    value.pop(key, None)
value.update(
    release=341, created_at_utc=datetime.now(timezone.utc).isoformat(),
    previous_checkpoint_context=ref(prior), counts_scope='historical_closed_cycle',
    release_counts={key: 0 for key in value['counts']},
    preparation_status='passed_candidate_exact_installed_validation_bound_separately',
    summary='Preserve the original result screen when auto-run has reached its configured run cap, completed the collection, or cannot verify fresh collection metadata. The controller now checks a fresh terminal observation before the product closes its owned result overlay. Under-limit continuation still closes that overlay before searching; a reached run cap has a plain-language count/outcome message and cannot Resume or renew the session allowance.',
    outcome_summary='Read-only passive session session-20260916T005407Z-1 confirms loaded 2.140. It played four hands against Amber Acorn, scoring 147,894/400,000, lost with zero hands and three unused discards, then stopped at the configured five-run limit. Its passive session totals were one win and four losses; these are not a new simulated cohort or a general win-rate estimate. The product had closed the loss overlay before discovering the cap, leaving an unclear dead table. The manufactured baseline fails the new final-cap assertion and the candidate passes the relevant controller/product/terminal fixtures. No logged run was replayed or rescued. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins.',
    limits_summary='This slice fixes terminal presentation and transition ordering, not the recorded loss. The four Acorn decisions used immediate public-world play comparisons and left all three discards unused. There were zero public Joker activation observations; a separate read-only source inspection found a persistent-flipping-field mismatch, for a subsequent separately tested repair. That diagnosis is not evidence of an improved terminal outcome. All existing search, session, action and retry limits, saved settings, logs and native dependencies remain preserved. Activation of this new installation waits for the user normal restart; the observed prior loaded version was 2.140.',
    budget_summary='All experiment allowances remain CLOSED. Release 341 uses read-only existing passive logs/source excerpts and manufactured fixture/regression validation only, with 60-second per-suite caps. Zero source components, captured-policy replays, searches or complete attempts were started; no executable archive, player save/profile, live game control or scheduled continuation was used. Historical loss328 accounting remains 1,200 seconds reserved/685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed.'
)
value['diagnostic_evidence'] = {name: ref(path) for name, path in {
    'previous_checkpoint': prior, 'integration': HERE / 'integration.json',
    'passive_log_analysis': HERE / 'log_analysis/acorn_session_audit.json',
    'manufactured_baseline_failure': HERE / 'terminal_component/baseline.json',
    'manufactured_candidate_pass': HERE / 'terminal_component/candidate2.json',
    'component_result': HERE / 'terminal_component/result2.json',
    'component_before_manifest': HERE / 'terminal_component/before.json',
    'controller_fixture': ROOT / 'tests/advisor_auto_run.lua',
    'product_fixture': ROOT / 'tests/advisor_auto_run_product.lua',
    'candidate_validation': candidate,
}.items()}
component = '''# Auto-run terminal screen and run cap - 341

The passive session session-20260916T005407Z-1 ran loaded 2.140. Its final
Amber Acorn attempt played four hands for 147,894/400,000 chips and lost at
zero hands, leaving three discards. Loss sequence4572 preceded run_limit
sequence4575 at five runs (one win/four losses). These are passive session
records, not new simulated trials. Exact read-only anchors and byte hashes are
in development341/log_analysis/acorn_session_audit.json. The last segment was
append-active; its hash identifies only the bytes observed during that audit.

Core/auto_run_product.lua previously dismissed the owned terminal overlay
before Advisor/auto_run.lua could check its fresh terminal observation against
the cap. It now ticks the controller first and closes only if still active in
terminal state, with controls settled. The controller checks fresh collection
metadata, completion, then run cap before readiness for another search. The
result remains visible for terminal stops. Below-cap continuation still closes
the original owned result surface, then starts a new search on a later update.

Controller status exposes max_runs and run_limit_reached. The product explains
the reached count and win/loss counts. Existing stop/resume, cap, ownership,
logging-before-transition, collection metadata and session-time protections
remain. No counters, user settings or exhausted allowances are reset.

tests/advisor_auto_run_product.lua adds manufactured coverage alongside the
existing controller fixtures for the final five-run overlay, below-cap continuation, fresh complete
or unknown metadata, delayed result UI, foreign overlays, outcome uniqueness,
Stop/Resume, logging failure and session deadline. The preserved baseline
fails the expected final-cap assertion. Candidate component evidence is in
development341/terminal_component; full candidate and exact-installed evidence
is under runs/terminal341_candidate, terminal341_installed,
terminal341_installed_validation and terminal341_final.

This is a presentation/transition repair, not a strategy win. The same passive
blind had zero Joker activation observations. Preserved source Card:update
leaves flipping nonnil after facing/sprite_facing and pinch settle; the observer
treats it as perpetually busy. That separate mismatch is being prepared for a
subsequent fixture-tested slice. Discard/consumable joint planning remains
unfinished, as do unsupported Acorn resources and ability transitions.

No source worker, captured replay, seed search, complete attempt, save/profile
read or live game control occurred. All historical experiment budgets remain
closed. Current settings, logs and every native dependency are preserved.
'''
priorities = '''# Priorities after 341

The apparent freeze at zero hands was a logged loss followed by the user's
five-run cap. Preserve the loss surface at terminal stops; do not increase or
renew that cap. Loaded 2.140 is confirmed in passive logs; 2.141 activation
awaits the user's normal restart.

Next: repair the concrete Card.flipping lifecycle mismatch in public Joker
observation, with source-shaped manufactured tests for settled backs/fronts,
real transitions, redaction and observed slot movement. No hidden identities
or retrospective source replay may substitute for missing public observations.

Acorn still lacks complete joint discard/consumable/hand planning and broader
resource/ability coverage. The logged unused discards identify missing scope;
they do not prove a particular counterfactual wins. Retain exact score floors,
complete common-world comparisons, population/inventory guards and all budgets.
The broader Jokerless, Knife's Edge and Gold-sticker objectives remain open.
Fresh source/replay/search/terminal experiments need prospective authority.
'''
architecture = '''# Terminal transition navigation - 341

- Advisor/auto_run.lua: controller terminal receipt, fresh collection goal,
  run cap, counters and resumability.
- Core/auto_run_product.lua: reread before owned overlay close; run-limit text.
- Advisor/auto_terminal.lua: unchanged source-bound terminal/overlay ownership.
- tests/advisor_auto_run.lua and advisor_auto_run_product.lua: manufactured
  final-cap, continuation, fresh metadata, logging and Stop/Resume coverage.
- AUTO_RUN_TERMINAL_341.md and development341/terminal_component: component
  notes, preserved before bytes, expected baseline failure and candidate pass.
- development341/log_analysis/acorn_session_audit.json: passive 2.140 loss.
- ARCHITECTURE_MAP_340.md: Acorn Lucky/public-world scoring navigation.

This map grants no experiment authority. The separate observer lifecycle
repair is not part of installed 2.141. Keep prior notes/evidence intact.
'''
objective = 'Fix the misleading zero-hands terminal stop and the concrete public-observation defects found in its passive logs, preserving bounded execution and public-information safeguards.\n\n' + (EVAL / 'development340/release_context/objective.md').read_text(encoding='utf-8')
out = HERE / 'release_context'
out.mkdir(exist_ok=False)
write(out / 'context.json', json.dumps(value, indent=2) + '\n')
write(EVAL / 'AUTO_RUN_TERMINAL_341.md', component)
write(out / 'priorities.md', priorities)
write(out / 'architecture.md', architecture)
write(out / 'objective.md', objective)
print(json.dumps(ref(out / 'context.json')))
