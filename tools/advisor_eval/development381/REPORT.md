# 381 public choice audit and bounded shop correction

The source is the previously frozen redacted public journal at
`../win_rate_research/20260924_132921_interrupted/capture/`. The compact
arithmetic reader/output are `public_choice_audit.py` and
`public_choice_audit.json`; they never load policy, scorer, game source or
saved games. The public label was 2.175, profile
`perkeo_yorick_win_v1`, and capture ended at sequence 13,931. Six starts
include two verified wins, one loss, two unsupported stops and one incomplete
controller-error stop. The release 380 installed receipt is not evidence that
2.178 was loaded in that session.

Run 2 (`FQ7ZJDXV`, observed-game:14) bought a rental Blueprint at action
2912, then sold **Perkeo**, not Blueprint, at action 2923 for a five-round
Perishable Swashbuckler. Advice 2920 and its complete replacement receipt
compared all five owned-sale endpoints for that one offer over four paired
worlds. It selected Perkeo at merit 94.598, opening ratio 1.6615 and $25
after purchase. An eligible Throwback sale had merit 49.278, ratio 1.7408
and $18 after purchase. Both ratios share the same original row/target; the
second offered a stronger sampled opening while retaining Perkeo, Yorick and
Blueprint. The heuristic merit does not model a future Perkeo copy when the
current consumable pool is empty. The run later lost, but the unobserved
alternative is not a proven rescue. An earlier Yorick sale at action 2777
raised the four-sample opening estimate from 1,301 to 3,685 against The
Club's 2,000 target; a survival need remains a plausible explanation.

Across 82 cleared Ante-1–5 rounds, 130 discards remained (54 rounds with at
least one). In 46 such rounds with Yorick, 109 remained. These are
opportunities to investigate, **not** 109 proven safe growth actions. Examples
with surplus scoring still have specific proof issues: run 5's Ante-3 Psychic
clear at action 9640 used two Glass cards, whose scoring order can change;
run 3's Ante-5 Big clear at action 4826 had Raised Fist, Lucky/Mult cards and
an order-sensitive held score. Other clears had margins below the existing
105% growth requirement or too few spare cards. Growth rejection reasons are
not in this journal projection, so the eligible missed-growth count is
unknown. `growth.lua:drawn_hazard/accept` retains the established safeguards.

The frozen prefix has 14 visible Joker sale actions and **no Blueprint sale**.
It has 117 current `reorder_jokers` actions with paired action attempts and
callback returns; 37 stale order recommendations are marked stale. The
reviewer found no clear current wrong copy target. Shop placement copied
Perkeo (for example advice 13218), while hand placement copied Yorick (for
example 13386/13500/13736). A distinct, actual wrong-order example would be
needed before changing ordering policy. These public checks do not establish
the exact loaded bytes or optimality of every reorder.

Release 381 makes one bounded decision change: `strategy.lua` reuses the
complete eligible one-sale/one-buy endpoint family to prefer a non-engine
seller of the *same* Perishable offer if its common-world opening mean and
clear count are no worse, and any complete paired finishing comparison also
does not regress. It protects Yorick/Perkeo and non-rental Blueprint/Brainstorm
from this specific short-lived swap. It does not force discards or alter phase
copy ordering, search breadth, score caps or other shop graphs. The bounded
public replacement receipt now records compared opening scalars and a
substitution reason. The read-only review found no concrete defect after
the full guards were added; `advisor_engine_retention381.lua` covers the
qualified case, weaker/different/mismatched worlds, finishing regression,
copy alternative, objective isolation, determinism and unchanged score calls.

Installed 2.179.0-alpha at 2026-09-24T11:40:52.0422715-05:00 from four
explicit runtime files. Full frozen candidate and exact-installed gates each
passed 251 Lua fixtures and 392 Python tests with matching frozen hashes.
All 92 deployment and 108 runtime/dependency files match; settings and seven
native DLLs were preserved. Digest
`92bd817059146bd36f86238c2880c1ec3f8436dd55c7e3b7e70650f8be3d1c68`;
backup `deployment-backups/advisor-20260924-114051`;
`../SESSION_RESET_381.json` and `../runs/engine381_final/final_verification.json`
hold exact receipts. Balatro was not running during installation; a normal
user restart is still needed to observe activation. No real-game benefit of
2.179, safer new discard rate, or corrected specific historical run is claimed.
