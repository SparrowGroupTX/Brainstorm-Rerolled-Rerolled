"""Record the bounded speed-menu extension after its full candidate regression."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def write(path, text):
    with path.open('x', encoding='utf-8') as stream:
        stream.write(text)

candidate = EVAL / 'runs/speed339_candidate/validation/report.json'
report = read(candidate)
assert report['passed'] and report['policy_unchanged'] and report['tests_unchanged']
source = ROOT / 'Brainstorm/UI/game_speed.lua'
before = HERE / 'before/Brainstorm/UI/game_speed.lua'
assert source.read_text(encoding='utf-8') == before.read_text(encoding='utf-8').replace(
    'ipairs({8, 16})', 'ipairs({8, 16, 32, 64})')
assert ref(source)['sha256'] == report['policy_files']['Brainstorm/UI/game_speed.lua']
tests = {key.replace('\\', '/'): value for key, value in report['test_files'].items()}
fixture = ROOT / 'tests/advisor_game_speed.lua'
assert tests['tests/advisor_game_speed.lua'] == ref(fixture)['sha256']
checks = re.search(r'advisor_game_speed: (\d+) checks passed',
                   (candidate.parent / 'lua.log').read_text(encoding='utf-8'))
assert checks

prior = EVAL / 'development335/economy_release/release_final/context.json'
context = read(prior)
assert context['release'] == 338 and context['status'] == 'CLOSED'
for key in ('release_validation', 'prepared_context_preserved', 'manufactured_work_counts'):
    context.pop(key, None)
context.update(
    release=339, created_at_utc=datetime.now(timezone.utc).isoformat(),
    previous_checkpoint_context=ref(prior), counts_scope='historical_closed_cycle',
    release_counts={key: 0 for key in context['counts']},
    preparation_status='passed_candidate_exact_installed_validation_bound_separately',
    summary='Add 32x and 64x to the existing Game speed option cycle alongside 8x and 16x. The current speed stays unchanged until the user selects a choice. Numeric and string labels, saved selection, additional mod speeds, layout and persistence retain the existing implementation.',
    outcome_summary=f'Release 339 uses routine manufactured fixture/regression validation only. The updated existing speed fixture passes {checks[1]} checks covering all eight standard choices, reopened selection, one settings-save call per choice, numeric-string 32/64 selections, preserved extra speeds without duplicates, invalid input and unchanged menu arguments. These are settings/menu doubles, not live rendered or original-game timing validation. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331; they are not release339 outcomes.',
    limits_summary='Only the existing speed option list is extended. Current configuration is preserved during installation and opening the menu. Native event/timer behavior, auto-run readiness and single-action gates, real-time deadlines, computation budgets and all previous strategy/performance fixes remain unchanged. No proportional gameplay-speed or live-FPS improvement is claimed. Activation waits for the user normal restart; tools do not touch the running game. Logs, current settings, native dependencies and dirty/untracked work remain preserved.',
    budget_summary='All experiment allowances remain CLOSED. Release 339 starts zero source components, captured-state policy replays, searches and complete attempts. It reads no executable archive, player saves or profiles, and does not control the game. Only routine manufactured fixtures and full candidate/exact-installed regression run with 60-second caps per suite. Historical loss328 counts, outcomes and 1,200 seconds reserved/685.3740000000689 seconds actual remain unchanged; unused P05/P06 and 60 seconds remain closed. No worker, source attempt, search or scheduled continuation is pending.')
context['diagnostic_evidence'] = {
    'previous_checkpoint': ref(prior), 'before_files': ref(HERE / 'before.json'),
    'previous_speed_source': ref(before), 'speed_source': ref(source),
    'speed_fixture': ref(fixture),
    'previous_speed_fixture': ref(HERE / 'before/tests/advisor_game_speed.lua'),
    'candidate_validation': ref(candidate), 'previous_speed_mechanics': ref(EVAL / 'ANIMATION_SPEED_318.md')}
component = f'''# Game speed 32x and 64x - 339

The user requested 32x and 64x choices in addition to the existing speeds.
`Brainstorm/UI/game_speed.lua` extends the existing extra-values list from
8/16 to 8/16/32/64. The value-based sorting, duplicate detection, selection
mapping and native settings persistence are unchanged. Existing additional mod
speeds remain available. Opening the menu does not change the current setting.

`tests/advisor_game_speed.lua` now covers all eight standard choices, saved
selection at 32/64, both string labels, extra speeds and existing 32/64 labels,
exactly one save per selection, invalid input, native argument/return forwarding,
unchanged layout and stale-game rejection. Its {checks[1]} checks passed in the
full candidate regression. Final records own the full candidate/exact-installed
suite counts and hashes. Read-only independent review found no additional
runtime integration needed; the previously invalid index7/value32 fixture was
updated because that combination is now valid.

Source/fixture baselines are retained under `development339/before/`.
Evidence: `runs/speed339_candidate/validation/report.json`,
`runs/speed339_installed/record.json`,
`runs/speed339_installed_validation/report.json`, and
`runs/speed339_final/final_verification.json`.

Relevant existing speed mechanics and implementation boundaries remain in
`ANIMATION_SPEED_318.md`. Native event/timer behavior, real clocks, advisor
budgets and auto-run gates are unchanged. The test uses settings/menu doubles;
the actual rendered menu and original-game timing at 32/64 are unverified.
Numeric speed does not promise proportional whole-run speedup. No game control,
save/profile read, source experiment, search or complete attempt occurred.
All experiment allowances stay closed. Current settings, logs and native DLLs
are preserved, and activation waits for the user's normal restart.
'''
priority = '''# Priorities after 339

The requested 32x/64x speed choices are implemented. Activation and their live
behavior await the user's normal restart. Keep the running game undisturbed.
If stalls persist, analyze fresh compact public performance windows; game speed
does not reduce advisor computation. Preserve all freshness and execution gates.

The completed redundancy slices and broader remaining strategic work are in
`NEXT_PRIORITIES_338.md`: joint nonempty Perkeo/Certificate shop exit, broader
resource planning, Jokerless, Knife's Edge, twenty challenges and Gold stickers.
Their existing unsupported guards and closed experiment limits remain intact.
No source/search/replay/complete-attempt allowance is opened by this release.
'''
architecture = '''# Speed option architecture - 339

- `Brainstorm/UI/game_speed.lua`: extends the existing change_gamespeed control
  with 8/16/32/64; preserves value-based mapping, labels and native persistence.
- `Brainstorm/Core/Brainstorm.lua`: unchanged module loading; version stamp only.
- `Brainstorm/steamodded_compat.lua`: matching version stamp.
- `tests/advisor_game_speed.lua`: full selection/persistence and callback guards.
- `ANIMATION_SPEED_339.md`: current component evidence; `ANIMATION_SPEED_318.md`
  retains original implementation and existing source-mechanics observations.
- `ARCHITECTURE_MAP_338.md`: current advisor redundancy/strategy source/test map.

All prior advisor runtime changes remain intact. This navigation grants no
experiment authority; activation waits for the user's normal restart.
'''
objective = ('Provide the user-requested 32x and 64x game-speed settings while preserving '
             'native event handling, current settings and existing advisor behavior.\n\n' +
             (EVAL / 'development335/economy_release/release_context/objective.md').read_text(encoding='utf-8'))
out = HERE / 'release_context'
assert not out.exists() and not (EVAL / 'ANIMATION_SPEED_339.md').exists()
out.mkdir()
write(out / 'context.json', json.dumps(context, indent=2) + '\n')
write(EVAL / 'ANIMATION_SPEED_339.md', component)
write(out / 'priorities.md', priority)
write(out / 'architecture.md', architecture)
write(out / 'objective.md', objective)
print(json.dumps({'context': ref(out / 'context.json'), 'speed_checks': int(checks[1])}))
