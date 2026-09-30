# 384 — loaded-2.180 ten-start diagnosis and installed 2.182 repair

The exact public journal is frozen under `logs1/manifest.json` (24 BRJ2
segments, 41,958,389 bytes). `capture/manifest.json` verifies 18,179
consecutive records, 2026-09-25T14:47:23Z–15:28:39Z, no gaps or decode errors.
The loaded *label* is 2.180.0-alpha in 16,033 events; all 2,775 recorded
teacher snapshots name `perkeo_yorick_win_v1`. A label is not loaded-byte
attestation. `capture/summary.json` and the compact `actions.json`,
`rounds.json`, `runs.json`, `diagnostic.json` preserve the passive projection.
No captured state was run through a policy/scorer; no game, save, hidden RNG,
seed search, training job or complete simulation was controlled or executed.

Ten starts used ten distinct observed seeds: **one verified win, eight losses,
one unsupported retirement**. This is operational yield 1/10 starts, not a
calibrated win rate. The unsupported run reached Ante 8 Amber Acorn; it is
not counted as a loss. Run 4 used Hanged Man 16 times; its physical deck
reached 13 cards before its Ante 7 Wall loss. Run 3 chose an ordinary-slot Eternal
Polychrome Business Card in its first Buffoon Pack at action 3339; the
advisor's sampled opening rose only 125→188 against the next 600 target,
while its income was explicitly unprojected. Across 59 Ante≥4 cleared rounds
with unused discards, 47 cleared in one play. These counts are opportunity
screens, not proof each unused discard was safe. There were 62 shop exits
above $50 (23 above $100) and only one reroll in the cohort; every such
high-cash exit had five Jokers. The existing development-reroll receipt
reported `baseline_not_sampled_safe` for 47, even though that status also
includes unresolved whole-blind coverage. The stock observations include
off-target Planet types and 33 Hanged Man uses; target suitability and
available alternatives require per-observation assessment.

At run 10 sequence 18141, the public five-Joker row was Perkeo, Yorick,
Arrowhead, Eternal Red Card, Brainstorm. Amber Acorn's concealed order was
fully represented by 120 public worlds before action 18159, which settled
at 18170. Advice 18174 then rejected the row as “Current public inventory
abilities are not qualified” and auto-run retired unsupported at 18177.
Static inspection of the installed Balatro 1.0.1o archive, without executing
it, verified Arrowhead's fixed extra 50 and Red Card's fixed extra 3; Red
Card's Mult changes on booster skip, not play/discard. This is a narrower
five-Joker continuation gap than the existing seven-Joker Acorn boundary.

Version 2.182.0-alpha addresses the supported classes:

- Win-first late Yorick may choose a neutral discard through Ante 8 / X8
  when 24 complete common draw worlds clear after the exact physical
  transition. Ante≥6 additionally needs a *supported score floor* at least
  105% of the target in every world. Cash, population, held effects, boss
  and budget exclusions remain. This is not a calibrated win probability.
- Ordinary-slot Eternal Business Card without Pareidolia is rejected in the
  win-first objective, including a Polychrome copy. A Negative slot or
  already-owned active Pareidolia differs.
- Truly surplus cash can fund a bounded paid reroll if a source-supported
  ordinary Joker has a legal replacement witness and positive retained-build
  heuristic, while reserving next-blind costs, interest and a purchase. The
  newly revealed shop is reconsidered; no hit, score or win is assumed.
  Cash-scaling rows, unreplaceable full rows, special shops, escalating fees
  and insufficient catalog support remain excluded. This does not impose an
  unconditional $50 ceiling.
- Win-first off-target Planet copy value falls to a small option value; the
  whole-inventory Perkeo manager can sell a diluting source while retaining
  useful target Planets and Negative/Observatory behavior. If Death is held
  with no strong public copy source, adequate cash can justify inspecting a
  visible Standard or Spectral pack; unknown contents receive no identity
  credit. Pack choice is reassessed when revealed. This is a narrow link,
  not a complete long-horizon deck/pack planner.
- Hanged Man cannot reduce win-first physical deck size below 28. Its Perkeo
  copy value/capacity expires at that floor, and exhausted stock can be sold.
- Amber Acorn's public transition accepts only the exact observed stable
  Arrowhead and Red Card ability shapes. Unknown fields, actions and seven-
  Joker coverage still fail closed; the 120 public worlds remain intact.

The previously frozen 2.181 64x event-cadence candidate is incorporated
unchanged in 2.182; it was never installed separately. Source one-pass and
REAL-clock safeguards and its prior read-only review remain, but a real
wall-time improvement has not been measured.

Manufactured fixtures cover positive and negative boundaries, including
the review-found uncertain-mean/score-floor and additive cash-reserve
counterexamples. A read-only reviewer found those two risks; both were fixed
before freeze. `runs/win384_candidate/{freeze.json,validation/}` and
`runs/win384_installed_validation/` each passed **254 Lua fixtures and 392
Python tests** with unchanged frozen policy/test hashes. Installed
2026-09-25T11:35:56.0108851-05:00 with backup
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260925-113555`.
`runs/win384_installed/record.json` and `runs/win384_final/final_verification.json`
verify all 92 deployment and 108 runtime/dependency files, current config
and all seven native DLLs. Policy digest:
`71a50538faf9af0c0208244165ae466b9ebc55a28cff4b9a930b5c5f50d14a6d`.
The game was absent at installation; no game process was controlled.
Activation awaits a normal user restart. There is no 2.182 real-game
outcome or demonstrated win-rate gain.
