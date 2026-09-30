# Complete replacement comparisons and retained copying inventory

Slice 329 / 2.129.0-alpha repairs two shop-planning integration failures identified
while reviewing the selected public losses. The `shop329` candidate, installed
and exact-installed records own final validation, deployment and hash facts.
Neither installation nor these manufactured tests establish that an observed
loss is rescued. Live activation waits for the user's normal restart.

## What the public record establishes

Run 4 event **3282**, before Ante 5 Small, offered **Blueprint for $10** while the
player held **$52**. Blueprint was Eternal, nonperishable and nonrental. The held
row was Yorick at X4, Perkeo, Sly Joker, Greedy Joker and a perishable/rental Trio;
none of those owned Jokers was Eternal. The advisor left the shop and explicitly
reported a scoring-limit fallback. This was a visible affordable copy offer,
not an unfulfilled prediction from seed search. The run subsequently lost Ante 5
Big at **18,340 / 37,500** with **$45**. No particular replacement or complete
counterfactual run has yet been shown to save it.

Run 5 event **3829**, after Ante 4 Small, instead sold **Perkeo for $10** with
**$3** available to fund the visible **$10 Blueprint**. One ordinary Mercury and
one Negative Mercury were still held. The recorded plan credited the new scoring
copy while its generic retained-Joker valuation omitted the future copying value
of that actual inventory. Selling Perkeo was affordable and legal; its long-term
opportunity cost still needed inclusion. That run later lost final Amber Acorn
at **98,808 / 400,000**. Its incidental `won_field=true` does not override the
GAME_OVER state, unmet threshold and loss receipt. Keeping Perkeo is not itself
a demonstrated rescue, and an otherwise necessary survival sale remains allowed.

These facts come from `development328/public_trace/run4.json` and `run5.json`,
derived only from redacted public snapshots and recorded advice/action/time
metadata. No raw internal fingerprint text was used to infer concealed state.
Original logs and exact captured copies remain unchanged.

## Runtime changes

`Brainstorm/Advisor/strategy.lua` now threads the actual original owned row into
generic shop replacement-offer comparisons. The prospective sold state still
funds the purchase, supplies its exact cash/slot effects and constructs the paid
endpoint. It no longer becomes an artificial vacant-slot scoring baseline. The
outer replacement planner reuses that complete original-to-endpoint evidence
and its adjusted scoring delta, so neither the scoring call nor the rating is
counted twice. Every admitted legal victim/offer remains considered. Pack callers
without this shop baseline flag keep their existing full-row comparison.

The same module also includes the existing whole-inventory valuation in the
before/after utility of generic shop, revealed pack and supported catalog Joker
replacements. That accounts for ordinary and Negative consumables, active Perkeo
copy sources/chains and the existing nonlinear Observatory utility. It does not
ban selling Perkeo, require a named Joker setup, alter the random copy pool or
claim a win probability. `shop_sequence_api.build_value` remains Joker-only:
`shop_sequences.lua` already adds inventory separately. The combined
`replacement_value` helper is separate, preventing duplicated inventory credit.
Special Egg/Omelette policies stay unchanged.

These changes preserve the **50,000 shop** cap and the existing complete-family
fallback. Original **140,000 ordinary**, **25,000 consumable** and **70-score fast
clear** limits are unchanged, as are deterministic sampling, paired worlds,
affordability, legal sales, population/Glass, inventory/capacity, survival vetoes
and retry/session protections. An incomplete family still cannot publish a
partial tactical winner.

## Manufactured evidence and its limits

The replacement-baseline fixture checks all four admitted legal victims against
both visible copy offers, original-row identity, actual sale funding, refusal of
unfunded endpoints, preserved input, deterministic scoring, complete four-world
policies and whole-decision fallback. Its detached version passed **96 checks**,
plus ten existing relevant fixtures. A finite manufactured 52-card/8-card-hand
example drops **28,302 to 20,172 score calls**, **9 to 5 completed profiles** and
**8 to 4 paired requests**, with the same action. At a lower **25,000** supplied
cap, baseline truncates after 21,716 calls while candidate completes at 20,172.
This example intentionally has an empty Perkeo inventory; it is not a captured
player-state replay or proof that the observed Blueprint decision now completes.
The nine-card diagnostic concerns opening profiles only because ordinary
finishing declines that larger hand; it supplies no full-blind survival result.

The inventory fixture passed **25 checks**, plus eight relevant existing fixtures.
In a generic full three-Joker row, a known Blueprint and insufficient cash can
still justify selling empty Perkeo. Giving that same row ordinary plus Negative
Mercury preserves the actual source in the constructed case, including the pack
endpoint. At the manufactured level-4 Pair, removing sole Perkeo loses exactly
two future copy utilities, each `8 + 65*(15/55 + 1/5)`, while retaining both
original Planets. Two matching Planets with Observatory lose another **67.5**
prospective held utility, while existing held utility remains **30**. Mixed pools
and removal of copying Jokers are covered. These are existing utility units,
not chips, win rates or demonstrated terminal benefit.

Full integrated candidate and exact-installed counts belong to generated release
records. Detached fixture-authoring failures are retained in the component
notes/receipts; none is relabeled as a source experiment or successful regression.

## Navigation and remaining work

| Area | Source/test/evidence map |
| --- | --- |
| Original-row replacement scoring | `strategy.lua`; `tests/advisor_shop_replacement_baseline.lua`; `development328/scaling_component/strategy.patch`, `manifest.json`, `README.md` |
| Retained copying inventory | `strategy.lua`; `tests/advisor_replacement_inventory.lua`; `development328/inventory_component/strategy.patch`, `manifest.json`, `README.md` |
| Existing paid endpoints and scoring | Unchanged `shop_scoring.lua`, `shop_sequences.lua`, `liquidity.lua`; shop decisions/survival/copy/sequence fixtures |
| Existing inventory mechanics | Unchanged `inventory_value` model and Perkeo/Observatory/Negative handling; inventory/timing/Planet fixtures |
| Public postmortems | `development328/public_trace/run4.json`, `run5.json` and their referenced redacted snapshots |
| Fresh validation authority | `runs/loss328_validation_20260915/authority.json`, `status_initial.json`; prospective job registrations own later execution facts |
| Final runtime evidence | `runs/shop329_candidate/validation/report.json`, `shop329_installed/record.json`, `shop329_installed_validation/report.json`, `shop329_final/final_verification.json` |

Amber Acorn hidden-order information fairness remains a separate unresolved gap.
Public run 5 events4355–4387 show face-down Jokers without reveals, while advice
quotes scores derived from the internal row. `concealed_belief.lua` currently
detects concealed playing cards, `decision.lua` otherwise proceeds to ordinary
search, and `scoring.lua` does not reject a concealed Joker row. `ordering.lua`
does refuse an Acorn reorder, but that alone does not establish a public scoring
belief. The separate validation adapter must stop both baseline and candidate
at the same unsupported concealed-Joker boundary until a qualified public-order
model exists. This release does not implement that belief comparison, reveal
learning or an Acorn rescue.

Midrun mixed-inventory Planet preparation also remains separate. Run 4 acquired
Venus and Perkeo did generate copies; three were used when a real 3OAK appeared,
raising it to level 4. At event 3344, nine Venus plus Hermit remained held. The
generic printed Planet tip is not an executable midrun preparation policy with
Jokers, and the final-only homogeneous-Planet path does not apply there. The
terminal hands did not make 3OAK, so consuming Venus alone cannot be described as
saving that sequence. A useful follow-up requires a complete owned-use/draw
comparison preserving cash, copying pools, Observatory and actual action cost.

The separate loss328 validation batch is **ACTIVE with zero registered or executed
jobs at this prepared snapshot**, using its already-authorized limit of six
30-second detached comparisons and six 180-second complete attempts: **1,260
seconds total**. This component consumes no experiment job. Root must freeze and
register exact policy/adapter/profile/source/runtime provenance and one-use limits
before execution. No search or other source component is authorized. Every older
cycle remains CLOSED; no unused historical quota is restored. Preserve current
settings, native DLLs, saves, logs and all previous failed/unsupported/censored
evidence. No live game control, save evaluation, commits, resets, cleaning or
scheduled continuation is part of this slice.
