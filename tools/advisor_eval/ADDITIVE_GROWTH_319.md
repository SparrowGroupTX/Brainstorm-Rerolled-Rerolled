# Additive-card Yorick growth comparison — 319

The C06 postmortem found a repeatable integration failure: developing cards with
Empress made the growth planner reject every further discard as a sorting hazard,
even in an ordinary row whose card additions precede all Joker multipliers.
At recorded step59 it played14,175 against3,200 with two unused discards. This
diagnoses the rejected comparison, not an evaluated better move or rescued run.

This slice narrowly admits order-independent Base/Mult/Bonus card scoring before
ordinary Yorick/Perkeo/Blueprint/Brainstorm/Supernova/Droll/Burnt effects. Every
selected card must have canonical identity/effect, bounded integer chip inputs,
no edition/seal or per-card multiplier. Bounds keep reordered sums below2^53.
Held effects must be known and monotone; ordinary Steel repeats the same1.5
factor, and unscored Glass remains conserved. Ordinary played/discarded history
booleans are preserved. Contradictory effects and unknown fields still decline.

Admission only enables the existing complete comparison. The same physical hand
must still clear after the exact discard transition without a favorable draw.
Cash, Blue/Gold costs, held Steel, whole Perkeo/Negative/Observatory inventory,
population, Glass exposure, boss/visibility restrictions, growth utility and
horizon remain. Maximum12 growth scores and70 fast-clear scores are unchanged.
This does not force five-card discards or implement two-discard threshold planning.

Runtime: Brainstorm/Advisor/growth.lua and version metadata. New fixture:
tests/advisor_growth_additive.lua. Detached review and exact staging provenance:
development300/growth318/revision2/manifest.reviewed.json and its staging receipt.
The historical directory318 does not identify this runtime release.

The2,558 new manufactured checks plus384 existing focused checks cover all120 permutations for all-Mult and mixed
Base/Mult/Bonus cases, Arm/Flint, numeric boundaries, retained Steel/Red, unknown
effects, resource refusals, source-shaped Burnt/Glass/history fields and real
Decision integration within70 calls. Read-only canonical_metadata_audit.json
binds actual C06step59 fields without evaluating that captured state.
Independent final review: development300/reviews/additive_growth319.json,
SHA256 bc21f3256c0c2c31427fc9d56a428423449ea0002b8ea44fc2b16d62c1d7f308.
The reviewer independently ran the new fixture and verified all package hashes.
Full candidate/exact-installed regression and byte verification are preserved
under runs/additive319_candidate, additive319_installed,
additive319_installed_validation and additive319_final.

No new source/search/captured-state/complete-attempt worker was used for this
slice. C06 remains a timeout. No terminal gain, odds or whole-run speedup is
established. The installed8x/16x menu extension remains included; activation of
each new installation waits for the user's normal restart.
