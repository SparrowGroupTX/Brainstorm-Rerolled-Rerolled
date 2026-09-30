# Marathon repairs366

Installed **2.166.0-alpha**,2026-09-22T23:40:12.4992551-05:00.
Backup:`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260922-234011`.
Policy digest:`9d5dd16effe8b929e831be2e7d57bfd9e3200f96f404de1c46ca2939f2d3352e`.
All89 deployment/105 runtime-dependency files match. Current settings and all
seven DLLs preserved. Normal user restart activates; no game control occurred.

The user requested repeated seeds, remaining hard stops, unused stock and early
discards together after the latest ten-start audit. That expands the implementation
scope, not experiment or preservation authority. Latest actual evidence remains
loaded2.165,3 wins/5 losses/2 unsupported over10 starts; no2.166 activation or
win improvement is demonstrated.

## Delivered behavior

- `Core/collection_search_product.lua`: the old in-memory wall-time cursor could
  restart before the same sparse matches. A separate mod-owned
  `brainstorm_collection_cursor_v1.txt` persists progress outside journals,
  settings and player saves. Verify a reservation before dispatch and advance
  beyond a found match before publishing it. Fresh installation spreads initial
  wall time across the seed domain; later progress is monotonic without wrap.
  Invalid storage fails closed, never silently resets. This is seed progression,
  not an experiment lease, exhaustive coverage or extra run allowance. No old
  historical seed blacklist is invented, so absence of every possible historical
  duplicate is not guaranteed. This fixes restart-driven repetition.
- `Advisor/acorn_ordering.lua`: high-dimensional120..720-world beliefs whose
  exhaustive play family exceeds the ordinary cap use at most64 deterministic
  visible-card candidates, balanced by play size. Every candidate sees **every
  public world**; unsupported cells still reject the family. Diagnostics disclose
  `all_legal_subsets=false`. No hidden order recovery, world-prefix truncation,
  extra budget or claim of exhaustive action optimality. The manufactured
  six-Joker/nine-card case completes64×720=46,080 scores instead of refusing
  the381×720 exhaustive family. Future discards/consumables remain unplanned.
- `Advisor/decision.lua:mouth_cycle`: after no scoring or supported resource
  action, a visible locked Mouth hand with zero discards, spare hands and a
  nonempty deck can play a zero-score cycle. Two bounded probes verify exact
  Mouth rejection and otherwise supported scoring. It retains visible pairs
  when cycling singles; no future draw or win is predicted. Ordinary scorer
  legality is unchanged. Unknown effects, insufficient allowance or no spare
  hand still reject this fallback.
- `Advisor/strategy.lua`: teacher-only stock utility accounts for remaining
  unenhanced population, enhancement target capacity, cash/horizon reserve and
  redundant suit-conversion stock outside Flush plans. It evaluates the complete
  random copying pool with nonlinear small-pool Polya enumeration. A shop
  use/hold/supported-sale comparison can consume profitable duplicated money
  cards or surplus main-hand planets, or sell weak saturated stock. Negative
  capacity is removed with the card; matching Observatory planets and useful
  sole templates remain protected. Every action refreshes. No selected Perkeo
  source is invented. Collection-mode arithmetic remains exactly unchanged.
- `Advisor/growth.lua`: teacher Ante1–3 Yorick at x4 or below values partial
  progress at120 instead of80 in both single/pair comparisons. This explicit
  heuristic preference encourages safe early investment; physical counters,
  twelve-score cap,105% supported retained clear and all population/order/boss/
  cash/interest/Blue/Gold/Glass/horizon protections remain unchanged. It does not
  mandate discarding every card or exhaust mature/final-boss discards.

## Validation and retained limitations

Candidate2 **238 Lua fixtures/391 Python tests passed** (39.109s/13.625s).
Exact installed **238 Lua/391 Python passed** (38.047s/13.141s). Frozen policy and
tests unchanged in both gates;60-second suite bounds retained. First candidate's
exact legacy inventory equality failure is preserved and superseded by the
passing corrected candidate. No assertions were weakened: restored original
non-saturated floating arithmetic ordering fixed the difference.

New manufactured fixture: `tests/advisor_marathon_repairs366.lua`,92,909 checks,
including independent all-world/candidate accounting, refusal cases, input
immutability, Negative/Observatory/template and production shop-routing checks.
Collection-product fixture now193 checks (restart progression, corrupt storage,
write failures); growth-copy fixture92 checks includes early safe preference and
maturity/Ante/margin counterexamples. Other existing growth, population, search,
fallback, inventory and execution suites pass.

Evidence: `development366/REVIEW.md`, starting bytes and `runtime.diff`, raw
targeted logs, preservation receipts; `runs/marathon366_candidate2/validation`,
`runs/marathon366_installed/record.json` and policy,
`runs/marathon366_installed_validation`, and final verification receipt.
Review is primary-only; no extra agents or experimental workers. No captured
policy/scorer evaluation, source execution, seed search, simulation, training,
automation, log purge or save/profile access. A single passive public schema
check establishes that shop population cards render face down; it was not scored.

This does not solve every unknown-mechanics stop, jointly optimize full boss
continuations, force all surplus Tarot types to sell, or prove a stronger win
rate. Stock cleanup supports selected known cards/planets; generators and large
approximate pools remain limited. It does not assume overwriting valuable
enhancements. The existing teacher button still explicitly clears logs when the
user chooses it; its separate seed cursor is not reset. No new batch is pending.
