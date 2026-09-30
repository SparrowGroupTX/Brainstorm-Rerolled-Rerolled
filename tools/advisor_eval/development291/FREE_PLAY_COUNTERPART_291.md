# Free first-play counterpart — 291

## Observed comparison gap

The completed, selected-development C4 attempt under frozen289 used Justice at
step36 without an incumbent consumable hint. Its modeled immediate play after
the use selected cards 1,2,3,4, while the unchanged-inventory first actions only
offered play 2,3,4,5,8 and play 1,6,7. The use branch therefore had exclusive
access to a different first-play selection and its resulting cleanup/draw
schedule. This confounds the modeled value of using Justice with an omitted
free alternative. The original run lost Ante2 Flint with 748/1600 chips.

This identifies incomplete comparison coverage, not a proven harmful use.
The free counterfactual has not been rescored on that captured state or run in
the original source. Retaining Justice can change scoring, Glass destruction,
Lucky outcomes, inventory capacity, later targeting and draws. The two branches
must receive their own transitions rather than being declared equivalent.

Exact recorded evidence remains in
`runs/diagnostic287_20260913_222344/C4_postmortem/MANUAL_POSTMORTEM.md` and its JSON
companion. All source/captured/search/attempt allowances from that cycle are
spent. This slice uses routine synthetic fixtures only.

## Runtime change

Before any sampled world is shuffled or drawn, project the exact first owned
use and obtain its immediate supported structural best play on the public
projected hand. Map that play's physical card IDs back to the unchanged root
hand. Preserve order, including after Hanged Man removes cards and shifts
indices. Reclassify and score the mapped free play with the original cards,
inventory, blind restrictions and forced selection. Never infer its score from
the post-use score.

Add that free play when it differs from the already declared free plays. Keep
the exact incumbent use, original play, original discard and legal play of the
discard selection. Every first action crosses the existing five discard
schedules, both hold/observed-use schedules and all four common worlds. The
maximum becomes five first actions and 50 plans. The existing 12,000 score and
150,000 classification limits are unchanged; a larger family may therefore
reach a limit more often and decline the override.

Unsupported projection, missing or reordered identities, unsupported scoring,
or exhausted shared budgets abort the entire declared comparison. A known
illegal original forced/boss selection, or complete structural enumeration
proving no immediate legal post-use play, records `counterpart_declined` and
retains the original full legal first-action family. A legal use can itself
rescue a restricted category or remove a forced card; this does not establish
a legal free control. No partially evaluated alternative is selected.
The 274 discard guard, owned-use common-world nonregression guard, minimum
uplift, reliable-finish priority and compound-use exclusions are unchanged.

The diagnostic `free_play_counterpart`, when a legal free control exists, records the physical IDs, mapped and
post-use indices, use key, original score/category, and whether a new action
was added. Added plans are marked `free_use_counterpart`.

## Synthetic validation and limits

`development291/focused3/report.json` binds the staged files and records both
fixtures passing in 4.540774799999781 seconds: 326 checks in the new counterpart
fixture and 1060 in the extended joint-consumable fixture. The latter's complete
real-mechanics comparison uses 1866 scores and 89525 classifications, below the
unchanged shared limits. The controlled outcome fixture makes
all old free first actions fail, while both the use first and its previously
omitted free play clear. The extended complete family chooses the free play
with zero uses, and all ten corresponding schedules retain the same owned
Justice identity. Actual card classification, scoring, exact consumable
application and state transitions remain active; only the threshold outcome is
controlled to isolate comparison coverage. This is not a source run or win-rate
estimate.

Additional checks cover physical identity after Hanged Man removal, original
forced selection, Psychic legality, unsupported scoring/identity, duplicate
first-play suppression, invariant input state and hidden deck order, and both
shared budgets. The older joint-consumable fixture asserts all first actions
times ten and the new 50-plan maximum. The Eye/Moon category rescue, removal of
a forced card, and no immediate Psychic play retain all original legal plans
without asserting a free control.

The earlier `development291/focused1` passing 320-check receipt is preserved.
`focused2` failed because the new synthetic forced-card fixture supplied an
incumbent discard that illegally omitted its forced card. `focused3` corrected
the fixture to include that card; no runtime guard was removed to obtain a
pass. These are routine fixture results, not source or captured attempts.

The new action is one immediate structural-best free counterpart, not every
possible free play or post-use conditional discard. An existing use baseline
can still remain selected when the free play has equal modeled clear rate,
because minimum uplift is intentionally preserved. There is no newly measured
terminal benefit, human comparison, population win rate or confidence interval.

## Release integration

After 290's exact installed validation completed, the reviewed runtime was
applied to `Brainstorm/Advisor/resource_finish.lua`. The new fixture is
`tests/advisor_resource_free_counterpart.lua`; its baseline comparison copy is
preserved at `tests/support/resource_finish_289.lua`, with recursive frozen test
inventory required to bind those support bytes. The existing
`tests/advisor_resource_consumables.lua` now asserts the complete extended
family. Staged originals and all earlier receipts remain preserved.

The runtime hash is
`f885b7ba1b46871bc3bd2d91b73d5755353895c66c9dc719ffe8fac406827042`.
The baseline support hash remains
`cf8960e9ecff022fd02b862507ab5e434c333a5ed369eaba272d7126f5dee74f`.
Final candidate and exact-installed validations and the release ledger are
owned by the root; focused evidence alone is not installation validation.
