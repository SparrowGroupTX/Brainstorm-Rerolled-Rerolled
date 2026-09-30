# Collection search component (development 300)

Root's later registered M04 passed the existing native API regression, the 41
synthetic checks and two bounded 50,000-index v9 smoke calls. The blank rank/suit
query with zero minima is valid; both calls screened their 50,000 indices with
zero exact candidates. They finished before cancellation, so M04 does not prove
active cancellation responsiveness. M03 is retained as a spent fixture-dependency
failure: its frozen binary directory omitted complete anchor assets expected by
the existing API regression. M04 included all four `.ids`/manifest pairs.
Evidence: `../runs/gold299_20260914/M03/` and `../runs/gold299_20260914/M04/`.
No native source/DLL changed between those two registrations. Root's registered
M07 then passed active cancellation: 909,312 screened indices, nine exact
candidates, cancelled after 0.0104299s and returned in another 0.0002440s, with
no worker remaining. This is one selected mechanical fixture, not a general
worst-case latency guarantee. Its intentionally nonmatching Ante8-only Perkeo
quota proves no acquisition or win. Evidence:
`../runs/gold299_20260914/M07/validation/cancellation.json`. These jobs are spent;
they do not provide unused experiment authority for this worker.

Implemented source: `Immolate/src/collection_targets.hpp`, additions to
`Immolate/src/immolate.cpp` and its ABI declaration, plus the CMake target and
`Immolate/tests/collection_targets_regression.cpp`. Existing normal v1-v8 and
challenge ABIs remain available. No existing native DLL was changed or staged.

Current candidate DLL: `Immolate/build-collection300-4/Immolate.dll`.
SHA256: `ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf`.
Bounded build and 41 synthetic observation/contract checks pass; receipts are
`native_collection_build4/build.json` and `synthetic.json`. Build1's test-only
C++ reference-binding compile failure is preserved. Earlier successful builds
are development artifacts; only build4 includes both OR branch fixes.

`brainstorm_v9` takes all 22 existing v8 arguments, then:

1. `bool interchangeableCopies`: Blueprint and Brainstorm requirements accept
   either center while retaining timing, edition and Perishable restrictions.
2. `const char* missingNames`: canonical native Joker names separated by US
   (`\31` in Lua), no trailing empty entry. Duplicate names count once.
3. `int minimumDistinct`: 0..150. Zero does not constrain encounters.
4. `int firstAnte`: inclusive first counting Ante, 1..8.
5. `int lastAnte`: inclusive deadline, firstAnte..8.
6. `int budgetMs`: 1..30000. The actual cooperative deadline is checked between
   4,096-index batches, scalar survivors and recursive timeline branches.

Return value is owned JSON text, released with the existing `free_result`:
`schema`, `status`, `seed`, `screened`, `exact_candidates`, `seconds`,
`budget_ms`, `threads`, `route`. Status is found/not_found/timeout/cancelled;
invalid/busy requests have a smaller status response. A timeout is not proof of
an empty seed population. `screened` counts complete gate batches (or scalar
candidates without a gate), not guaranteed exact timeline evaluations. Worker
startup/cleanup and a current bounded batch can slightly exceed the deadline.

`brainstorm_cancel_v9()` cooperatively cancels the active v9 job. The runtime
must suppress normal search and estimate entry points until that worker has
returned because they share native query globals. Use a LOVE worker thread to
keep the menu responsive; the current normal `autoReroll` v8 call is synchronous.
Keep a generation/profile token and ignore late results after stop/profile
change. A stop before the worker enters v9 also needs a pending-job guard, since
each newly entered v9 job clears old cancellation state.

Search reuses the existing normal exact necessary-condition Charm/Soul SIMD
gate and authoritative no-reroll timeline. It counts distinct non-Perishable
missing-Joker offers on each individual branch, including selected opening
Soul/Judgement Jokers when Ante1 is in the window. Initial shop stock and the
contents of each prescribed left-to-right opened Buffoon pack are observations.
Counting never acquires an ordinary target. Once N is reached, no further
membership counting occurs; traversal ends when all named requirements are
also satisfied. Different copy-center ownership and collection masks remain
separate branches. Both visible copy alternatives are explored when later
requirements could depend on their different pool locks.

The original four distinct slots Yorick/Brainstorm/Burnt/Perkeo are accepted
independently by current source; the synthetic fixture specifically checks
slot-four Perkeo may be the first Soul and Burnt may precede Brainstorm. Duplicate
requirements retain the prior occurrence-order constraints. This does not assert
the historical installed DLL was built from identical current normal source.

Lua request draft: `collection_search.lua`; synthetic fixture:
`collection_search_fixture.lua`, 29 checks with unchanged-input receipt under
`../development294/collection300draft2/report.json`. It is outside the product
until root stages the coherent runtime slice. It prepares the user's Red/Gold,
two-Soul Yorick/Perkeo, copy/Burnt byAnte5 opening, CPU maximum, no Perishables,
optional distinct missing count/window and optional Zodiac deck. It binds loaded
complete Gold progress, excludes six unsupported fresh-run prerequisites,
changes no saved filters and starts no job. The product caller owns explicit
start/stop, profile refresh, launch safety, event logging and installation.

No v9 rarity estimate is claimed. Existing v8 estimates must not be labeled as
estimates of the new compound quota/OR query. The 30-second actual budget can be
enforced even when an expected-wait estimate is unavailable. Offer matching does
not qualify affordability, retention, survival, route feasibility after other
Joker acquisitions, player unlocks or a Gold-sticker win. Later shop offers remain
conditional on the prescribed no-reroll/acquisition route.

At this component checkpoint no seed searches, original-source components,
captured replays or terminal attempts were executed by this worker. New dynamic
native validation, if registered by root, must be recorded separately and added
to the native evidence gate before staging the content-addressed sidecar.
