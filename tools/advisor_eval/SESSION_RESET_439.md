# Closed experiment439: twenty targeted continuations

The discard benchmark is NOT met. Frozen candidate2.217 completed17 of20 modeled
rounds. These17 averaged2.8824 discard actions and11.1765 cards per round,
3.8776 cards per discard.190 cards against216 required;49/54 discards used.
Eleven of17 individual complete rounds reached their card-count target.

| Completed subset | Rounds | Discards/round | Cards/round | Required cards/round |
|---|---:|---:|---:|---:|
| Three available discards |14|2.9286|11.8571|12|
| Four available discards |3|2.6667|8|16|
| All complete rounds |17|2.8824|11.1765|12.7059|

Three additional attempts reached a supported clearing score floor after three
five-card discards each, but final Matador earnings/resource transitions were
unsupported. Their45 cards/9 discards remain separate censored-prefix evidence.
Across all20 attempts, known prefixes total235 cards/58 discards (11.75/2.90 per
attempt), not a validated20-complete-round average. Entire cohort target252 cards
(12.6 per round). No timeouts/errors/action-cap cases; no jobs replaced or retried.

Concrete findings from frozen receipts:

* Run3 round23, Cerulean Bell: zero of4 discards, then clear. Growth refused draw
  changes to finishing conditions. The adapter now models Bell's forced-card
  refill, but the runtime retained-clear policy still blocks this family.
* Run4 round23, Verdant Leaf:5+4 cards, then clear with1 discard. A scoring-card
  order guard stopped growth admission. This is a public-model gap.
* Run5 round16: all4 discards used but only3+2+1+2=8 cards. Larger candidates
  were present; risk admission rejected them on progress and, for five-card
  candidates, survival/margin criteria. Separate short-action valuation problem;
  simply counting remaining discards would miss it. No claim larger actions
  have been proved safe or that relaxing every guard would improve win-rate.
* Earlier round shortfalls9 and8 cards used all3 actions. Their sampled survival
  refusals need a different diagnosis from zero-discard automatic-clear blocks.

The user's subsequently reported zero-discard clear is independently confirmed
in the preserved later public prefix: run6 round12, Ante5 Small Blind,32,320/
25,000, one Flush, zero of3 discards. Observation16439 -> advice16441 -> request
16444 -> callback16445 -> settled round16449/link16451. Photograph/Hanging Chad
with a9-card hand and two Glass cards hit the scoring-trigger order guard. That
guard remains in2.217; the narrow Blue/Yorick two-play repair does not cover it.
See reported_round/REPORT.md, TRACE.json and source events. It was not inserted
into the experiment or evaluated as a21st case.

Passive archived comparison accounts for all20 actual source rounds through
request/callback/settled counter changes:57 discards/224 cards, averages2.85
actions and11.20 cards. These loaded2.216 source outcomes include19 round clears
and1 round loss. This is descriptive only: simulated2.217 worlds differ from the
actual draws; neither causal policy improvement nor full-game win rate follows.

Scope/provenance: user authorized20 new round continuations.85 eligible openings
from five available runs; balanced quotas2/5/5/4/4 and evenly spaced chronological
selection, before evaluation. One fixed SHA-derived hypothetical world per case.
Candidate digest `46786a7789363b6bd32554e78f717ec0eabdd6a56530f341e24ec804eaaed62d`; exact74 modules, helpers,
wiring, Lua runtime, Python, cases/jobs and scripts bound in manifest.json. No
original game-source execution or private live draw order. No selected Acorn or
Heart coverage. Round rewards, economy and future shops are not simulated.

Validation: reused unchanged438 full gate319 Lua/458 Python,110 runtime/370 tests;
six manufactured runner controls, five accounting/seed controls, one invented
preflight. Reviewer assessment and focused recheck exhausted. Exactly20 exclusive
parent/job/worker registrations consumed. Four low-priority workers;40seconds/job,
16actions/job,800 reserved child seconds/600 overall cap. Actual wall time
16.25s; summed child wall time56.78s. CLOSED, remaining
authority0; no resumption. No policy tuning or runtime change after results.

Installed437/2.216 remains exact; candidate438/2.217 remains UNINSTALLED. Config,
seven DLLs, all18838 prior artifact hashes and before-copies verified.
Both public captures verified; game remains user-controlled. No normal exit was
inferred. Historical experiments remain closed. Next coherent repair should
address the proven sorting/Bell admission gap, then qualify targeted manufactured
cases; new captured experiments require fresh prospective authority and limits.
