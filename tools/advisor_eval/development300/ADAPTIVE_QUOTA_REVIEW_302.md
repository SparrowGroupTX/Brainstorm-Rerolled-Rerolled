# Read-only review: missing-Joker quota after startup qualification

Reviewed the current 302 product query/controller and native v9 implementation. No search or original-source worker was run for this review. M12 was separately audited from its completed receipt; its 0.39000000001396984-second component verifies only original-source product startup using an injected, already-observed S05 match.

## Implemented behavior

- `Brainstorm/Advisor/collection_search.lua` reads fresh loaded-profile missing records every time `prepare` runs. Unknown records fail closed. Its default `minimum_distinct=0` disables the missing-target requirement; a positive value exceeding the supported missing list fails before native dispatch.
- `Brainstorm/Advisor/auto_run.lua` reuses the explicitly bound search recipe across runs and receives fresh collection observations. `Core/auto_run_product.lua` calls product preparation anew each time, so completed targets disappear from the native missing list. The numeric quota itself does not adapt.
- `Brainstorm/UI/collection_run.lua` currently renders zero as `Missing: any`. This is potentially misleading: zero means no missing-target condition, including when the strong opening Jokers already have Gold stickers.
- `Immolate/src/collection_targets.hpp` correctly counts exact distinct missing identities only within the inclusive Ante window, rejects Perishables when requested, and stops counting immediately at the quota. Copy interchangeability changes fixed strategic requirements, not which actual missing identity earns quota credit.
- The timeline only succeeds once both fixed strategic requirements and the requested missing quota are complete. It preserves acquired strategic Joker locks and separate Blueprint/Brainstorm branches. Counted offers do not become owned Jokers and do not demonstrate affordable acquisition, retention or survival.

## Small useful next change: an explicit automatic collection quota

Provide a clearly named automatic mode for the automatic collection loop. Require at least one currently missing Joker that the prescribed route can actually produce. There is no need to choose an arbitrary remaining-population threshold: when Yorick or Perkeo is still missing and Ante 1 is in the requested window, the already-required opening naturally satisfies a quota of one. Once the strategic opening no longer adds progress, the same requirement forces the search to include a new reachable missing target. The existing 27-second native/30-second product ceiling remains unchanged.

Keep a separate strict numeric mode for explicit user requests such as four distinct missing offers after Ante 3. Do not silently relabel an explicit zero or relax a strict user quota after a miss. In automatic mode, no reachable targets should produce an explicit route-exhausted status rather than another unconstrained run. In strict mode, a requested count exceeding reachable targets should explain the mismatch before any worker starts.

Pure fixtures can verify: fresh collection; opening pair already complete; all fixed strategic Jokers complete; a previously missing target becoming complete between runs; late Ante windows; one reachable target remaining with a larger strict quota; all targets complete; unknown metadata; and only unmodeled targets remaining. These are request-logic fixtures, requiring no new seed mining or source experiment.

## Reachability must match this exact fixed route

The normal reusable Gold-search registry already excludes Stone Joker, Steel Joker, Glass Joker, Golden Ticket, Lucky Cat and Cavendish because their prerequisites are not modeled by fresh-run search. That registry is broader than the fixed quick-run route: it also labels Canio, Triboulet and Chicot as direct-supported Soul targets. The quick-run route spends its two starting Soul choices on Yorick and Perkeo and thereafter examines shop stock/Buffoon packs. Those three other Legendary Jokers are therefore not reachable quota candidates on this exact route. Likewise, Yorick/Perkeo are not reachable quota candidates in an Ante window starting after Ante 1 unless a separate modeled later source exists; the current route provides none.

Compute a route-specific eligible list without deleting those Jokers from the overall collection registry. Preserve each excluded identity and its concrete reason in request metadata/status. When only such targets remain, the eventual solution needs a different declared opening or a supported prerequisite-development route. Continuing the same fixed opening is not an implemented strategy for finishing those targets.

## Subsequent integration gap: show which offers satisfied the quota

Current v9 result JSON reports seed, screened/exact counts, timing and threads, but no satisfying route witness, matched missing identities or encounter windows. Consequently, the product can know that a conditional quota was satisfied without giving its strategic planner a concrete future target itinerary. The fixed opening recipe retains conditional copy alternatives and explicitly leaves future acquisition unverified.

A useful later native slice would emit a bounded witness containing no more than the requested number of distinct quota matches, actual matched identity/Ante/source, and the fixed-copy branch that satisfied the combined search. This requires a new sidecar and the documented native evidence gate. Treat the witness as conditional route metadata, never as permission to act on hidden future stock or as proof of affordable acquisition. A separate causal planning comparison should decide whether reserving cash/slots for an actually visible needed Joker improves the complete common-world outcome.

Do not add another native search for this review or infer win odds from quota counts. The existing tests establish deterministic counting and guards; S05 and M12 used quota zero and therefore provide no positive-quota original-source route validation. A genuinely new quota-route experiment must be separately registered under a remaining fresh lease before execution.
