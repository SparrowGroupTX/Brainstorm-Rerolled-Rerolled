# Bounded reroll magnitude implementation — 2026-09-10

Runtime files: `Brainstorm/Advisor/catalog_joker.lua` and `paid_reroll.lua`.
The parent task owns snapshot/strategy/loader integration and installation;
consult its later release/checkpoint for installed status. This document does
not claim installation. Earlier selected evidence is in `ROI_EVIDENCE_247.md`.

`Catalog.create(entry,price,snapshot)` constructs a detached ordinary Joker from
source center metadata or returns `nil,reason`; `supports(entry)` is the cheap
eligibility check.57 deterministic-initial-state scoring keys are supported.
Random/stateful initializers remain unsupported. Catalog support is not a scoring
safety promise: actual build comparison must also support the result and boss.

Pool entries supply existing key/name/cost/rarity plus detached source_config,
source_set, source_effect, source_order and blueprint_compat. No ability is guessed
from a key. The constructor mirrors original Card:set_ability base fields,
including config.Xmult to ability.x_mult, observed creation-hand counters and
copied extras; quoted actual prospective price determines original resale value.

Set `paid_reroll.catalog=Catalog`. Existing three-argument suggest calls preserve
their behavior. Optional fourth-argument contract:

```lua
{compare=function(entry,price) return evidence,reason end, tactical_only=true,
 shortlist_limit=6, visible_evidence=actual_visible_purchase_evidence,
 visible_cost=actual_visible_purchase_cost}
```

Compare ORIGINAL current snapshot against the source-derived purchase after
BOTH reroll and purchase cash costs, using the shared comparison context. Return
`nil,'incomplete'` on budget truncation. An unsupported alternative returns nil
with another/no reason. All at most six shortlisted entries are considered; an
incomplete comparison invalidates the whole shortlist. Ranking uses positive
numeric assess return (Boolean remains accepted), then price and stable key.
Unassessed/unsupported entries keep their mass and earn zero improvement.
The post-visible-choice integration uses tactical_only=true so unsupported
tactical metadata cannot displace a choice through the older generic fallback.

Evidence requires four paired opening_scores, actual target/resources, supported
status and opening summaries. `opening_gain(evidence)` computes average target-
clipped paired opening gain as a target fraction. It does not multiply an opening
by future hands. Random scoring, malformed vectors or changed targets fail closed.

The tactical route requires sampled_deficit, or unresolved with at most one
clearing opening and mean below75% of target. This is a pressure heuristic, not
a failure probability. sampled_safe preserves cash. Full rows, missing metadata
and prospective shop-sticker rules retain the prior generic fallback scope.

Base-price affordability is credited only for source-derived no-edition mass:
`clamp(1-max(.003,.04*edition_rate),0,1)`. Normal create_card uses poll_edition's
default modifier1, and the negative branch remains.003 even at edition_rate0.
All premium-edition outcomes count as unknown/zero credit. Missing/invalid
edition_rate leaves this tactical model unsupported. No edition is promised.

Money uses actual bankrupt_at, cash, quoted prices and modifiers. Reserve all
observed next-blind paid-discards costs plus owned rental charges above the
actual purchase debt limit; no future income or sale is assumed. No new challenge
name exceptions are introduced. Generic fallback behavior remains unchanged.

Forecast reports every failed-refresh fee, expected checked-offer purchase spend,
covered/unknown pool mass, all shortlisted outcomes and target-clipped expected
gain. Approximate independent-offer chance is an upgrade opportunity estimate,
never win rate. Explicit heuristic guards require at least2% of target in covered
expected opening gain and10% better gain per expected cash dollar than an actual
supported visible alternative. These guards remain UNCALIBRATED; no versioned
coefficient was fitted/changed. Unknown visible evidence cannot be displaced.

Validation: tests/advisor_reroll_magnitude.lua passes24 checks; existing paid-
reroll49 checks pass unchanged. catalog_joker_source_parity.py/.lua runs original
Card:set_ability, Card:set_cost and poll_edition:57 Jokers/260 comparisons pass,
including original/inflated/discounted prices, deep-copy isolation, and edition
thresholds at rates0/1/2/4/25/30. Hidden independent DLL worker0.092s within15s.
`runs/roi247_catalog_editions_source/report.json` freezes module, fixture, harness,
workflow, runner, original source and runtime hashes. Earlier250-comparison
constructor-only artifact remains preserved at runs/roi247_catalog_source.

Root owns integrated decision tests and the coherent tested runtime slice.
No terminal win, latency gain or revised numerical win forecast follows.
