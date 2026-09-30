# Passive auto-run stop audit — 348

This audit reads only a bounded prefix of the existing observation journal. It does not execute the advisor, replay a state, simulate a run, search seeds, read saves/profile data or control the game. Original journals remain unchanged. The final segment was append-active; this report makes claims only through the frozen prefix ending at sequence 1895, `2026-09-16T06:14:22Z`.

## Evidence

- Session: `session-20260916T060145Z-1`; four frozen segments, 5,490,634 bytes, 1,895 decoded events, no decode errors.
- Loaded version: `Brainstorm v2.147.0-alpha` in all 1,397 versioned events.
- `passive_audit.json` SHA-256: `532092c5bc654205c655d7e0fd123b8135393422acbab81026facff6ced194a7`.
- `summary.json` SHA-256: `a455d274186a524877a2b2b1e6725707f3bdc3f2194b5aaa8dfd5aa3270408e2`.
- `summary.json` binds individual original paths, frozen byte-prefix hashes, decoded-event and stored-frame anchors. Exact reconstructed public events 1851, 1853 and 1854 are preserved separately.

## Latest run stopped; it did not reach a terminal result

Run `YVYN2Z11` (`game:3`) starts at sequence 1020, `06:07:54Z`. After 159 automatic actions, sequence 1854 at `06:10:58Z` records `session_stopped`, reason `log_unavailable`, detail `Controller data must be plain finite values.` The current state is Ante 6, round 16, inside a Celestial pack, with $58. No terminal result for this run occurs in the captured prefix.

The last completed automatic action opens a $6 Jumbo Celestial Pack. Sequence 1853 records advice to choose Black Hole with zero score evaluations. No subsequent choose request appears. The 41 later events are performance windows with auto-run and advisor worker inactive; the game continues producing frames. This is an auto-run stop, rather than evidence of a game freeze or a failed Black Hole action.

The 16 held consumables comprise twelve Temperance, two Moon and two Sun, fourteen Negative, with inventory limit 16 and buffer 0. All sixteen held Tarot source certificates are supported. The constructor-certificate repairs are active in this run.

## Strong source-supported explanation, with an observational limit

The last successful raw fingerprint length is 258,571 bytes (sequences 1849–1850), only 3,573 below the controller clone's 262,144-byte string bound. The maximum successfully logged length in this session is 259,274 bytes. The controller emits the observed-action record with raw fingerprints and clones that record before the product logging callback hashes its fingerprints. An oversized string raises the same generic error text as a nonfinite value.

The timing and near-limit lengths strongly support an oversized post-pack fingerprint as the cause. The failed record was never emitted, so the exact rejected fingerprint length is **not directly observed**. The saved public snapshot's JSON byte count is not the runtime fingerprint length and must not be substituted for it. No nonfinite card value is established by this error.

## Earlier terminal result and repeated setup

The earlier run `M4BVSY11` has a verified loss at sequence 1011, `06:07:54Z`: Ante 6, round 17, Serpent, 112,910/120,000 chips, zero hands and discards. It used 185 actions over 360.9945756 seconds. The session has one verified loss, zero verified wins and zero confirmed new Gold stickers; the latest run remains unfinished.

Both observed native searches request the same opening targets: Yorick and Perkeo in the opening Soul pack, Brainstorm interchangeable with Blueprint by Ante 5, and Burnt Joker by Ante 5. Each asks for one distinct missing Joker between Antes 5 and 8. The two starts advance from cursor `Y9ZG4Y11` to `N4BVSY11` within this session. These observed searches are user-started product work, not experiments executed by this audit. They neither establish survival/acquisition nor justify treating previously inspected seeds as unseen holdouts.

At the stop, the held Joker row is Caino, Yorick, Eternal Cartomancer, Negative Perkeo, Eternal Devious Joker, Brainstorm; all are already Gold. This is direct inventory evidence. Whether a particular earlier purchase was strategically justified requires inspecting its contemporaneous decision context, not inferring intent from the final row alone.

## Separate earlier-session and pack-choice supplement

`supplemental.json` (SHA-256 `deb2d6b44c4dae38b0ffa5edfa2e972072fcfc438d1b32fb9713cc144b90f380`) independently binds four earlier-session prefixes, 5,776,076 bytes, with no decode errors. Session `session-20260916T053031Z-1` records loaded 2.146; the latest session records loaded 2.147. Both searches return exactly `M4BVSY11`, then `YVYN2Z11`. The first cursor differs: earlier `WRXG4Y11`, latest `Y9ZG4Y11`. The second cursor/result pair is identical: `N4BVSY11` to `YVYN2Z11`. Thus the result seed sequence repeats across the two sessions; the full cursor sequence does not. This audit does not independently observe the game restart itself.

The latest session selected Cartomancer from a pack at sequence 1093 (`06:08:14Z`) and Devious Joker from a pack at sequence 1135 (`06:08:24Z`). These are accepted pack choices, not shop Joker purchases. At decision time both are marked Gold complete and Eternal, and both are observed held afterward. Cartomancer is Holographic (+10 Mult); Devious is ordinary. Advice explicitly acknowledges that the Eternal slot is permanent. Cartomancer's explanation emphasizes resources for later rounds; Devious's emphasizes Chips supporting hand levels and Mult. Both choices use strategic ratings after incomplete legal pack comparisons, with `Blind-start Joker changes are left to the existing strategy.` as the scoring-preview limitation. Contemporaneous public alternatives, rows, advice, callbacks and observed outcomes are preserved in the supplement; no counterfactual score or optimality claim is imputed.
