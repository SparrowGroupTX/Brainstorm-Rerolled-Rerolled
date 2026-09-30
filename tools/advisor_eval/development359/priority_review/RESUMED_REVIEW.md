# Independent resumed review of release 359

Reviewed on 2026-09-22 after the usage cutoff. No release-blocking runtime defect
was found in the inspected changes. This is a source review plus routine
manufactured regression evidence; root candidate, installed and final records
remain authoritative for deployment. No captured player-state policy/scorer
evaluation, original-source component, game control, save/profile read, seed
search, simulation batch or training was performed.

## Runtime findings

The Decision change resolves a real integration problem: on a known clear,
repeatable optional Empress development previously prevented the growth planner
from running. It now evaluates supported Yorick or first-discard Burnt growth
first and defers optional development only if that comparison returns a complete
discard action. A rejected growth candidate falls through to consumable
development; a Death-cycle play receives no discard-only priority. The cheap
inventory gate is not a legality proof. Growth still owns the retained-finish,
boss, resource, horizon, unknown-mechanics and population checks.

Growth is called once at most in this branch. All its work is charged before the
remaining consumable allowance is computed. Neither the ordinary 140000-score
nor fast-clear 70-score ceiling increases. The manufactured priority fixture
checks production actions, fresh observed refill behavior, no-discard fallback,
Burnt, inactive/expired Jokers, paid discards, final boss, forced-card hazard,
unchanged input and whole inventory, and shared allowances with zero to two
remaining score calls.

The copied Yorick change measures the marginal score of one physical X increment
using the exact existing visible Joker row and the same retained play. It does
not simply multiply the heuristic by the number of copies: intervening or later
additive Mult can attenuate the relative score change. The measured factor is
bounded between one and the resolved current scoring multiplicity, is explicitly
heuristic, and never assumes a later reorder. The resolver follows Blueprint
right and Brainstorm leftmost, detects cycles, ignores debuffed routes, and
requires explicit positive compatibility on each copy edge. This is stricter
than the general scorer's treatment of missing compatibility metadata.

Both endpoints must be finite, legal, exact and reliable. A supported random
floor cannot serve as the ratio baseline. Concealed, moving, unsupported,
noncanonical and soon-expiring rows earn no added credit. Each upgrade probe
costs one of the existing twelve growth score calls, while at least one call is
reserved for an actual retained-finish verification. The cloned hypothetical
ability changes only the physical Yorick's X value. Actual discard transitions,
countdowns, threshold increments, cash, deck population and whole consumable
inventory are unchanged. Copying Yorick does not multiply physical growth.

The same current-row factor is used for first- and second-discard partial utility
in the existing narrow two-discard proof. That proof only applies when the
selected first action misses the physical threshold, so its second partial
estimate begins with the same Yorick X and Joker row. The exact threshold bonus
remains physical. The proof still charges both actions and draws, preserves the
physical clear for the complete admitted neutral population, and dispatches only
the first action pending a fresh observation.

## Cutoff test failures and completed expectations

The cutoff's `growth_review/candidate01.json` is preserved. Its first failure was
the old assumption that a countdown of three always makes a future pair inferior
to a three-card immediate threshold. With the new copied-growth factor of two,
discarding two then three has merit 18.5942028985507; discarding three immediately
has merit 17.9565217391304. The selected two-card first action still misses the
threshold, and the second action gains exactly one physical increment.

`advisor_yorick_pair.cutoff.lua` preserves the test bytes before resumed edits.
The stale single rejection was replaced with explicit assertions for first two,
second three, five actual discarded/drawn cards, two action costs, one physical
X increase, countdown 21 and the independently calculated pair merit. The
existing independent 24-case subset/count oracle and all 720 complete draw-order
endpoints remain intact.

`growth_review/resumed_candidate02.json` is also preserved. It passed six of seven
fixtures, then exposed another stale heuristic rejection: an unused-discard
reward of three now costs 26 across both actions versus copied growth utility
28.9130434782609. The test now explicitly verifies the full positive accounting
at rewards one and three, and a reward of four still defeats this investment.
No cash, interest, reward or action-cost safeguard was removed. The separate
paid-discard rejection remains unchanged.

The subsequent `growth_review/resumed_candidate03.json` passes all seven
manufactured fixtures:

- Copied Yorick: 86 checks.
- Paired threshold: 18650 checks, 720 complete draw orders and 24 complete count families.
- Post-first Burnt inert pair: 48363 checks, 2160 complete draw orders and three physical Joker layouts.
- Weighted growth: 12 checks.
- Yorick retained margin: 108 checks, with four production decisions using 48 score evaluations.
- Existing growth: 56 checks.
- Known-clear discard priority: 118 checks.

No runtime file was changed by this resumed reviewer. The only fixture edits
were the explained paired-threshold expectation updates. Reviewed file SHA256:

| File | SHA256 |
| --- | --- |
| `Brainstorm/Advisor/decision.lua` | `e6f9302526894f38289527ffde95a5fc67a2435ab8c7d284293babfc4ab653da` |
| `Brainstorm/Advisor/growth.lua` | `d22f42a7e4b4c5c3631cdb6cdada63f4798fe4adbca87384bef73b2bf4e53ba0` |
| `tests/advisor_growth_copy359.lua` | `dfeb9d33ba660e28713e5fe728eb38051b6d2cfc2a7df4aed2398e440b9b0a4c` |
| `tests/advisor_growth_priority359.lua` | `5a78990cd08d2bb8e5ed713f8207d944836b7f36c6e71eb584a7a5d1930dcd03` |
| `tests/advisor_yorick_pair.lua` | `a6d1bf42679e97c4160aad95d749e5a434bebe0305c0e826605abb8b715dc432` |

## Limits

This does not prove that every unused discard is safe or beneficial, force five
cards at the expense of the retained clear, calibrate future win value, or repair
all joint hand/discard/consumable planning. The current copied-growth qualifier
intentionally admits only its narrow canonical row family; other supported game
Jokers can remain outside this extra credit. Tactical Empress use can still be
appropriate before a guaranteed clear exists. Mature/short-horizon growth,
valuable held resources, unsupported bosses or insufficient safe spare cards can
still cause a round to finish with discards unused. No rescued run or improvement
in terminal outcomes is established by this review.
