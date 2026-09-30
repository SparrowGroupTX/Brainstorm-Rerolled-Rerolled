# Release 378: qualified copy acquisition and shop admission receipts

2026-09-24. Baseline is installed 2.176.0-alpha, release 377, policy digest
`858b47a6f4c4e4f771952a4656307941fec57066bebf294efdb3da51f745128a`.
The frozen user-started loaded-label-2.175 ten-start cohort is
`../win_rate_research/20260924_032258_ten_start/REPORT.md`: two wins and eight
losses. It is selected diagnostic evidence, not a population win-rate estimate.
Release 377 activation remains unconfirmed. No captured state will be run
through a policy or scorer.

## Observed gap and acceptance before edits

Run 6 action 9566 declined a visible rental Brainstorm after a complete
Smiley-sale comparison: four paired opening worlds, $23 after purchase,
opening ratio 1.476 and net merit +16.22, below the universal 26 threshold.
The run later reached A8 Violet with $125 and no copy, then lost. This is a
specific threshold exposure, not proof that buying would rescue the run.
Run 5's superficially similar copy offer left only $4 and a concealed boss;
run 8's A1 pack offer left $5. Those must not be admitted by this correction.
Run 2 and run 10 lost despite owning copy Jokers, so copy acquisition is only
one barrier to the requested win rate.

One win-first **visible shop replacement** exception may select Blueprint or
Brainstorm with whole-row merit 13–26 when the row has no copy Joker and has
an active, developed, compatible Yorick. It must replace a supported,
noncritical, non-Eternal, non-Negative Joker; leave at least $20, the full
next-blind liquidity reserve and two further rental payments if applicable;
and occur by Ante 5 with at least three antes before the win target. The
existing Joker admission must pass. Reuse the already-computed complete
four-world, known-mechanics, fixed-policy finishing comparison: matching
targets and world IDs, opening ratio at least 1.25, no clear or progress
regression in any world, and a supported clear in all after worlds. A partial
or uncertain comparison never qualifies. Select only the sale and require
fresh advice for the purchase. Other shop/pack/collection rules and the
ordinary 26 threshold remain in force. No extra scorer calls or raised caps.

For each completed visible replacement, record bounded scalar reasons and
finishing eligibility in the existing public receipt. For the optional
durable-engine reroll path, record a bounded reason for rejection/admission
at high-cash no-copy shop exits, including baseline, forecast, liquidity,
complete comparison and expected-utility gates. Do not serialize catalog
lists, state/world assignments or concealed identity. Diagnostics do not
change the reroll decision.

Manufactured fixtures must show a qualifying copy sale, fresh purchase,
low-cash and unsupported controls, no existing-copy/early-undeveloped/
collection controls, all-world guards, bounded evaluation count, unchanged
snapshot, and public diagnostics allowlist. Run focused checks, then frozen
full candidate and exact-installed gates. If they pass, explicitly install
changed runtime files with `install_slice.py`, preserve config/saves and all
seven native DLLs, and verify exact installed hashes. Activation and real-game
win-rate benefit require later user play.

## Delivery — 2026-09-24

`strategy.lua:copy_replacement_exception` implements the bounded shop rule
above. Read-only review found that its first draft could reach the fallback
winner-only comparison when a visible family exceeded six Jokers or three
offers, and could treat Credit Card debt as reserved cash. Both were fixed
before freezing: the exception now requires `complete_family`, finite actual
cash at least the full liquidity reserve, and the extra rental buffer.
`paid_reroll.lua:development_suggest` records bounded rejection/admission
statuses; `player_journal.lua` projects only allowlisted scalars in
`replacement_review` and `reroll_review`. No reroll threshold changed.

`tests/advisor_copy_acquisition378.lua` passed 37 manufactured checks;
`tests/advisor_proactive_reroll371.lua` now passes 24 checks, four covering
public admission receipts. Twelve focused related fixtures passed. Frozen
candidate and exact-installed gates each passed 249 Lua fixtures and 391
Python tests with identical policy/test hashes. Policy digest:
`e2444d6f6aed6d3aba7b3fabe332a515d3b015f79e88fdf6bfea761f4ed803b3`.
`install_slice.py` installed only `Advisor/{strategy,paid_reroll,player_journal}.lua`,
`Core/Brainstorm.lua` and `steamodded_compat.lua` as 2.177.0-alpha at
2026-09-24T00:30:29.4822262-05:00. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260924-003028`.
All 91 deployment and 107 runtime/dependency bytes match repository and
installation; current settings and seven native DLLs were preserved. Exact
gate, receipt and checkpoint references are in `../SESSION_RESET_378.json`
and `../runs/copy378_{candidate,installed,installed_validation,final}/`.
Activation awaits the user's normal restart. No loaded-2.177 game or higher
win-rate result is demonstrated, and no captured state was evaluated.
