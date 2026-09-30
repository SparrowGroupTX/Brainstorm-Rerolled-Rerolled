# Phase copying draft for the next runtime slice

Owned draft files only; no runtime/test files or release records were edited.
Do not include this draft in an earlier slice's runtime freeze.

After root authorizes integration:

1. Copy `phase_copy.lua` to `Brainstorm/Advisor/phase_copy.lua`.
2. Copy `advisor_phase_copy.lua` to `tests/advisor_phase_copy.lua` and change its
   first dofile path to `Brainstorm/Advisor/phase_copy.lua`.
3. In `Brainstorm/Advisor/runtime.lua`, next to `A.ordering`, add:
   `A.phase_copy = module('phase_copy')`.
4. In `Brainstorm/Advisor/decision.lua`, immediately after
   `local result=run(snapshot,modules,yield_fn,options)` and BEFORE retry
   arbitration, add:

   ```lua
   if modules.phase_copy then
     result=modules.phase_copy.apply(snapshot,modules,result,options and options.phase_copy)
   end
   ```

   Its apply wrapper retains the prior decision independently, accounts for
   every added score, and uses the existing ordering/growth/strategy display
   fields. No runtime presenter change is needed. Shop prep can only replace
   an actual leave_shop action. Hand prep only replaces an ordinary play,
   discard or score-order suggestion with a certified held-card finish; it
   does not intercept consumable, boss-rescue or hand-order interventions.
5. Add the module to syntax navigation and any explicit deployment manifest.
   The checkpoint tooling freezes all Advisor Lua files automatically.
6. For a newly frozen source adapter, load BOTH `probe_policy_phase_copy` and
   `probe_policy_gold_stickers` into the modules table when their preloads are
   present. Existing `engine_run.lua` has neither. The pure `target_keys()`
   method supplies the identity registry; it does not capture player progress.
   Add the same optional load to `component_profile.lua` if relevant to future
   newly authorized components. All source files remain untouched by this draft.

## Complete comparison

The existing scoring order optimizer already compares ordinary plays with
Blueprint/Brainstorm, including Yorick's multiplicative scoring. This draft
adds phase timing rather than a fixed always-copy rule.

- Shop exit: bounded visible vanilla row, more exact Perkeo callback events,
  and higher whole-inventory value at unchanged cash/inventory. Includes
  Negative consumables, copying chains, and the immediate final-shop exit.
  No random copied identity is predicted. At most four copy events keeps the
  inventory comparison inside its existing exact nonlinear envelope.
- First discard: current row plus a legal Yorick scoring row are compared on
  the SAME up to three currently held subsets. The existing growth planner then
  evaluates its six bounded discard candidates in the Burnt arrangement, with
  exact scoring restored to the certified scoring row. No favorable draw is
  required. Both exact discard transitions must agree everywhere except the
  additional Burnt hand level after matching physical Joker order. This
  protects discard income, inventory, cash, population and Yorick growth.
- A new arrangement is an actual reorder_jokers action, never an imagined
  persistent state. Once arranged, fresh advice issues the discard instead of
  flipping straight back to scoring. Following the first discard, the normal
  order optimizer resumes. Snapshot fingerprints and Execute's existing
  stale/duplicate/pinned checks remain authoritative.
- Setup charges one or two extra arrangement actions in the existing
  uncalibrated growth-action utility units. The extra Burnt improvement must
  justify that overhead; final-blind growth remains disabled by existing policy.

Maximum added work is currently 18 score calls (six common-order/subset scores
plus the existing twelve-score growth limit; actual growth usually uses six).
The wrapper accepts at most 30 only as a forward bound and further restricts it
to the UNUSED part of the current 70 fast-clear / 140000 ordinary / 50000 shop
decision allowance. Insufficient budget does not start partial work. Shop
preparation uses zero score calls. It does not enlarge an earlier search cap.

The normal decision may already consume its separate existing specialist
allowances. This wrapper adds no work once the ordinary allowance is exhausted;
it does not retroactively change those existing searches.

## Validation and boundaries

`advisor_phase_copy.lua` uses synthetic public states and detached existing
scoring/decision modules. It verifies actual first-action progress, exact
retained scores, all 24 permutations of the four-Joker row, copying chains and
cycles, no repeated first-discard growth, source immutability, deterministic
output, remaining-budget cutoff, copied-discard-income refusal, negative pools,
final-shop copying, hidden/unknown/debuff/pinned/Dagger restrictions. No game
process, source component, captured replay, search, terminal attempt, player
profile, or save operation is performed. Two mistaken synthetic assertions and
their corrections are preserved in fixture_failure_01/02.txt.

This proves local mechanical/decision behavior. It does not establish a win,
win probability, complete source-adapter qualification or time-to-achievement
improvement. The retained-clear approach still cannot justify discarding the
only surviving hand merely to level it with Burnt.
