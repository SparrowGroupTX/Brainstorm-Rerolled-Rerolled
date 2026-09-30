# Release 379 candidate: independent manual observations and timing coverage

2026-09-24. Baseline is installed 2.177.0-alpha, with activation unconfirmed.
The latest frozen ten-start cohort has public loaded label 2.175 and two
verified wins/eight verified losses; its 20% operational yield is selected,
not a calibrated rate or evidence about the 2.177 policy. A separate new
marathon is user-started and in progress. Its files, process, settings, search
recipe and installed runtime are outside this candidate's inspection or edits.

The user requested durable human-play trajectories, retaining the latest ten
verified manual wins and latest ten verified manual losses independently of
the auto-run clear control, with separate 10 GiB storage allowances. They
also asked when RL training becomes worthwhile and for further speed work.
No training, new tool-started run, game control or experiment is in this slice.

## Behavioral acceptance fixed before release

1. Manual play records linked, redacted public observations, available advice,
   actual callback requests/results and explicit terminal evidence even when
   the old auto/legacy logging toggle or advisor is off. Auto-owned GAME
   objects, including a finished batch's last GAME, never become manual runs.
   A checkpoint/new GAME or profile replacement ends an unverified trace and
   starts a distinct one; identical seeds are not merged.
2. Only an original successful `win_game` callback tied to observed final
   boss threshold/saved evidence gives a manual win. GAME_OVER gives a loss.
   `GAME.won` alone, a result UI label, advice, an interrupted run or an
   errored recorder does not. Once verified, one GAME cannot be counted twice.
   All other runs remain incomplete/unknown rather than becoming losses.
3. Auto v1/v2 logs share their own 10 GiB cap; manual v1 logs have a separate
   10 GiB cap. Each manual run has separate BRJ2 segments and a readback
   verified, hashed completion receipt. After a new completed run, prune whole
   older verified runs only past ten per outcome. Unknown, malformed, changed
   and incomplete files are preserved and count against capacity. A full cap
   stops recording explicitly; it cannot promise both 20 huge runs and an
   absolute cap. The auto clear control never touches manual files.
4. Retain the existing teacher ten-start/action/time/search/inactivity bounds,
   journal event/frame/segment bounds, redaction, hash-chain and append
   readback protections. Publish bounded five-second `performance_window`
   events to future automatic journals so the already-written offline timing
   reader can split game update, draw, journal and frame intervals. This is
   measurement, not a demonstrated animation or wall-time speedup.
5. Manufactured fixtures cover namespace/cap isolation, 11+11 interleaved
   terminals, incomplete/auto-owned games, no double counting, original
   callback notification, retention corruption and auto clear. Full frozen
   candidate validation is required. Installation and exact-installed gate
   wait until the user reports the active marathon complete; installation
   still requires their normal restart to activate.

## Current candidate

Repository code labels 2.178.0-alpha. The manual recorder lives in
`Brainstorm/Advisor/manual_run_log.lua`; it shares the existing BRJ2 encoder
and callback hook chain rather than installing a second terminal wrapper.
`player_log_archive.lua` uses closed literal auto/manual namespaces. The
manual completion receipt is a bounded `MR1` text record listing exact owned
segment names, sizes and SHA-256 digests. Receipt/segment mutation blocks
retention. Pruning first writes and verifies an exact receipt-backed marker;
an interrupted deletion leaves a stopped recorder and a recoverable marker,
never silent reclassification. The UI says that Clear auto logs
retains manual runs. Manual logging defaults on in memory and has its own
settings toggle; no installed config or save was touched.

The prior passive timing audit (`../development372/PERFORMANCE_AUDIT.md`)
measured 516.321 s active advisor decision time (19.8%), 747.705 s between
decision resumes, 1,140.198 s post-callback to settled public state outside
decision (43.8%), and 200.033 s unassigned in ten loaded-label-2.169 runs.
The largest identified action subclass was 280 plays with 655.681 s of
post-callback interval. Those intervals mix animation, update/render,
settlement and journal work; there were zero frame performance windows.
The next speed decision should use the newly emitted windows and explicit
game-speed/FPS provenance before changing REAL timers or input debounce.
Existing 128x/256x choices and one-pass event cadence do not scale REAL
timers or guarantee a 2x run speedup at low rendered FPS.

For learning, public trajectories are useful now for schema/coverage checks,
behavior cloning and contrasting human/heuristic choices. They are not expert
labels or enough to justify promoting offline RL. The 355 GPU prototype was
rejected and its simulator is not qualified for retail outcomes; all 355
budgets remain closed. Losses remain valuable labeled failures, while
unsupported/interrupted or unsettled transitions are censored. A future
training proposal must freeze representation, split by whole run/seed family,
establish simulator fidelity and complete outcome accounting, then seek fresh
bounded authorization and compare on separately user-started real games.
The requested trailing 10+10 manual retention and auto-log clearing keep a
diagnostic window, not a cumulative RL corpus. Any later training dataset
would need an explicitly frozen, provenance-preserving export before clearing;
none is created here. Human actions also carry versioned advice exposure and
are not assumed stationary or optimal when the advisor changes.

## Candidate validation and review

The final 2.178.0-alpha repository candidate is frozen at
`../runs/manual379_candidate2/freeze.json`, policy SHA-256 digest
`44080aeca408432d1b3761ab33835e793aad7904b2fbbd32467c4c21d021c347`.
The manifest contains 108 runtime/dependency files; 12 differ from installed
release 378, including the new manual module, UI, journal/archive integration,
single passive terminal listener and version labels. `freeze.py` asserts the
exact set. The full candidate gate at
`../runs/manual379_candidate2/validation/report.json` passed **250 Lua
fixtures and 392 Python tests**, with unchanged frozen policy and test hashes.
The new manual fixture has 71 manufactured checks, including 11 interleaved
wins/losses, same-GAME auto cancellation, duplicated completion ownership and
automatic recovery on a new manual recording after an interrupted prune. The
earlier passing `manual379_candidate/` freeze is preserved and superseded by
the startup-recovery addition; its bytes are not the candidate for release.
The independent read-only review
and one focused recheck identified duplicate segment ownership, canceled
startup reclassification and interrupted-prune recovery; the candidate and
fixture address all three. No captured game state was evaluated.

This is **not installed**. Installed 2.177, current settings, seven DLLs and
the user-started active marathon were not changed. No exact-installed gate
or activation/full-run speed/win-rate claim exists. After the user confirms
the marathon is over, verify frozen repository bytes, use `install_slice.py`
with only the 12 explicit files and a backup, then freeze and validate exact
installed bytes. A later normal user restart activates the changed runtime.

## Later release update — 2026-09-24

The user exited the interrupted marathon. Its frozen audit exposed two
additional Amber Acorn/retirement defects; see `../development380/SCOPE.md`
and `../win_rate_research/20260924_132921_interrupted/REPORT.md`. Candidate2
above remains preserved as passing historical evidence, but its pending
installation instruction is superseded. Release 380 installed all 12 of
these files together with the two narrow repairs as 2.178.0-alpha, backed up
the preceding installed files, and passed the full exact-installed gate.
See `../SESSION_RESET_380.md`; activation still awaits normal user restart.
