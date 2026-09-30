# 388 — late surplus cash and rejection visibility

**Outcome:** repository candidate 2.186.0-alpha is frozen and full-candidate-
validated, but not installed. Installed checkpoint and public loaded label are
2.184.0-alpha; exact loaded bytes are not attested. The ongoing user-started
batch has not been confirmed complete. This candidate incorporates the
previously validated, uninstalled 2.185 Yorick comparison.

Passive evidence: `capture/manifest.json` fixes completed public segments
8–20 of `session-20260925T190519Z-1`, sequences 7144–18531, 10,064 events,
all reported 2.184, with 1,697 win-first profile observations. The writable
segment 21 was excluded. Segments 1–7 were already frozen in
`development387/capture/manifest.json`. At this cutoff the combined public
prefix has eight starts: three wins, three losses and two unsupported stops.
That is not a completed ten-start outcome or a 2.186 test.

`analysis/cash_shops.json` extracts 281 shop advice receipts from the new
segments. Twelve shop leaves had at least $100. At observation 18281, Ante 8
had $147, a $5 reroll and a full row with legal-looking expendable Jokers;
advice 18285 chose `leave_shop`, request 18287 settled, and the next blind
observation 18292 retained $147. The record's hashes and segment ordinals are
in the compact index. The development receipt said
`baseline_not_sampled_safe`, but `player_journal.lua:compact_reroll_review`
masked the separate surplus rejection. `public_snapshot` intentionally strips
the forecast. Therefore this establishes a high-cash leave, not its exact
live surplus rejection reason. One run with many high-cash leaves won; high
cash is not by itself a certified cause of a loss.

Source inspection found a fixed 0.005 supported first-slot chance threshold,
$12 refresh cap, additional $60/$25 trigger cushion, and a separate genuine
cash reserve in `strategy.lua:surplus_reroll`. A rare Blueprint-only source
chance can be below that fixed chance threshold even with ample unused cash.
The manufacturing fixture reproduces this *class*, not the captured $147
state. The implemented Ante 6–8 rule uses any positive source-supported
first-slot upgrade chance, permits a $20 maximum single refresh, and spends
only cash above the actual liquidity reserve plus interest floor and $12
purchase capacity. It still requires a known, affordable, legal gain of at
least 26 after purchase penalty and a replaceable full-row victim. The
advisor pays for one offer then reobserves; a hit is never promised and the
rule makes no score/survival claim. Earlier antes retain their old gates.
This is deliberately an aggressive late reserve-floor policy; repeated misses
can use the cash above that floor, bounded by actual funds and fee cap.

The compact journal now preserves separate scalar development and surplus
statuses, selected action/mode, cash after the **reroll only**, cost cap,
interest/survival/purchase reserves, candidate counts and admitted chance.
Funded/admitted counts are candidate-victim endpoints, not unique source
entries. No catalog, private scored world or hidden card enters the public
receipt. An independent read-only reviewer and focused recheck found no
reserve breach or leak; it identified this deliberate aggressive scope and a
count-label issue, which was clarified before freezing.

`tests/advisor_proactive_reroll371.lua` has 75 manufactured checks, including
diluted rare opportunity, early/late and $12/$20 fee boundaries, exact reserve
and one-dollar shortfall, successive charged misses, protected full rows,
unknown catalogs, fallback, deterministic input/RNG and redaction. Seven
targeted related Lua fixtures passed. Frozen full gate:
`runs/cash388_candidate/freeze.json` digest
`eb996950e48a9ee1685aca6c63c84f540db5a1d2a54fa204e32cc796e9c58cda`;
108 runtime/dependency and 295 test hashes. `validation/report.json` and raw
logs attest 255 Lua fixtures/392 Python tests passed with unchanged frozen
hashes. No captured state was passed to policy/scorer. This is a local
decision-policy and observability correction, not a demonstrated full-run gain.

No game process was controlled, no installed/config/native bytes were changed,
and no saves/profiles, hidden seeds, training, scheduled job or closed
experiment budget were used. Preserve all public journals. After the user's
normal batch completion and exit, verify installed 2.184, settings, seven
DLLs and candidate/test bytes before explicit-file installation, backup and
exact-installed validation. Installation alone will not prove activation.
