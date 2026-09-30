# Midrun scaling audit and replacement comparison repair

This component only reads the root's redacted public trace and repository source.
It runs manufactured Lua fixtures, never a captured policy decision, original game
source, seed search, complete attempt, save or live game action. Historical
experiment authority remains closed.

## Public observations

The selected run 4 started at event 2767 and lost event 3388, Ante 5 Big Blind,
18,340 / 37,500 chips with $45. No counterfactual run was executed.

At event **3282**, before Ante 5 Small, the actual visible shop offered an Eternal,
nonrental, nonperishable **Blueprint for $10**. Cash was **$52** and the held row
was Yorick (X4), Perkeo, Sly Joker, Greedy Joker and a rental/perishable Trio.
Every held Joker was non-Eternal. The chosen action was leave_shop; its advice
explicitly reports that the shop scoring comparison reached its limit and fell
back to strategic ratings. This was an encountered, affordable copy offer, not an
unfulfilled search promise. It does not establish that any resulting run wins.

Perkeo did acquire a Venus source (2940) and produce copies on subsequent shop
exits. Three were used at 3171, 3176 and 3182; 3OAK rose to level 4. At 3344,
nine Venus plus one Hermit were still held while 3OAK remained level 4. On the
terminal blind the observed hands did not make 3OAK, so merely consuming Venus
cannot be claimed to rescue that observed terminal sequence. No forced named-hand
rule is proposed. This is a future owned-consumable/draw-planning integration
question, not evidence that Perkeo did nothing.

## Concrete source defect

`replacement_sale_plan` asks `best_shop_purchase` to choose an offered card after
each prospective sale. That helper scored the artificially vacant row against
the resulting bought row. The outer planner then separately scored the actual
original row against that exact bought row. The intermediate vacant row is never
the completed recommendation but cost a full opening and finishing profile.

`strategy_candidate.lua` threads the actual original row into those replacement
offer comparisons, while the sold state still supplies affordability, purchase
price, resource effects and the real paid endpoint. Every admitted victim/offer
remains considered. It reuses the resulting evidence and adjusted scoring delta
in the outer planner; the candidate's utility is not added again. Generic pack
replacement callers without that baseline flag retain their existing full-row
comparison. Shop cap, complete-family fallback and survival veto stay unchanged.

## Manufactured validation

- New fixture: 96 checks including all four legal victims × both visible copy
  offers, complete original-row baselines, actual sale funding, an unfunded offer,
  real deterministic scoring, untouched input, four common worlds, unchanged
  50,000 maximum and whole-decision fallback with an insufficient cap.
- Ten existing relevant fixtures pass through a detached strategy substitution:
  strategy, shop decisions, shop survival, shop copy, shop sequences, shop
  finishing, owned Fool shop, Perkeo inventory, growth and economy.
- A finite manufactured 52-card / 8-card-hand example uses **28,302 → 20,172**
  score calls, with **9 → 5** completed profiles and unchanged action. This
  example intentionally gives Perkeo an empty inventory; it is not a reproduction
  of the user's full captured state and does not evaluate the observed Blueprint
  refusal.
- At a lower **25,000** requested cap, the baseline truncates after 21,716 calls;
  candidate completes at 20,172. The baseline's transient partial recommendation
  would be discarded by the existing decision wrapper; the new fixture verifies
  that fallback explicitly with a one-call cap. The ordinary hard cap is 50,000.
- Nine-card-hand diagnostic: 45,720 → 33,528 opening calls. The ordinary finishing
  module declines that larger hand, so these numbers are not complete blind
  survival evidence.

The first new fixture attempt failed because the test mistakenly expected sale
advice to export a top-level `scoring_evidence` field. Existing sale advice only
prints it. The corrected fixture captures the actual context's evidence for the
selected victim; no runtime behavior was altered to satisfy that expectation.

## Integration

Do not overwrite root strategy wholesale: another component changes its
replacement inventory valuation. Apply `strategy.patch` against the corresponding
unchanged functions, and stage the new fixture as
`tests/advisor_shop_replacement_baseline.lua`, replacing its first strategy path
with `Brainstorm/Advisor/strategy.lua`. Run the combined candidate and exact
installed regressions before release. No installation was done by this agent.
