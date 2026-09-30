# 389 — Perkeo filler and Negative stock, 2026-09-25

The installed release remains 2.184.0-alpha. Repository 2.187.0-alpha is a
frozen, full-gate-passing **uninstalled** candidate that incorporates the
uninstalled 2.185 Yorick and 2.186 cash corrections. Completed public segments
1–20 of the ongoing user-started batch attest loaded label 2.184 and win-first
profile through sequence 18531, not exact loaded bytes or a complete cohort.
The user's Tower/Stone and unwanted Negative-stock observations were not
individually matched to an action receipt in that prefix; the defect class
below is source-derived and independently manufactured.

`strategy.lua:743` now classifies Tower, off-plan Planets and non-Flush suit
Tarots as temporary win-first copy filler. Perkeo's repeated-copy and useful
stock values for those types are bounded. A known, viable first Tarot/Planet
source gets the same early empty-pool benefit regardless of type; a visible
Strength or Death therefore does not lose to Tower solely because Tower is
filler. The normal collection profile and contextually useful Flush suit
conversions remain separate.

`strategy.lua:1959` compares a one-action shop use or sale against the complete
retained inventory. It can sell a cash-positive Negative weak copy while an
ordinary source remains, includes actual interest threshold gain, and
protects matching Observatory Planets. It keeps a sole source until a better
one is held or a known, affordable, preferred Tarot/Planet can be bought
after selling the ordinary full-slot filler. A Negative sale loses the capacity
it grants and cannot create an imaginary ordinary purchase slot. The visible
replacement preview shares the shop score context and refuses a truncated
comparison. The policy emits a single sale, then requires fresh settlement
and observation before recommending any buy. Concealed/debuffed/unknown or
Eternal stock, invalid prices/capacity, pending consumable creation and the
cash-sensitive hand-size modifier block the cheap cleanup path.

The first frozen draft at `runs/filler389_candidate/` failed one Lua fixture:
`advisor_marathon_repairs366.lua` correctly expected useful Empress stock to
remain. The new weak-type predicate had treated Lua `false` from a non-Planet
`hand_type` as a mismatched hand, downgrading Empress to filler. That bug is
fixed by requiring a truthy hand type. The failed log and intermediate
passing-but-incidental-test-byte candidate under `runs/filler389_final_candidate/`
remain preserved; neither is the release candidate. The original historical
fixture's exact test hash was restored after temporary diagnostics.

The independently manufactured `tests/advisor_perkeo_filler389.lua` passes 40
checks, including a Tower-only seed, Strength/Death preference, Negative sale
and capacity, last-source guard, visible settled replacement, truncated
comparison, interest, Observatory, non-Flush suit stock, and useful Empress.
The existing 92,909-check marathon fixture again passes. The final exact
candidate `runs/filler389_verified_candidate/` freezes 108 runtime/dependency
files and 296 test files, digest
`ac7d4dc9574f4a9bdcafdaee142a3a8f1f81cd79f4b8aa7a93d6c8398f2bebd8`.
Full validation passed 256 Lua fixtures and 392 Python tests with frozen
policy and test hashes unchanged. A read-only review and one focused recheck
found no material static blocker before that regression; no additional review
was commissioned after the gate found the false-hand bug.

This establishes a local decision correction, not a win-rate change. It does
not plan unseen future consumables, value every possible Tarot/Planet as a
sale candidate, or prove that any particular observed batch loss was caused
by Tower. No runtime installation, game control, log purge, captured-state
policy/scorer replay, hidden search, training or budget renewal occurred.
Preserve the current batch and installed settings/DLLs. After normal user
completion and exit, audit the remaining public segments and verify the
installed baseline and frozen candidate before the explicit-file release and
exact-installed regression.
