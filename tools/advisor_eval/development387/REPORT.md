# 387 — frozen 2.185 Yorick discard-comparison candidate

The installed checkpoint is 2.184.0-alpha (`SESSION_RESET_386.json`), with
92 deployment and 108 runtime/dependency hashes matched before editing;
current settings and seven native DLLs were unchanged. The repository now has
an **uninstalled 2.185.0-alpha candidate**. The user-started 2.184 batch was
still in progress at the captured prefix; its completion has not been audited.
No installed or running product bytes were changed in this slice.

`capture/manifest.json` freezes only completed public segments 1–7 of
`session-20260925T190519Z-1`: 7,143 consecutive events, loaded public label
2.184, 1,043 win-first profile observations, one verified win, one verified
loss, and a third start with no terminal event by sequence 7,143. The writable
tail was excluded. A public label is not an exact loaded-byte attestation.
`analysis/loaded_2184_prefix.json` and `loaded_2183_complete.json` are passive
action indexes built without policy/scorer replay. The 2.184 prefix has 38
requested hand plays with discards remaining and 56 sub-five-card discards;
the completed 2.183 cohort has 148 and 219 respectively. These counts do
**not** certify that all alternative discards would have been safe.

At public advice/action sequences 6063/6066 and 6519/6522, the advisor
reported 14/14 sampled redraw clears but selected a known clear. The second
was Ante 5 Small with three discards, a nine-card hand and a reported minimum
84,075 versus 25,000 target. Search required 24 matched samples and its
ordinary 16-candidate shortlist did not reserve enough budget for them.
Other prefix receipts include legitimate tight margins, resource cards,
unknown bosses and draw-sensitive Raised Fist/Shoot the Moon scoring. No
captured alternative was rescored, and the policy change is not claimed to
rescue these exact games.

The candidate changes five runtime files: `Advisor/{search,decision,
player_journal}.lua`, `Core/Brainstorm.lua` and `steamodded_compat.lua`.
For a win-first known clear, `search.lua` narrows only its discard shortlist to
fit at least 24 complete common-world rounds, including an uncertain-score
floor, Hook resolution, existing continuation reservation and a 12-score
growth allowance. If 24 rounds cannot fit under the existing 140,000 or a
smaller caller cap, the certain play remains. The risk comparison now tests
each complete candidate against the unchanged sampled-survival, supported
late 105% floor, physical Yorick, neutral-resource, cash/population and
horizon requirements. Among individually qualified candidates with the best
sampled survival it favors more physical discard cards. Continuation uses
that actual candidate as its prior and cannot override a known clear with an
uncertified different discard. Final public receipt fields are stamped even
when continuation vetoes risk through the early clear return. The independent
read-only review found an above-24 caller-sample budget edge; it was fixed
before freezing. Raised Fist/Shoot the Moon guards remain.

`tests/advisor_yorick_discard382.lua` now has **153 manufactured checks**.
New cases cover nine-card/default-16 comparison, 48 requested samples with
uncertain floors, Hook plus floor accounting, a short ordinary leader masking
a separately qualified five-card option, a late five-card 105% floor versus
shorter subfloor row, continuation prior and play veto, public receipts and
smaller-budget fallback. All are invented states, not captured-state replay.
The exact frozen candidate is `runs/yorick387_candidate/`: digest
`bf09ad12fcd2327850d02c0e6dd8c308f952c93c26e8f3341aeaa9ccd99fb1b2`;
108 runtime/dependency files, 295 test files. Its full gate passed **255 Lua
fixtures and 392 Python tests** with unchanged policy/test hashes. Raw logs
and `validation/report.json` are preserved there. This demonstrates a local
coverage correction, not increased full-run win rate.

The user's newer reports of a missed Blueprint, early Rental/Eternal commons,
suboptimal pack rentals, excess cash, consecutive Hanged Man uses, stale suit
Tarots, Strength/Death saturation and rank-hand preference remain separate
shop/consumable/deck questions. Their exact current-batch offer/action
receipts have not been audited. The 2.184 Blueprint-vs-unopened-pack rule
excludes Rental copies (`strategy.lua:best_shop_purchase`), and its
`protected_core` replacement guard also excludes owned Rental copies. This
is a source-level lead, not proof of the newly reported pass-up's cause.
The user estimates Death/Strength usefulness often drops after about 8–12
best-card/rank copies; this is a hypothesis, not a universal hard cap.

No new game run, process control, save/profile access, captured-state
policy/scorer evaluation, hidden search, training, schedule, log purge or
budget renewal occurred. Keep the frozen policy and current user batch
separate. After the user confirms normal batch end, verify installed baseline,
settings and native hashes, install only the five explicit changed files via
`install_slice.py` with backup, then freeze and validate exact installed
bytes. Installation alone does not establish activation or gameplay benefit.
