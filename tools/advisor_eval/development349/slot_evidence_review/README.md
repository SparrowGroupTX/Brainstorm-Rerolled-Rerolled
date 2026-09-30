# Reusing existing evidence for an already-Gold Eternal exception

Read-only review of checkpoint 2.148 product source. No runtime edit, captured
policy evaluation, original-source execution, search, complete attempt, game
control, save/profile access, or current-settings write was performed.

## Recommendation

An Eternal-slot guard can admit a narrow, supported next-blind improvement using
each candidate's **already computed** `scoring_evidence`. The guard itself should
perform zero score calls. It should not give new credit for heuristic score,
ratio, `timely_scoring`, average chips, or `readiness.status` alone. A failed
exception leaves the ordinary slot protection active; it does not manufacture
an alternative scoring policy or relax unknown mechanics.

Concrete API proposal:

```lua
-- Called only after a candidate's exact after-state and ordinary comparison
-- already exist. This pure function never constructs a new scoring context.
local receipt, reason = gold_slots.opening_exception(
    original, after, candidate, evidence,
    {context = original._shop_scoring,
     gold_goal = Strategy.gold_goal,
     gold_perkeo = Strategy.gold_perkeo,
     gold_tarot_hold = Strategy.gold_tarot_hold,
     bell_opening = Strategy.bell_opening})
```

The caller's classification decides whether the offer is already Gold, Eternal,
non-Negative, and consumes flexibility. The proof function should return either
a bounded scalar receipt or `nil, reason`; it should not give the Joker a new
strategic score. Unknown collection progress remains unknown, rather than being
treated as already Gold or missing.

Recommended receipt fields are `schema`, `supported`, `kind`, `family_key`,
`samples=4`, `target`, `before_min`, `after_min`, `minimum_delta`,
`baseline_short_worlds`, `required_margin=1.25`, `additional_score_calls=0`, and
`terminal_evidence=false`. Do not include projected states or entire evidence
copies in logging.

## Validation contract

1. Require the exact candidate transition to be legal, affordable and already
   qualified by its normal cash/capacity/resource checks. The `original` input is
   the full owned row before any proposed sale. The `after` input is the complete
   paid or free-choice endpoint, including actual sale proceeds, purchase costs,
   resource changes, exact append/remove positions and Negative slot effects.
   A sale-vacated preview cannot be used as the holding baseline.
2. Require the original comparison context to exist and not be truncated. Use
   this immediate candidate's evidence; the current evidence format does not
   contain a complete hash binding to its after-state, so it must not be reused
   for a different endpoint or cached only by Joker key.
3. Reuse `gold_goal.validate_inventory_opening(evidence, target, boss, bell)`
   (`gold_goal.lua:137`, exported at 381). It validates the four world IDs,
   common-world schema, readiness targets and four opening scores, no incomplete
   or uncertain result, no speculative temporal scenario, no startup receipt,
   and the fixed-layout ordering contract. Also require a nonempty family key,
   exact known next-blind key/target match, and no neutral-boss fallback.
4. Require at least one baseline opening below the actual target and every
   purchase opening at or above `1.25 * target`. This implies a positive minimum
   change in the deficient world but is **not proof that holding loses the
   round**. A more conservative gate may require all four baseline openings to
   be below target. Avoid naming this a win or guaranteed survival rescue.
5. If an already-computed complete, supported, known-mechanics baseline finishing
   policy clears all four common worlds, do not call the extra Eternal necessary
   for survival merely because holding needs multiple hands. Validate the
   finishing receipt's completeness, sample count, selected policy and clearing
   count before using that veto. Do not run another forecast to obtain it.
6. The narrow initial scope can additionally require both ordering receipts to
   have zero action count and identity permutations. If a projected first-hand
   reorder is allowed instead, it remains a real future action requiring fresh
   delivery; it must not be described as the current physical row or a free
   action. Unsupported pins/hidden copy routing cannot justify an exception.

`Shop.new` used by ordinary Strategy receives `modules.scoring` directly
(`decision.lua:154–156`). Its comparisons use `Score.score`, not `lower_bound`.
However every scoring warning sets `uncertain=true`, even if warning text is
suppressed (`scoring.lua:215–219`), and the profile accumulates uncertainty over
all evaluated selections (`shop_scoring.lua:786`). Thus the existing validator's
strict `e.uncertain == false` admits deterministic exact opening scores only.
Do not relabel generic ordinary evidence as `supported_random_floor`. Random
mean scores remain ineligible even when a high mean happens to exceed 125%.
Obtaining fresh random-score floors would be additional score work and needs a
separately charged, complete family; it is outside this zero-work proposal.

## Inventory and startup boundary

The generic Shop scorer does not project an arbitrary Perkeo shop-exit copying
pool. For an exception, require no Perkeo in either endpoint, or exact empty
inventory and known settled capacity/buffer in both, or the existing qualified
whole-inventory held-Tarot certificate for **both** shop endpoints.
`gold_tarot_hold.certify` is explicitly shop-only (`gold_tarot_hold.lua:270–277`),
limited to qualified Tarot identities and current row, original inventory held
unused, no value from generated cards, and no generated Observatory multiplier.
Do not silently convert a pack snapshot's phase to shop to bypass its boundary.
Nonempty Perkeo pack copying pools and mixed/unknown inventory remain outside
this first exception unless an explicit already-supported projection applies.

Cartomancer has an exact no-op startup test only when inventory is known full,
buffer is zero, and identity/copy metadata match (`gold_goal.lua:54–71`). Generic
Shop enables that exception only in its `current_order_opening_only` context
(`shop_scoring.lua:515`). Ordinary Strategy does not use that context. Therefore
ordinary Cartomancer comparisons may remain unavailable even for a full pool;
free-slot/random Cartomancer certainly must not receive a heuristic exception.
No new context or generator simulation should be created merely to admit the
Eternal. Deterministic or random startup evidence is also excluded by the reused
opening validator; Chicot target-changing and other unsupported effects stay
explicitly outside this narrow first scope.

Crimson Heart and Amber Acorn are absent from Shop's supported next-blind table
(`shop_scoring.lua:326–340`); neutral fallback is not proof about those bosses.
Concealed opening mechanics can yield unsupported readiness. Bell requires its
existing full first-forced-card comparison; do not accept an ordinary unforced
sample in its place. Gold-purchase resource/survival safeguards remain in force.

## Integration paths that must not bypass the guard

- Direct shop offer candidates: `strategy.lua:1056–1087` already have exact
  after-state and `scoring_evidence` available before candidate selection.
- Direct free pack choices: `strategy.lua:1923–1985` compute the complete Joker
  endpoint comparison with no purchase cash. The same rule belongs here.
- Shop sale/replacement: `strategy.lua:1283–1297` reuses the exact original-row
  endpoint evidence. Preserve that reuse and original baseline.
- Full-row Buffoon replacement: `strategy.lua:2035–2080` compares original row to
  sale-plus-choice; guard it before it can become the chosen replacement.
- Visible shop sequences: `shop_sequences.lua:399–442` compare the original root
  with each complete node. A guarded direct candidate alone is insufficient;
  this graph can otherwise select the same blocked Eternal through another
  first action. Track actual newly acquired physical cards in the node; apply
  the endpoint rule after its existing evidence is complete, without inventing
  credit for a temporary weak or empty intermediate row.
- Tactical failure fallback: `decision.lua:186–202` calls `advise(nil)` when the
  shared context truncates or a pack family is incomplete. With no evidence the
  slot protection must remain active. An unavailable proof must not fall back to
  the generic high rating that the guard was intended to constrain.

Existing score budgets and whole-family fallback stay unchanged. A candidate
rejected solely for objective/slot protection should remain explicitly recorded
as considered-but-blocked, not make a complete comparison appear incomplete.
Actual missing or Negative Joker exceptions are separate from this already-Gold
Eternal survival test. This test does not compare every future run opportunity,
calibrate win odds, or prove that an Eternal is globally optimal.
