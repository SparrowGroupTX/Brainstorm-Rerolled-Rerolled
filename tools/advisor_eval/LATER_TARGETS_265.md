# Challenge opening plus a later Rare target

Installed as 2.65.0-alpha on 2026-09-11 at 09:57:18 CDT. See
SESSION_RESET_265.md/.json for the final installation, hashes and validation.

The user chose to retain the exact two-Legendary opening and add later targets.
This first extension adds one optional target from the20 original Rare Jokers,
including Blueprint, Brainstorm, Baron, Burnt Joker and DNA. The deadline selector
ranges fromAnte2 through8. Existing opening-only settings and v1 behavior remain
the default. No seed, challenge-specific recommendation or projected win rate is
hardcoded; the challenge catalogs encode verified source rules and starting rows.

## Product use and scope

After a normal restart, open Brainstorm → Challenge opening. Keep the desired
two Legendary selectors, enable Conditional later offer, select the later Rare
target and its deadline, then use the existing search button/hotkey on a fresh
challenge. This still replaces only an untouched fresh challenge after a match.
All gameplay and advisor Execute actions remain user initiated.

The result is a conditional initial-shop offer. Take the searched first Small
Charm/two-Soul opening, then play every blind. Avoid further skips, shop rerolls,
pack openings, voucher purchases, other Rare acquisitions/sales/generation,
Showman and Joker-generating consumable uses before the target. Keep the opening
pair and any starting Rare. Ordinary Common/Uncommon support purchases and sales
are compatible; original Riff-Raff Common generation uses separate source RNG.
Acquiring the target ends the future-offer condition. Its cost and a legal place
in the actual row must still be assessed when revealed.

The native query receives the actual current20-position Rare availability mask
and preserves unavailable positions. Core validates the original pool order,
unlock/ban/ownership flags, starting Joker identities/Eternal/Negative/pin flags,
shop rates/slots, pending tags, tutorial/saved-shop overrides and generation rules.
This reads public runtime state when the user starts the feature; no evaluation
tool reads user saves. Common/Uncommon target generation has gameplay-dependent
eligibility and is deliberately outside this initial extension.

Known impossible capacity is excluded: a full protected row requires a Negative
slot bonus, and the zero-slot transition caps the usable acquisition window.
Blast Off and Typecast exercise those source-derived rules. Bram Poker has no
shop Jokers, so its optional later filter is unavailable; its original opening
route remains. Jokerless is excluded from both routes.

Found ante means the ante when the shop stock is generated. Ante1/shop1 follows
Big. AnteN/shop1 follows the previous Boss; shop2 follows Small and shop3 follows
Big. The Boss shop belongs to the next ante. The deadline can accept earlier
offers too. No survival/affordability forecast is invented.

## Advice, cost and provenance

The advisor appends detached diagnostics without overriding scoring/survival
advice or queuing actions. It distinguishes a conditional offer, an actually
visible offer with current price/capacity, and the complete engine present and
active now. Missing, expired, debuffed or sacrificed Jokers do not count as an
active retained engine. Negative slot conservation, pinned/Eternal protections
and true one-sale capacity are respected. A transient used flag on unbought
shop stock is distinguished from a purchased Rare exclusion.

Observed incompatible pools, rates, extra skips/packs and proposed path-changing
actions withdraw or qualify the forecast. This is not a complete action-history
tracker: removing and later restoring a condition can hide an earlier divergence.
The display never labels historical adherence, legal acquisition or future
survival verified. A fresh current inventory can establish current retention only.

The product keeps cumulative batch/miss counts and measured native-call time,
with an explicit unknown-clock state. Those counters exclude gameplay/setup
time and never mislabel a batch limit as the exact number of evaluated seeds.
Snapshot capture omits this telemetry so computer speed and miss history cannot
change deterministic decision samples; the product's cost display retains it.
Offline helpers and auditors follow the frozen Core-selected native artifact;
new cohorts bind its filename/hash, while historical cohorts remain on2.16.
Yorick reports now use actual x_mult/yorick_discards counters; increment/reset
constants are separately labeled and missing actual counters stay unknown.

## Evidence and limitations

NATIVE_LATER_265.md records199 native checks, three compatibility suites,
64 source-generation/capacity cases, actual Boss rollovers and Riff-Raff stream
independence. Core admission is checked against36 original challenge/profile
fresh starts. These use declared synthetic profiles and isolated fixtures.

Three fresh one-million-seed smoke searches were registered and run once, all
returning misses. Their native-call times were about0.027–0.028seconds each;
the complete worker/audit cost was0.721seconds. Misses, cursors and frozen inputs
remain in runs/native_later265_smoke1. This tiny smoke is not a yield estimate,
search ETA, acquired engine, full attempt or win-rate measurement.

The larger repaired-policy16-worker full-attempt comparison remains deferred
before execution at the user's request. Actual per-challenge win rates remain
unknown. Passing tests cannot establish numerical improvement.

New native bytes live beside the old loaded2.16DLL under their full SHA256 name.
The tested-slice installer requires build/test/source/runtime evidence, verifies
the selected loader, backs up runtime files and preserves settings/saves. Final
installation paths, hashes and complete regression results belong in the current
checkpoint rather than this implementation note.
