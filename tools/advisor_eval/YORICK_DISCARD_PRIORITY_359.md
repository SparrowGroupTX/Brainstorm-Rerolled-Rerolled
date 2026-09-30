# Yorick / Burnt discard priority and copied growth value — 359

The user observed clears with unused discards and repeated opening-hand Empress
uses. The preserved loaded-2.158 session supports that observation: through
2026-09-16T19:17:59Z, 11 of 21 cleared rounds retained discards (32 in total), and
20 of 24 Empress uses preceded the first play. Eighteen recommendations were
optional deck development; six were tactical upgrades. This prefix contains no
terminal result. It is a previously studied opening, not an unseen cohort.
See development359/log_review/POSTMORTEM.md and report.json for original-record
anchors and logs1/manifest.json for exact byte-prefix hashes.

## Runtime changes

Brainstorm/Advisor/decision.lua now considers available Yorick / first-discard
Burnt growth once before optional development beside a known clearing hand. A
qualified useful discard preserves its complete supported finish and preempts
the optional Tarot action. Rejected growth falls back to development inside the
remaining shared allowance. Death cycling does not gain discard-only priority.
The next observed state is evaluated afresh; no future discard is enqueued.

Brainstorm/Advisor/growth.lua previously credited physical Yorick progress but
omitted repeated scoring applications through the current Blueprint/Brainstorm
row. For its narrowly supported visible row, one bounded exact rescore of the
same retained play with one physical Yorick increment measures the marginal
scoring effect, including intervening additive Mult. The partial-growth utility
factor is clamped between one and the number of current scoring applications.
The same factor is used in the qualified two-discard threshold comparison.
It remains a heuristic valuation, not a learned win probability or a guarantee
that a given copying arrangement will remain best later.

Physical discard counters and threshold increments are unchanged. Copy credit
never manufactures extra discards, doubles physical progress, assumes a future
reorder, or converts a score floor into an exact baseline. Uncertain, concealed,
unsupported, soon-expiring or incompatible rows get no new bonus. At least one
score is reserved for checking the retained finish; the growth cap remains 12
and the overall fast-clear cap remains 70. Ordinary/shop/consumable allowances
remain 140000/50000/25000. Input, whole inventory and population are preserved.

## What this does not promise

The advisor does not blindly exhaust all discards or always discard five cards.
A five-card reserved finish in an eight-card hand can leave only three safely
discardable cards. Boss hazards, held Blue/Gold value, finite remaining cards,
cash, interest, action cost, short horizon and mature low-value growth still
matter. The existing copy qualification is a narrow canonical row, not every
Joker combination. Tactical Empress use can still precede a discard when needed
to secure a clear. This is not a complete joint hands/discards/consumables planner.

It also does not choose an optimal Perkeo copying pool, implement generic surplus
consumable sales, solve exhausted below-target Serpent budgets, or qualify future
discard planning under Amber Acorn. No rescued run, 2.159 terminal outcome,
calibrated odds, new sticker or stronger-than-human performance is demonstrated.

## Verification and preservation

tests/advisor_growth_priority359.lua verifies the production decision integration,
consecutive fresh observations, first/spent Burnt, safe fallback, inventory/input,
boss guards and actual shared-budget accounting. The old decision fails the
new priority assertion; the original bytes and failure are preserved separately.

tests/advisor_growth_copy359.lua verifies current-row exact marginal arithmetic,
copy chains, immutable physical counters, unsupported/floor/expiration exclusions,
resource costs and all caller caps from zero through twelve. The old growth
module fails the newly useful copied-X4 partial-growth case.

tests/advisor_yorick_pair.lua retains all 720 finite-population draw orders and
24 independent complete count-family comparisons. Copied partial utility can
change which safe single/pair candidate wins; the recovery repairs obsolete
selection assumptions with explicit physical endpoints and cost comparisons.
All original fixture bytes and intermediate failed receipts remain under
development359/growth_review. Independent review is in
development359/priority_review/RESUMED_REVIEW.md.

This release uses passive public-log/source analysis and manufactured regression
only. All historical experiment quotas remain closed. Game, saves, profiles,
journals, current settings and existing native DLLs are not controlled or reset.
The September 22 recovery note is development359/RESET_20260922.md.

## Completed installation and final regression

Installed **2.159.0-alpha** at **2026-09-22T10:31:04.4428288-05:00**, using
install_slice.py with explicit Advisor/decision.lua and Advisor/growth.lua.
The two existing version fields were stamped consistently; no other runtime
module or native DLL changed relative to installed 358. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260922-103103`.

All 89 deployment files and 105 frozen runtime/dependency files matched the
repository and installation. Policy digest:
`44550e55371a8e4eb41aa4ea6aea30006daf5e693a4c93bcdc870d591b4f839e`.
The current configuration was preserved at deployment with SHA256
`ef870d95171d06779b42a7ae17a6167dae3bf494f4104fabe434ce3b46ed87ad`.
This is the user's current configuration, not a restored September 16 copy.

Full frozen candidate validation passed **231/231 Lua fixtures and 391 Python
tests** (32.047 seconds Lua, 13.250 seconds Python). Full exact-installed
validation passed the same counts (32.031 seconds Lua, 12.172 seconds Python).
Each suite retained its 60-second cap; policy/test hashes were unchanged across
both validations. Earlier component failures are preserved; no failed final
regression is pending. Evidence is in runs/growth359_candidate/validation,
runs/growth359_installed/record.json and policy, and
runs/growth359_installed_validation. The final checkpoint receipt binds these
records and current documentation under runs/growth359_final.

Installed activation is unconfirmed and awaits a normal user restart. No tools
launched, controlled, restarted or stopped the game. No new terminal outcome or
post-installation player-performance result is claimed.
