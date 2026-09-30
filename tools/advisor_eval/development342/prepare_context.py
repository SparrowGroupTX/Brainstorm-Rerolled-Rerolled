"""Bind the presentation lifecycle repair to closed experiment accounting."""
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

candidate = EVAL / 'runs/presentation342_candidate/validation/report.json'
result = read(candidate)
integration = read(HERE / 'integration.json')
assert result['passed'] and result['policy_unchanged'] and result['tests_unchanged']
assert result['policy_digest'] == integration['policy_digest']
for name, hashes in integration['files'].items(): assert ref(ROOT / name)['sha256'] == hashes['after']
prior = EVAL / 'development341/release_final/context.json'
value = read(prior)
assert value['release'] == 341 and value['status'] == 'CLOSED'
for key in ('release_validation', 'prepared_context_preserved', 'manufactured_work_counts'):
    value.pop(key, None)
value.update(
    release=342, created_at_utc=datetime.now(timezone.utc).isoformat(),
    previous_checkpoint_context=ref(prior), counts_scope='historical_closed_cycle',
    release_counts={key: 0 for key in value['counts']},
    preparation_status='passed_candidate_exact_installed_validation_bound_separately',
    summary='Repair the persistent Card.flipping lifecycle mismatch in public Joker observation. The game retains its flip direction after the logical/rendered facing agree and pinch.x becomes false; the observer previously treated every nonnil direction as unfinished. Qualified settled backs now admit rendered effect observations, public reorder authorization and observed drag. Settled revealed fronts expire concealed beliefs, can be remembered again, and become visible to Snapshot and opt-in Gold held-inventory capture. Real or uncertain transitions remain blocked and redacted. The installed terminal-screen/run-cap repair from 341 remains intact.',
    outcome_summary='The preceding passive session confirms loaded 2.140: four hands against Amber Acorn, 147,894/400,000, a loss with zero hands/three unused discards, then the five-run limit. It recorded no public Joker effect observations. The preserved source lifecycle explains a concrete observer mismatch, but the log does not contain every live presentation field needed to establish it as the only runtime cause. Original modules fail a new manufactured source-shaped regression at six worlds instead of two; repaired modules pass 190 Acorn checks and 334 Gold checks. These fixtures demonstrate restored public observation/visibility behavior, not a rescued run or stronger win rate. The passive session one-win/four-loss total is separate from the historical closed loss328 experiments (three losses, one error, one timeout, one unsupported, zero wins).',
    limits_summary='Directed flips qualify only with a known direction, matching facing and sprite_facing, and explicit pinch.x=false. Active, missing, malformed or mismatched transition fields remain conservative. Concealed identities are never recovered from saved state, physical IDs or hidden card payloads; current rendered slots and remembered unordered public inventory retain their existing roles. Existing score/world/order budgets and complete comparisons are unchanged. Acorn joint hands/discards/owned-consumable planning, broader resources and ability transitions remain unfinished. No new live observation or terminal benefit is verified for 2.142; activation waits for the user normal restart. Settings, logs, every native dependency and all earlier evidence are preserved.',
    budget_summary='All experiment allowances remain CLOSED. Release 342 uses read-only already-preserved source excerpts/passive evidence and manufactured fixture/regression validation with 60-second per-suite caps. Zero source components, captured-policy replays, searches or complete attempts started; no executable archive, player save/profile, live game control or scheduled continuation was used. Historical loss328 accounting stays 1,200 seconds reserved/685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed.'
)
stage = HERE / 'presentation_component'
value['diagnostic_evidence'] = {name: ref(path) for name, path in {
    'previous_checkpoint': prior, 'integration': HERE / 'integration.json',
    'passive_log_analysis': EVAL / 'development341/log_analysis/acorn_session_audit.json',
    'staged_component': stage / 'result.json',
    'manufactured_baseline_failure': stage / 'validation_01_before.json',
    'manufactured_candidate_pass': stage / 'validation_01_staged.json',
    'source_provenance': stage / 'validation_01_evidence.json',
    'observer_fixture': ROOT / 'tests/advisor_acorn_public.lua',
    'gold_fixture': ROOT / 'tests/advisor_gold_stickers.lua',
    'candidate_validation': candidate,
}.items()}
value['manufactured_work_counts'] = {'release': 342, 'scope': 'manufactured_inputs_only',
    'acorn_public_checks': 190, 'gold_sticker_checks': 334,
    'captured_state_policy_replays': 0, 'live_rescue_verified': False}
component = '''# Public Joker presentation lifecycle - 342

The passive session documented in AUTO_RUN_TERMINAL_341.md confirms loaded
2.140. Its last blind played four hands for 147,894/400,000 and lost at zero
hands, leaving three discards. Five public Jokers retained 120 possible orders;
four action completions and zero public effect observations were recorded.
The five-run cap and prematurely dismissed loss overlay were fixed in 341.

Read-only preserved source card.lua lines 4113-4142 shows Card:flip assigning
flipping='f2b'/'b2f', while Card:update changes sprite_facing and pinch.x=false
without clearing flipping. common_events.lua lines779-785/875-917 supplies
attention_text's major/text/backdrop_colour after focus redirection. Exact
source hashes and ranges are sealed in development342/presentation_component/
result.json and validation_01_evidence.json. No executable ZIP was read or
original source executed. The passive log lacks the full live presentation
fields, so this is a concrete source mismatch rather than proof that every
missing popup had this single cause.

Advisor/acorn_public.lua now qualifies a directed flip as settled only when
its direction is recognized, logical/rendered facings both match its target,
and pinch.x is explicitly false. That shared local predicate controls shuffle
settling, visible-front memory, hidden redaction, display-slot observation,
public reorder authorization and drag-origin certification. Nil-direction
legacy cards remain supported unless pinch is active or malformed. Unknown,
missing and mismatched directed-flip fields remain blocked.

Advisor/snapshot.lua uses the same presentation predicate before reading Joker
identity. Advisor/gold_stickers.lua uses its equivalent through raw get, retaining
opt-in and hidden-row public-inventory fallback. Settled fronts are no longer
permanently unavailable after a back-to-front flip. Actual backs stay redacted.
No new identity join, RNG read, scoring budget, inference class or loader
dependency is introduced.

tests/advisor_acorn_public.lua adds source-shaped flip/settle fixtures leaving
flipping nonnil: six worlds narrow to two from a rendered X4 event; juice stays
non-identifying; settled backs authorize existing public proofs and observed
drag; revealing fronts remain hidden until settled, then retire belief and
can be remembered before a later concealment. Poisoned concealed identity
fields are never read. Snapshot and Gold tests cover front recovery, explicit
redaction, active/nil/unknown/malformed transition fields and Gold rawget safety.
The original modules fail at the expected six-versus-two assertion; staged
modules pass 190 Acorn and 334 Gold checks. Full candidate/exact-installed reports
are under runs/presentation342_candidate, presentation342_installed,
presentation342_installed_validation and presentation342_final.

The change restores supported public observations. It does not demonstrate a
rescued blind, improved terminal outcomes or calibrated win odds. Complete
discard/consumable/hand planning, broader resources and unknown ability
transitions remain outside current Acorn support. All experiment budgets stay
closed; no source/search/replay/attempt worker ran. Current configuration, logs,
native files and all earlier evidence remain preserved. Tools did not control
the game; installed 342 activates at the user's normal restart.
'''
priorities = '''# Priorities after 342

The two concrete defects found in the latest passive Acorn report are repaired:
341 retains the result at the session cap (including Stop/Resume), and 342
recognizes completed flips so public effect observations can be recorded.
Loaded 2.140 was confirmed; live activation and effect capture under 2.142 await
the user's normal restart. Neither slice establishes a rescued run.

Read future passive logs for actual Joker observation events and narrowing,
and preserve any unsupported/contradictory evidence. Never fill missing public
observations from concealed fields, physical identity joins or save data.

The largest remaining Acorn strategy gap in this trace is that all three
discards remained unused. Develop the smallest complete common-world comparison
of a resource action and its supported continuation; account for Yorick/Burnt,
draw uncertainty, held rewards, cash, population/Glass, inventory and user time.
Do not choose different actions using different unobserved Joker worlds or
increase score caps to mask the gap. A local upgrade is not a terminal rescue.

Broader Jokerless, Knife's Edge and Gold-sticker work remains unfinished.
Source/search/captured replay/terminal experiments require new prospective
authority; only read-only analysis and routine fixtures are currently open.
'''
architecture = '''# Public presentation navigation - 342

- Advisor/acorn_public.lua: source-shaped settled-flip gate for public memory,
  effects, physical slot movement, reorder authorization and redaction.
- Advisor/snapshot.lua: aligned visibility gate before any Joker identity read.
- Advisor/gold_stickers.lua: raw-field equivalent and existing hidden-memory
  fallback; opt-in loaded-table capture only.
- tests/advisor_acorn_public.lua and advisor_gold_stickers.lua: persistent
  f2b/b2f lifecycle, public world narrowing, reveal and redaction regressions.
- ACORN_PRESENTATION_342.md and development342/presentation_component/result.json:
  exact source/runtime/test hashes, baseline failure and manufactured pass.
- AUTO_RUN_TERMINAL_341.md / ARCHITECTURE_MAP_341.md: retained terminal screen,
  fresh run-cap/completion checks and explicit Stop/Resume behavior.
- ARCHITECTURE_MAP_340.md: immediate Acorn play/order score floors and budgets.
- ARCHITECTURE_MAP_338.md: prior scoring, resource, inventory and logging map.

This map grants no new experiment authority. Earlier evidence remains intact.
'''
objective = 'Restore public Joker effect observation after completed flips, preserving the terminal-cap repair, hidden-information safeguards and complete bounded planning.\n\n' + (EVAL / 'development341/release_context/objective.md').read_text(encoding='utf-8')
out = HERE / 'release_context'
out.mkdir(exist_ok=False)
write(out / 'context.json', json.dumps(value, indent=2) + '\n')
write(EVAL / 'ACORN_PRESENTATION_342.md', component)
write(out / 'priorities.md', priorities)
write(out / 'architecture.md', architecture)
write(out / 'objective.md', objective)
print(json.dumps(ref(out / 'context.json')))
