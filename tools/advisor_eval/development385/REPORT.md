# 385 — high cash survived the truncated-shop fallback

The active user-started batch supplies a **partial**, passive public prefix:
the first six complete BRJ2 segments of `session-20260925T165555Z-1`, 4,020
consecutive records through 2026-09-25T17:05:19Z. Exact original bytes and
hashes are in `logs1/` and `capture/manifest.json`; `capture/{shops,actions}.json`
are compact public projections. The observed label is **2.182.0-alpha** and
all 613 captured teacher snapshots use `perkeo_yorick_win_v1`. This is a
label, not a loaded-byte attestation. The prefix contains two completed
losses; it is not the full batch and says nothing about its eventual yield.
No captured state was run through a policy or scorer, and no game, save,
profile, hidden RNG or seed search was accessed by tools.

Ten shop recommendations in run 1 left with **$71–$178**; all ten were
requested through auto-run and received callback returns. Every one had
`shop_truncated=true`. Three (`1504`, `1920`, `2483`) even carried
`reroll_review.status=admitted` for the new surplus catalog opportunity, yet
the final action was `leave_shop`. In `decision.lua`, the shop comparison
could truncate after the independent admission, then the whole-decision
fallback replaced the candidate with `Strategy.advise` without a scoring
context. Seven other high-cash leaves lacked that admission receipt; their
eligibility is unknown, not zero. The public evidence supports this
arbitration failure, not a claim that every unbought refresh would hit.

Repository candidate **2.183.0-alpha** rechecks only the existing unscored
surplus opportunity after the complete strategic fallback chooses to leave.
The scorer's partial candidates and old reroll receipts are discarded. A
fallback buy, sale, use or other action remains intact. The existing public
catalog witness, additive cash reserve, interest, fee≤$12, cash-scaling,
replacement-slot and unsupported-mechanics gates remain unchanged. Newly
revealed offers require fresh advice. This does not impose a hard $50 ceiling
or promise a winning Joker.

`advisor_proactive_reroll371.lua` has 41 checks, including a real manufactured
500-score exhausted-shop context, exact budget accounting/input preservation,
fallback-purchase priority and negative cash-scaling/unsupported/profile
contrasts. One read-only correctness review found no blocking issue; its
identified real-context test gap was filled before freeze. The frozen
candidate digest is `fc946ea12d0b3b142aa3efb32b62c7ff667179870ea2204a950914e8ce822262`.
`runs/cash385_candidate/validation/` passed **254 Lua fixtures and 392
Python tests**, with unchanged frozen policy and test hashes. The initial
validation command pointed at the candidate container rather than its
`policy/` subdirectory and failed before creating a validation directory;
the corrected command passed. That invocation error was not a test failure.

The game was running during repair, then absent at installation. **2.183
was installed** at 2026-09-25T12:37:04.1335402-05:00 with backup
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260925-123703`.
Fresh pre-install checks matched installed 2.182, candidate bytes/tests,
current config and seven DLLs. `install_slice.py` deployed only four explicit
runtime files. `runs/cash385_installed/record.json` and
`runs/cash385_final/final_verification.json` attest all 92 deployment and
108 runtime/dependency hashes; exact-installed validation passed **254 Lua
fixtures and 392 Python tests** with the same frozen policy/test hashes.
Settings and seven native DLLs were preserved. Installation does not prove
activation; no loaded-2.183 cash use or win-rate effect is demonstrated.
