# Owned Fool shop comparison — 290

This runtime slice adds an exact ordinary owned-Fool copy transition to the
existing bounded shop sequence comparison. A known previous Planet for the
actually played main hand can be copied into inventory and then used in a
separate action. Holding the original Fool and retaining the generated Planet
are explicit endpoints. The policy compares their existing build, inventory,
cash, liquidity, action and paired scoring values; it does not force the copy.
Future Fool option value remains the existing heuristic, not a calibrated
estimate of run success.

## Observed development gap

The read-only C3 postmortem is under
`runs/diagnostic287_20260913_222344/C3_postmortem/`, with exact snapshot/result/
decision files and extraction line/hash links. Frozen 289 bought Fool for $3
at step 77 after using Empress at 76, and retained it through the terminal
Ante 4 Big loss: 4,379/7,500 chips. At step 85 Fool and Saturn occupied both
slots. Pack Saturn at 86 and owned Saturn at 87 left the ordinary Fool in one
of two slots, with previous identity Saturn. At shop 88 the actually played
Straight was level 8. Shop 94/96 again had known previous Saturn and the held
Fool; pack Saturn at 95 raised Straight to level 9. The later Death use at 98
changed the previous identity before the final blind, outside this new scope.

These records show a missing known copy/use comparison. They do not establish
that using Fool was the best choice, that any failure was caused by holding it,
or that the copy would rescue C3. No captured-state rescoring, source component,
search or complete attempt was run for 290. All 14 jobs in the preceding
diagnostic cycle are closed; 290 has no terminal validation.

## Exact transition and scope

`Brainstorm/Advisor/pack_scoring.lua` exports `owned_fool_candidate` and
`project_owned_fool`, sharing the existing pack-Fool catalog creation helper.
The source mechanics and hashes are preserved in `FOOL_PACK_278.md` and
`runs/fool276_focus4/source_review.txt` / `.json`; no executable or save was read
again. Source Fool creates the forced previous identity as a fresh ordinary
held card, and does not immediately apply its effect. This implementation
removes the owned ordinary Fool and creates that card, preserving exact
inventory count/capacity, usage counters, last-consumable identity, source
configuration, price/resale, cash and population.

Admission requires shop phase, one original visible ordinary Fool with stable
nonempty string inventory identities, a slot already free and unreserved,
finite played-main-hand data, no owned Jokers and no Observatory. Full-slot,
Negative or other edition Fool, modified abilities, hidden cards, arbitrary
Tarot copies and blind/hand phases are excluded. Requiring the slot already
free deliberately avoids relying on cleanup ordering to create capacity.
Other held cards and their capacity are retained. Unknown callbacks or
metatables in the raw catalog/inventory, missing or ambiguous catalog entries,
banned identities, malformed history, nonordinary Planet configuration or
whole-inventory preservation failure abort an admitted copy. Raw projection
is checked before graph copying could discard callback fields.

The target identity must remain the Planet for the currently declared main
hand, which must actually have been played. This is a general public-state
rule with no seed or challenge-name condition. A copied card is editionless;
only Fool advances usage during creation. A later Planet use receives its own
usage update and permanent level change. Product Execute remains a single
user click followed by fresh advice; no queued execution or blind-preparation
priority bypass was added.

## Complete bounded graph and accounting

`Brainstorm/Advisor/shop_sequences.lua` retains its existing maximum two
visible Joker/Planet buys, one original Joker sale and one Planet use, and
adds at most one use of the admitted original Fool. Its physical identity
survives inventory index changes. Every later candidate must still satisfy
the ordinary/no-Joker/free-slot/main-Planet guards; acquired Jokers and a full
inventory therefore cannot use this new transition. A root outside the
owned-Fool admission scope does not gain it later. Generated cards cannot
renew either use allowance or create a Fool loop.

All reachable endpoints of this declared graph are expanded before scoring,
including held-Fool, held-copy, copy/use, and incumbent-first continuations.
The original 64-state default/96-state maximum and shared 50,000 shop scoring
allowance are unchanged. State-limit failure, failed admitted Fool projection,
failed generated-Planet use, unsupported compared endpoint or incomplete
scoring context publishes no partial sequence. Existing unsupported ordinary
shop transitions remain separately listed as before.

Each Fool or Planet use costs the existing two action-merit units. Only an
actual Planet-to-permanent-level conversion receives the existing
`used_inventory_value` credit. Fool-to-held-copy receives zero such credit:
the loss of the original Fool and value of the new held Planet remain visible
in endpoint inventory valuation. Plans expose action cost, separate Fool and
Planet use counts, and conversion credit. Actual paid purchases and endpoint
liquidity remain charged. The existing minimum merit, incumbent margin,
survival-dominance checks and 287 complete four-world progress exception are
preserved, including comparison with the best incumbent-first endpoint.

## Routine validation and component map

- Runtime: `Brainstorm/Advisor/pack_scoring.lua` and
  `Brainstorm/Advisor/shop_sequences.lua`.
- Focused fixture: `tests/advisor_owned_fool_shop.lua`; existing pack-Fool,
  shop-sequence and 287 finishing fixtures are also run.
- Fresh receipts: `development290/focused1/` and `development290/focused2/`.
  Both passed. Focused2 completed four fixtures / 250 checks in 0.251739 s
  under its 60-second hard process cap. The new fixture has 92 checks.
  `development290/final_focused/report.json` binds the final runtime/test
  bytes and repeats the same four fixtures / 250 checks in 0.2592101 s.
- The real scorer completed all three synthetic owned-Fool endpoints with
  2,616 score calls under the unchanged shop allowance. Controlled paired
  evidence separately tests selection, withholding, crossed worlds, incomplete
  evidence, target mismatch and liquidity. It is explicitly synthetic evidence.
- Tests also cover exact generation/use history, no immediate effect, preserved
  cash/population/other inventory, original index changes, protected inventory,
  deterministic repeated results, input immutability, incumbent-first retention,
  visible paid buy/use/copy orders, raw catalog callbacks, required-transition
  failures, state-cap fallback, and the absence of Fool conversion credit.

The final focused receipt and release record bind the exact final bytes; root
owns versioning, full candidate/exact-installed validation and installation.
No adapter, native DLL, engine action, scoring allowance, save or current
setting is changed by this component. Passing fixtures establish local
mechanics and declared comparison behavior, not Jokerless win odds or human
player superiority.
