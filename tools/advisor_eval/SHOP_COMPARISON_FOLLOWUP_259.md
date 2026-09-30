# Shop continuation, liquidity and catalog follow-up — 2026-09-10

This is the scoped implementation evidence for next-ten items 1, 4 and 6. The
current checkpoint/installation ledger determines the installed version; the
259 suffix identifies the final scoped test run, not a deployment claim.

## Completed comparisons retain their horizon

`shop_sequences` now records the best completed endpoint for each first action.
`with_continuation` attaches that evidence even when the incumbent first action
does not change. The decision router passes it to `shortfall_reroll`, which uses
the complete sequence's score and exact net cash, including sale proceeds and
free held Planet use. It does not store or execute a future action queue. Each
actual state is analyzed again, with shifted offer indices and observed cash.
Incomplete graphs cannot attach favorable partial evidence.

The regression isolates the old failure: a single purchase loses to a catalog
refresh while its completed visible pair wins the same comparison. The actual
Decision entry point now keeps that incumbent; after its first purchase the
next observed state independently keeps the remaining complement.

Evidence: `runs/shop_continuation254_focus2`, seven fixtures/180 checks, 0.265 s.
All runtime and test hashes stayed unchanged. Root installed this slice as 2.55.

## Shared resource cash allowance

`liquidity.estimate` counts retained rental obligations (including debuffed and
expired rental cards) and conservatively reserves all available paid discards.
Supported next-blind resource counts take precedence over reset counts. Unknown
resources remain labeled unresolved; sampled-safe opening profiles do not
prove a smaller complete finishing cost. Rental timing is after play and before
interest. The spending floor is the real borrowing limit plus this reserve.

Purchases pay a bounded penalty only for increasing an existing reserve gap;
timely emergency spending is still possible. Completed shop sequences assess
the final gap once, after the whole purchase/sale/use path. Conditional income
reports the same post-payment allowance; Moon uses its conservative reserved
cash basis for interest. No delayed payout becomes current purchase money.
Generic and tactical paid rerolls now consume the same estimator.

The optional future resource-plan contract requires a matched observation,
resources and target, complete known actual-action comparisons, at least four
samples and a clearing route in each world. No current producer supplies it.
Even accepted sampled resource evidence explicitly carries no win guarantee.

Credit Card and Moon acquisition changes moved into the shared pure purchase
helper; the sequence layer no longer adds them a second time. Direct and
multi-step purchases therefore use the same debt and interest state.

Evidence: `runs/liquidity256_focus2`, ten fixtures/501 checks, 2.234 s. The first
retained test attempt in focus1 used an already sampled-safe root, so its new
sequence-route assertion failed; the test target was corrected to exercise a
shortfall. Production code did not change for that fixture correction.
`runs/liquidity256_source1`: original-source purchase/pricing/resource parity,
13 cases/156 comparisons, 0.104 s. Root installed the integrated slice as 2.58.

## Full-row ordinary catalog replacements

The existing six-entry catalog shortlist can now admit a full row of at most
six Jokers. For each candidate it constructs every supported legal original
victim's exact post-refresh, post-sale and post-purchase state. The refresh must
be affordable before any future sale. Removing Credit Card borrowing or a
Negative supplied slot is applied before purchase legality. Final sampled
resource allowance and retained whole-build utility must both permit the
upgrade; raw immediate opening gain alone is insufficient.

At most twelve paired victim comparisons are admitted in complete victim sets
before scoring begins. Unadmitted entries receive zero probability credit. An
incomplete later comparison invalidates the shortlist; an unsupported legal
victim gives its whole candidate zero credit. Unknown sales, charged Invisible,
Luchador, Diet Cola, Chaos and Astronomer effects remain unsupported. Protected
Eternal/pinned victims and capacity-invalid Negative sales are not legal
replacement alternatives. Forced Eternal/random stickers and edition outcomes
remain outside the supported ordinary no-edition probability mass.

Diagnostics retain candidate eligibility, each compared victim, net cash,
capacity, resource allowance, utility, sampled gain and rejection status.
Expected cash spend includes every refresh fee and the supported net purchase
after sale proceeds. The published action is still only the reroll; any actual
revealed replacement is chosen by fresh advice. Opportunity probabilities use
the existing independent-offer approximation and are not win probabilities.

Evidence: `runs/catalog_replacements259_focus1`, nine fixtures/630 checks,
2.344 s, unchanged runtime/test hashes. New fixture has twenty checks, including
real scoring with two victims/3,488 evaluations, whole-inventory Perkeo and
mature growth preservation, debt/Negative/pinned legality, unknown/incomplete
victims and complete-set admission. `runs/catalog_replacements259_source1`
extends the source probe with actual sale/removal effects: twenty cases/296
comparisons, 0.104 s, frozen policy/adapter/source provenance and a 30 s cap.

These are bounded correctness and decision tests. No episodes were run, no
game window/process was controlled, no executable was launched, and no saves
were accessed. No measured challenge win rate or numerical improvement follows.

## Review correction before installation

The full-row refresh must preserve the shared rental/discard cash reserve on a
miss, when the old row remains intact. The initial implementation admitted a
refresh down to the borrowing limit and checked the reserve only after a
successful sale/purchase. That could incorrectly fund a failed search with a
sale contingent on success. The corrected full-row gate requires cash after
the refresh to remain at or above the reserve floor. It does not demand the
extra purchase dollar used for empty-slot searches: verified sale proceeds can
still fund a replacement after a hit.

`runs/catalog_replacements259_review1` supersedes focus1 for this cash gate.
Nine fixtures/632 checks pass in 2.219 s with unchanged runtime/test hashes;
the replacement fixture now has 22 checks, including a miss that cannot cover
retained rentals/paid discards and an exactly reserved sale-funded boundary.
The source transition helpers are unchanged from the 20-case/296-comparison
source check. Broader expected scoring loss on cash-sensitive missed refreshes
remains a limitation beyond this resource-reserve correction.

## Further review: cash-sensitive missed-refresh scoring

This correction supersedes the remaining cash-sensitive miss limitation above.
Runtime tactical rerolls now lazily compare the actual post-refresh cash state
with the retained row, after finding positive supported catalog mass. Expected
target gain includes the hit improvement plus the miss probability multiplied
by any negative paired miss gain. Positive miss gains and unmodeled positive
Flash growth receive zero credit. Unsupported or incomplete miss comparisons
reject the tactical forecast; all work stays inside the existing shared shop
budget. At most twelve admitted victim comparisons are followed by one complete
miss comparison. The failed refresh still preserves the shared cash reserve.

Forecasts and context diagnostics retain miss score evidence, cash, cost, status
and gain. The original direct callback contract remains available to isolated
callers without a miss callback, but Strategy's runtime route always supplies
the complete comparison.

`runs/catalog_replacements259_miss2` is the final scoped runtime evidence: ten
fixtures/641 checks pass in 2.125 s with unchanged policy and test hashes. Nine
new miss checks cover rare-hit versus likely-loss decisions, constant score,
no optimistic positive miss credit, lazy execution and incomplete/unsupported
comparisons. A real Bull row with a discounted source-configured Duo declines
the old positive-hit-only recommendation after actual miss cash loss is
included (3,488 scoring evaluations). The original replacement fixture now
uses 4,360 evaluations including its added miss comparison.

The retained initial miss1/debug fixture attempts selected a purchase below
the existing retained-build merit threshold, so the old policy also declined.
The final fixture supplies the captured discount needed to exercise the
intended old-advice-versus-corrected-advice regression; production code did not
change for this fixture adjustment. No episode or measured win evidence follows.
