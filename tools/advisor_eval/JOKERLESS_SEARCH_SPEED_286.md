# Exact Jokerless search gates — development286

The Four of a Kind opening request can take substantial wall time because it is
selective and because rejected seeds previously performed unnecessary work.
The old search generated both ordinary shop cards and both packs, including
every Standard card, after a Coupon result even when the visible voucher could
not satisfy the requested Telescope predicate. It also rebuilt the same catalog
signature for each Coupon seed and recomputed booster total weight for each
pack. These are concrete redundant operations; their removal does not establish
an empirical throughput multiplier, a future match yield or a stronger run.

## Private exact gates

`Brainstorm/Core/jokerless_opening.lua` now prepares a detached catalog copy for
one bounded `M.search` call. Supported positional pools, unique complete fronts,
ordinary edition rate and finite recognized booster definitions must pass the
structural checks. The copy stores the catalog signature and booster total,
with the total summed in the same order as before. There is no global cache and
the caller's catalog is never mutated. Public yield callbacks can mutate their
own catalog; the private copy and invariants are refreshed after each callback.
Unrecognized or malformed catalog shapes keep the complete existing predictor
path instead of entering the optimized gates.

The existing Small Coupon rejection remains first. The private search path then:

1. Generates the Big tag and voucher in their original order. A wrong voucher
   rejects the index only if Telescope is actually required.
2. Generates **both** ordinary shop slots with the original set draws, identity
   exclusion and keyed resampling. An absent requested Planet rejects the index.
   Legacy `require_saturn` receives the same necessary-condition gate without
   binding new target metadata into its old unbound recipe format.
3. Generates both pack choices in their original order. The sum of Standard
   `choose` limits is an upper bound on available Blue, quality-Blue and
   Steel-Blue choices. A sum below any requested minimum rejects the index.
   Revealed card count is not substituted for selectable capacity. Explicit zero
   minimums remain zero, and absent Telescope requirements remain absent.
4. Runs the complete Standard generation and ordinary match predicate for every
   remaining candidate. Shared keyed streams are not reordered, restarted or
   skipped within a potential match, including across two Standard packs.

`M.predict` remains the full public generation API and has no private rejection
gates. Matching recipes retain all their fields and provenance. Search retains
its exact index ordering, bounds, cursor accounting and requested match count;
`not_found` still retains any completed matches below that count. No criteria,
search caps, target hands or native code changed. The ordinary native tag filter
is not reused because its eligibility pool differs from Jokerless.

## Explicit prospective search contract

A proven-false required predicate permits search to skip later irrelevant
generation. Thus a wrong-voucher index is a known nonmatch even if its unused
shop stream would exhaust resampling in the full public predictor. It is counted
as a tested nonmatch without imputing any omitted shop or pack result. This is
an intentional prospective distinction from requiring complete generation before
every rejection. Public prediction keeps the downstream error, and all required
branches before a rejection and all potential-match branches still execute their
existing failure handling. No historical unsupported/search record was changed
or reclassified. Structural fallback prevents malformed catalog shapes from
silently gaining these optimizations.

## Routine validation and limits

`tests/advisor_jokerless_search_gates.lua` passes153 checks using injected keyed
streams throughout. It does not discover seeds or measure real search throughput.
It compares full public prediction with search for Mars, Jupiter, hand-only and
legacy Saturn options, mixed cards and differently sized Standard packs;
checks exact recipe equality, keyed draw order, resampling, duplicate shop-card
exclusion and unchanged inputs; and checks the individual rejection gates,
zero bounds, required resample failures, malformed/sparse fallback, preserved
partial matches/cursors and catalog mutation after a yield.

One controlled wrong-Telescope case needs3 draws after gating versus69 in full
prediction. That count establishes the removed work for that fixture only; it
is not a seeds-per-second result or a user wait-time estimate. A separate forced
fixture verifies the explicit downstream-failure contract above.

`runs/search286_development/focused2/` preserves the final focused run:
the new gate fixture153, existing opening279, Planet targets83 and source recipe16
checks all passed in0.125s under an explicit60s subprocess cap. `focused1/` keeps
the earlier successful143-check version. `reviewed_files.json` binds the reviewed
source, test and note. The existing source-recipe fixture consumes preserved
fixture data; no new original-source execution occurred.

The companion runtime scheduling/progress component belongs to
`JOKERLESS_PROGRESS_286.md`; root checkpoint records own full frozen
regression, installation and exact-installed hashes. No hidden search, source
component, captured replay, complete attempt, executable ZIP read, native build,
game control or save access was performed by this component. Match availability,
affordability, retention, survival, win odds and comparison with a good human
remain unmeasured. Previously closed experiment budgets remain closed.
