"""Bind the installed Acorn Lucky-card slice to preserved closed authority."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re

HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def write(p,text):
    with p.open('x',encoding='utf-8') as f:f.write(text)

candidate=EVAL/'runs/acorn340_candidate/validation/report.json'
r=read(candidate);integration=read(HERE/'integration.json')
assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
assert r['policy_digest']==integration['policy_digest']
for name,hashes in integration['changed_runtime'].items():assert ref(ROOT/name)['sha256']==hashes['after']
fixture=ROOT/integration['fixture']['path']
assert ref(fixture)['sha256']==integration['fixture']['sha256']
tests={key.replace('\\','/'):value for key,value in r['test_files'].items()}
assert tests[integration['fixture']['path']]==ref(fixture)['sha256']
check=re.search(r'advisor_acorn_lucky_340: (\d+) checks passed',(candidate.parent/'lua.log').read_text(encoding='utf-8'));assert check
prior=EVAL/'development339/release_final/context.json';value=read(prior)
assert value['release']==339 and value['status']=='CLOSED'
for key in ('release_validation','prepared_context_preserved','manufactured_work_counts'):value.pop(key,None)
value.update(release=340,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
 counts_scope='historical_closed_cycle',release_counts={key:0 for key in value['counts']},
 preparation_status='passed_candidate_exact_installed_validation_bound_separately',
 summary='Repair the observed Amber Acorn stop caused by a visible Lucky card. The existing complete public Joker-world planner now uses one supported random-score-floor pass for every subset/world when a Lucky card is present. The ordinary score cap, complete comparisons, hidden-identity exclusion and public reorder proof remain intact. Advice labels its random-floor scope, and existing invalid public-belief reasons reach the user instead of a generic missing-belief message.',
 outcome_summary=f'Read-only passive logs from loaded 2.138 show the original stop at sequence 4554 after decision 4547 rejected a Lucky Jack with a valid five-Joker/120-world belief. No captured policy was replayed. The manufactured Lucky fixture passes {check[1]} checks, including complete subsets/worlds, precise floor-call accounting, no mean or RNG fallback, inventory/resource preservation, reliable-bound requirements and a false-clear case whose floor is 112 while its expected score is 304 against 200. An independently manufactured five-Joker/eight-card case covers all 26,160 current-order comparisons inside the unchanged 140,000 cap. The component tests do not demonstrate that the logged run is rescued or that Amber Acorn is generally solved. Historical closed loss328 results remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331.',
 limits_summary='The change admits supported Lucky scoring only; unknown/hidden/destructible/held-reward card scopes, incomplete world families and unsupported ability changes remain explicit. It does not forecast Lucky outcomes, future hands/discards/uses or a complete blind win. All scoring inputs are detached public worlds, not hidden slot payloads. A later recorded uncertified manual drag and a checkpoint reload lacking pre-concealment inventory are separate limitations. A restart or restoration already inside Acorn cannot recreate public memory; use a checkpoint before selecting the blind so the advisor can observe the visible Joker inventory. No inferred movement origin, hidden-ID join, or saved-state equivalence is invented. Current settings, logs, native dependencies and all dirty/untracked work remain preserved; activation waits for the user normal restart.',
 budget_summary='All experiment allowances remain CLOSED. Release 340 performs read-only passive log/source analysis and routine manufactured fixture/regression validation only, with 60-second per-suite caps. Zero source components, captured-state policy replays, searches or complete attempts are started; no executable archive, player save/profile is read and no game is controlled. Historical loss328 counts/outcomes and 1,200 seconds reserved/685.3740000000689 seconds actual remain unchanged; unused P05/P06 and 60 seconds stay closed. No worker, source attempt, search or scheduled continuation is pending.')
value['diagnostic_evidence']={name:ref(path) for name,path in {
 'previous_checkpoint':prior,'integration':HERE/'integration.json','passive_log_analysis':HERE/'passive_log_analysis.json',
 'preserved_hash_scope_assertion':HERE/'log_hash_preflight_error.json',
 'initial_fixture_receipt':HERE/'lucky_component/validation_attempt_01.json',
 'final_fixture_receipt':HERE/'lucky_component/validation_attempt_02.json',
 'manufactured_fixture':fixture,'candidate_validation':candidate,'before_manifest':HERE/'before.json'}.items()}
value['manufactured_work_counts']={'release':340,'checks':int(check[1]),'five_joker_eight_card_current_order_scores':26160,
 'scope':'manufactured_inputs_only','captured_state_policy_replays':0,'live_rescue_verified':False}
component=f'''# Amber Acorn Lucky-card score floor - 340

Passive log decision 4547 (2026-09-15 23:58:25UTC, loaded 2.138) has a complete,
supported, state-valid public belief: five Jokers,120 possible orders, eight
visible cards, including one Lucky Jack. A blanket playing-card guard rejected
the hand. Sequence4554 stopped auto-run 30 seconds later with unsupported_stalled,
four hands, three discards and 0/400,000 chips. Exact closed-segment and stored-frame
hashes are in `development340/passive_log_analysis.json`. This is read-only
diagnosis, not a captured-policy replay or terminal counterfactual.

`acorn_ordering.lua` admits Lucky by requiring `scoring.lower_bound` for every
candidate/world, including subsets that leave the Lucky card held. Each legal
result needs a reliable finite supported floor, no uncertainty and no warnings.
Explicit illegality excludes that fixed action across worlds while all remaining
comparisons continue. One floor pass is charged once; no preceding average pass
or private outcome sampling is used. Complete family preflight and 140,000 ordinary
/30,000 order caps stay unchanged. Non-Lucky hands retain their existing scorer.

`decision.lua` charges floor calls through the shared budget, labels the
supported-random-floor scope and preserves the existing conservative public
world-floor proof. Exact-looking average Lucky triggers cannot certify a clear.
It also surfaces an existing explicit invalid-belief reason when available.

`tests/advisor_acorn_lucky.lua` passes {check[1]} manufactured checks: complete
world/subset counts, poisoned hidden payloads, no RNG/mean fallback, false-clear
prevention, complete robust reorder, fresh post-reorder advice, current row
resource/inventory preservation, unknown/unreliable bounds and unchanged
unsupported guards. The eight-card/five-Joker case covers 26,160 real floor calls.
Prior focused 310-check evidence remains preserved in the component directory.
Full candidate/exact-installed reports are under `runs/acorn340_candidate`,
`runs/acorn340_installed`, `runs/acorn340_installed_validation` and
`runs/acorn340_final`; final records own exact hashes, counts and installation.

Later passive events show supported belief after the first manual play, then an
uncertified Joker drag and a reload without public pre-concealment inventory.
Read-only source review does not establish an update race: ordinary controller
drag dispatch precedes advisor update. No uncertified movement or hidden identity
is recovered. A restart already inside the blind has no observed pre-shuffle
inventory; continue from before blind selection to establish public memory.
The separate Glass/population, Blue/Gold reward, larger world-family and unknown
ability-transition limits remain. No full blind continuation or rescued run is
claimed. All experiment allowances stay closed; current logs, settings and native
files are preserved, and tools leave the running game undisturbed.
'''
priority='''# Priorities after 340

The logged Lucky-card Acorn stop is repaired. Activation and live confirmation
await the user's normal restart with public pre-shuffle inventory observed.
Keep uncertified drags, hidden-inventory reloads and unqualified transitions
explicit; never recover concealed identities through physical IDs or saves.

Remaining Acorn scope includes complete resource comparisons for Glass and
held rewards, larger public-world families without higher budgets, broader
qualified ability transitions and publicly certified movement observations.
Use specific passive evidence to prioritize these; do not remove guards just
to produce an action. No captured replay/source/search/attempt allowance renews.

Prior performance/speed work remains installed. The broader strategy backlog
in NEXT_PRIORITIES_338.md and source navigation in ARCHITECTURE_MAP_338.md remain
current for their scopes. Jokerless, Knife's Edge, twenty challenges and Gold
stickers are unfinished; no win odds or stronger-than-human result is established.
'''
architecture='''# Acorn repair navigation - 340

- Advisor/acorn_ordering.lua: complete common-world immediate play/reorder;
  supported random floor for Lucky, unchanged family/budget/resource bounds.
- Advisor/decision.lua: public hidden-row interception, shared score accounting,
  conservative proof labels and explicit invalid-belief reasons.
- tests/advisor_acorn_lucky.lua: manufactured floor/reorder/budget regressions.
- tests/advisor_acorn_belief.lua and tests/advisor_acorn_public.lua: preserved
  belief/public-effect, movement and runtime/execution guard fixtures.
- Advisor/acorn_belief.lua, acorn_public.lua and acorn_public_hooks.lua: unchanged
  public inventory memory, effect observation and physical-slot inference.
- development340/passive_log_analysis.json and ANIMATION_SPEED_339.md: current
  bug evidence and preserved speed change. ACORN component note: ACORN_LUCKY_340.md.
- ARCHITECTURE_MAP_338.md: prior scoring/inventory/logging/economy source/test map.

This navigation grants no experiment authority. Preserve full public-world
comparisons and hidden-identity safeguards. Live activation remains unconfirmed.
'''
objective='Repair the observed Amber Acorn auto-run stop through complete public scoring support, preserving hidden-information, resource and execution guards.\n\n'+(EVAL/'development339/release_context/objective.md').read_text(encoding='utf-8')
out=HERE/'release_context';assert not out.exists() and not (EVAL/'ACORN_LUCKY_340.md').exists();out.mkdir()
write(out/'context.json',json.dumps(value,indent=2)+'\n');write(EVAL/'ACORN_LUCKY_340.md',component)
write(out/'priorities.md',priority);write(out/'architecture.md',architecture);write(out/'objective.md',objective)
print(json.dumps(ref(out/'context.json')))
