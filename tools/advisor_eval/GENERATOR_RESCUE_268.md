# Owned-generator last-hand revelation — 2026-09-12

This component note describes the new runtime implementation awaiting the parent
integration/install ledger. It does not establish a source rescue, challenge win,
player win rate or runtime activation.

## Behavior

`Brainstorm/Advisor/consumables.lua` recognizes The Emperor and The High Priestess
as owned generators. They never enter a fabricated pure transition: `apply`
returns an explicit public-reveal requirement. After existing deterministic
consumable comparisons, a last-hand/no-discard position may recommend one owned
generator use only when every legal ordered immediate play has a supported
maximum below the remaining target. The result contains no generated identities,
post-reveal score, rescue probability or automatic follow-up. Product Execute
remains user-clicked; ordinary fresh advice handles the actual revealed cards.

Source `card.lua` generator creation uses `consumeable.tarots` or `.planets`
and available capacity. The source callback removes the owned card first,
including its Negative slot. Admission requires the known Tarot type/name,
unmodified generation configuration, a positive integer count at most two,
known integer capacity and at least one resulting slot. Initially full ordinary
inventory frees one slot; removing a Negative does not invent capacity.

The existing complete deterministic rescue retains priority. Incomplete prior
consumable comparisons/sequence shortlists decline the generator fallback.
Whole-inventory `preservation_cost` is still checked. Active Perkeo abstains even
when removal alone would improve the pool: unknown generated replacements could
dilute that whole copying inventory. Mr. Bones also abstains because a scoring
shortfall does not prove that its final play loses the run. Existing boss/order
specialists retain their decision priority. No challenge name or seed dispatch
was added; no-Joker and already-developed Dagger rows use the same mechanics.

## Complete maximum and explicit limits

`Brainstorm/Advisor/scoring.lua` adds `upper_bound`, separate from the existing
mean and supported random floor. Admitted random contributions take their
possible positive maxima, including Misprint, Lucky, Bloodstone, Space Joker and
monotone cash-dependent effects. All random rolls may succeed together for this
upper bound; their probability and dependence are not asserted.

For supported independent Joker effects, additive effects precede multipliers
to bound Joker ordering. The caller enumerates all ordered nonempty selections
of at most five cards from at most eight held cards, including legal constraints.
Five held cards require 325 evaluations; eight require 8,800. The whole pass must
fit inside the existing 25,000 consumable evaluation allowance. It never starts
a partial maximum comparison. Ordinary 140,000 search and 70-score fast-clear
allowances remain unchanged, and fast clears do not enter this path.

The maximum declines unknown/custom keyed effects, concealment, unsupported blind
mechanics, negative/nonfinite domains, shrinking Joker multipliers, copy routing,
Midas/Vampire/DNA/Hiker before/order interactions, Hanging Chad/Photograph,
Raised Fist/Shoot the Moon, Baseball/Flower Pot/Seeing Double, mixed Joker or
held-consumable Mult editions, and held-card additive Mult. These restrictions
are conservative coverage limits, not advice that those engines are weak.

The ordinary scorer caps repetitions at 100. Maximum admission separately sums
possible played and held repetitions across the full active row, including a
possible Red seal, and declines if either can exceed 100. Large Negative rows
are never silently truncated into an impossibility certificate.

The score cache wrapper counts each maximum pass and supplies the immutable
per-decision preparation. Canonical bound rows are cached only for that detached
input. No input state, live callback, RNG, playing-card population or inventory
identity is modified. Existing Glass exposure and growth transitions are intact.

## Focused evidence and execution boundaries

`tests/advisor_generator_rescue.lua`: **94 checks pass**. It covers the generic
owned-generator omission and the recorded five-card development mechanics
(complete maximum 15,080 across 325 ordered plays), all six orders of an
independent additive/X row with both played-card orders, possible random clears,
known Planet rescues, Observatory, Perkeo, Negative capacity, unknown mechanics,
shrinking multipliers, repetition overflow, insufficient complete budget,
prepared-scorer counts, forced selection, normal no-Joker/Dagger decisions and
fast-clear preservation. No generated card or rescued outcome is imputed.

Other passing focused fixtures: existing consumables (79 checks), scoring (66),
score-cache coverage as owned by the parent cache slice, fast clear (24), decision
integration (12), resource decisions (199), inventory development (75).
The first generator fixture run corrected an overly strict test expectation:
an already-clearing Observatory state may legitimately receive existing safe
Planet development, so the assertion now forbids a generator claim rather than
requiring no suggestion. An initial fixture-list invocation named a nonexistent
inventory fixture and ran no fixtures; the correct fixture then passed.

Only ordinary unit fixtures and read-only executable-ZIP source inspection have
been performed for this component as of this note. No new original-source worker
or complete-attempt episode has run or been pre-authorized by these unit checks.
Any source validation must have a fresh prospective bounded registration and
preserve all errors/timeouts. All prior 262/266 pilot and step75 component leases
remain spent; their unused seconds provide no new entitlement. No game process,
save or settings was accessed or changed. Unit fixtures used the isolated Lua
DLL; neither existing Immolate DLL was changed or invoked by this component.
