# Advisor 2.16 update — 2026-09-10

The six requested priorities are implemented. These are the original ranked
development forecasts, in **percentage points on affected builds/runs**, not
measured patch gains. They overlap and cannot be added together.

| Priority | Change | Initial potential gain | Implementation scope |
|---|---|---:|---|
| 1 | Challenge opening search | +15–35 pp on useful filtered starts | Nineteen challenges; first Charm, two natural Souls, optional target pair |
| 2 | Played-card order | +3–8 pp | Up to 120 orders of the chosen cards, preserving unplayed slots |
| 3 | Copy-Joker purchases | +4–10 pp | Fair paired deck samples with up to eight target/order layouts per row |
| 4 | Boss-rescue sales | +3–8 pp | Legal supported boss-disable sale only when it enables an immediate modeled clear |
| 5 | Later-hand shop value | +3–8 pp | Discounted paired conditional scenarios for supported effects |
| 6 | Paid-reroll budgeting | +3–10 pp | Eligible useful offers, actual slots/prices, cash/interest/survival reserves |

The opening feature is the largest likely change per implementation hour.
The ordinary advisor changes justify only small upward revisions, not a claim
that every challenge improved by ten points. For several compatible challenges,
a **useful targeted two-Legendary opening** plausibly adds at least ten points
relative to the preceding ordinary-start baseline. That is this batch's
installation milestone. It is a different starting distribution, not proof
of a stronger policy on the same seeds. Simply choosing Any/Any can produce
two slow or unsuitable Legendaries and may offer much less benefit.

## Working win-rate guesses

All figures below are **subjective, very low confidence**. They are rough chances
of an Ante 1 challenge win following advice, not estimates of a current run.
Actual results may fall outside the ranges. No campaign or calibrated model
supports them; neither the 50% nor 75% qualification gate has passed.

The filtered column assumes a pair that fits the challenge and that both Souls
are taken. Triboulet benefits face-card builds, Chicot removes boss interference,
Yorick needs discards, Perkeo needs consumables, and Canio needs destruction.
Medusa and Golden Needle in particular cannot treat all pairs as equivalent.
On a Knife's Edge still needs careful Dagger sacrifice management; its estimate
is deliberately not raised much. Future milestones compare each column to
its own previous estimate instead of counting the opening advantage again.

| Challenge | Ordinary random start | Useful targeted two-Legendary start |
|---|---:|---:|
| The Omelette | 20–45% | 35–60% |
| 15 Minute City | 25–55% | 40–65% |
| Rich get Richer | 30–60% | 45–70% |
| On a Knife's Edge | 5–25% | 10–30% |
| X-ray Vision | 25–55% | 40–65% |
| Mad World | 25–50% | 35–60% |
| Luxury Tax | 20–45% | 35–60% |
| Non-Perishable | 20–45% | 35–60% |
| Medusa | 20–50% | 30–55% |
| Double or Nothing | 5–25% | 20–40% |
| Typecast | 5–25% | 20–40% |
| Inflation | 20–45% | 30–55% |
| Bram Poker | 10–35% | 30–55% |
| Fragile | 0–15% | 5–25% |
| Monolith | 5–25% | 15–35% |
| Blast Off | 20–45% | 35–60% |
| Five-Card Draw | 20–45% | 30–55% |
| Golden Needle | 0–15% | 10–25% |
| Cruelty | 15–35% | 30–50% |
| Jokerless | 0–15% | Unsupported |

## Evidence and limitations

- A real detached Photograph/Hanging Chad test improves the same play from
  1,700 to 5,600 chips solely by ordering; plain Glass/Mult ordering improves
  a Straight from 600 to 800. No played subset or held-card slot changes.
- Copy tests cover targets, chains, loops, compatibility, pins, own editions
  and equivalent-row fairness. Shop comparisons remain within the shared
  50,000-score cap and discard all tactical adjustments if a complete decision
  cannot fit. Late-hand capacity is conditional, not a predicted probability.
- Native first-opening tests and the original game source agree on all nineteen
  supported challenge definitions. Fixture I1L21111 produces Yorick then Perkeo
  through two actual Soul uses; actual Egg sales free Omelette slots. Jokerless
  bans remain and vanilla suppression without the exception is separately tested.
  These are 21 short source-generation cases, not 21 completed runs.
- One balanced-CPU search returned a valid Any/Any opening in 1.85 ms, stopping
  early within a one-million-candidate cap. DLL loading is excluded. This is
  one timing observation, not a general search-time guarantee.
- The advisor's source engine adapter and heuristics still have important
  long-term and uncertain-effect limitations. No GPU training or large win-rate
  simulation campaign was used. No game window, save or live run was controlled.

## Installation

Installed **2026-09-10 15:02:27 America/Chicago**, version **2.16.0-alpha**.
All **21 Lua files plus the versioned native DLL** match repository hashes.
The existing native DLL was retained. The update activates on the next normal
game restart; no game process or window was controlled.

Configuration SHA-256 before and after:
`08C40F7C6C989F842718323FA6A76CE3F8FB0D0E386C254604EBC1D7D03565C6`.
Backup and full per-file manifest:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260910-150227/deployment.json`.
Native DLL SHA-256:
`34598478571391D272C1E1A837832061BD767A09AB552BB61EF3458E24E9D751`.

Validation: **28/28 Lua fixtures**, **15/15 Python protocol tests**, native API
and Soul regressions, 21 original-source opening-generation cases, and
`git diff --check`. Notable checks: hand ordering 251, boss rescue 160,
copy shop 43, paid reroll 46, opening logic/UI 70/29, runtime 210. The final
runtime extension verifies HUD/panel/action agreement and duplicate-click
protection for both new action types.

A bounded ordinary-start source-engine development probe on Omelette seed
ADVISOR6 resolved 20 actions in 19.87 seconds, with four deterministic play
scores matching source results: 16, 280, 15 and 724. It intentionally stopped
after opening a Celestial pack after the Big Blind. It was not a terminal run,
did not use the filtered opening, and is not win-rate evidence. Its loaded
development digest precedes final review edits; see the retained trace and
[engine report](engine_probe_report.md).
