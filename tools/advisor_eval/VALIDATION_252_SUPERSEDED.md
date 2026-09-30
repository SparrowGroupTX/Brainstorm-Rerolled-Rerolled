# Registered 2.52 build validation — superseded policy

Completed 2026-09-10. The parent task subsequently identified and corrected
blind-start setup legality and paired-population correlation issues for2.53.
These retained results belong to frozen2.52. They are NOT validation of2.53,
even though the selected ordinary Golden Needle rows lacked Dagger/Marble.
No experiment was rerun or extended after the corrections.

Artifacts: `runs/roi252_registered_validation/registration.json` and `report.json`.
The registration froze all requests before execution: one15s source-prefix cap,
two40s selected replay caps, two40s unseen holdout caps,175s total requested cap.
Whole workflow finished157.895s. Original traces, registrations, source/adapter
freezes, elapsed costs and every unresolved outcome remain preserved.

| Provenance | SHA256 digest |
|---|---|
| Incumbent2.46 | 8dfb1955a4ced9491eaba8bdc0960b3edb66076bd888cb27d758f8946beee102 |
| Candidate2.52 | c44d81bd84e7c6f83ec8c1e72be8463173140ef59713fb6370b9f3139ab61f8c |
| Frozen adapter | af7611b872e7a2f515b4a0c6639818e62927398f397296002f5ade8e61ada2a7 |

Candidate source was `runs/development252_installed/policy`; complete product,
rules/runtime and file manifests are retained beneath the validation directory.
All source work used hidden bounded isolated lua51.dll workers. Balatro.exe was
read only as ZIP. No game process/window, user save or setting was touched.

## Selected earlier build decision

The fresh2.46 source prefix on ordinary ADVISORCOVERAGE332 completed its seven-
action limit in3.723s and was deliberately censored. The current adapter had
changed, so the earlier old-adapter trace was not reused across incompatible
provenance. `source/source_record.json` records this exact fresh producing run.

`replay/decision_report.json` retains both full bounded continuations from step7:

| Policy | Outcome | Wall time | Last observed progress |
|---|---|---:|---|
|2.46 | Loss |31.017s | Ante2 Small,608 chips short,30 actions |
|2.52 | **Timeout** |40.027s |65 actions resolved; entered Ante4 Boss/Arm, computing decision66 |

Both verified all six earlier actions and captured step7 at the identical
canonical source-state fingerprint. The existing report's `matched_checkpoint`
is nevertheless false because its completion gate excludes any timed-out
attempt, including one that reached the checkpoint. This false field remains
untouched; explicit prefix/state equality is distinguishable from completed
pair evidence. The candidate timeout is not converted to a win or loss.

At step7,2.46 leaves the $9 shop.2.52 buys Mercury for$3 and displays a complete
visible Mercury→Runner→use-Mercury plan, with mean opening score237→278 against
target450. Only the first action is published. Actual later refreshes change
the plan: it rerolls twice, purchases the actual **Holographic Misprint** for$7
and Banner for$5, and leaves at-$17 under its Credit Card debt facility. It never
acquires Runner on this final-policy path. The stronger retained row clears
the old failure point and multiple later blinds, but remains nonterminal.

The specific Holographic offer matters: its+10 Mult supports reliable immediate
score floors despite Misprint's random base Mult. The new prospective catalog
model credited no premium-edition mass, so this was an observed favorable
outcome, not an assumed guaranteed reroll result. Neither acquisition nor later
progress proves a terminal win or an aggregate return from rerolling.

## Unseen ordinary holdout

ROI251HOLDOUT1 was preregistered without examining its outcome. Despite the seed
label, the policies actually compared were frozen2.46 and2.52. Both use ordinary
unfiltered Golden Needle starts. `holdout/report.json` records two valid audited
trace records with no provenance/parse audit errors, and these unresolved results:

| Policy | Outcome | Wall time | Last observed progress |
|---|---|---:|---|
|2.46 | **Timeout** |40.022s |45 actions resolved; entered Ante2 Boss, computing46 |
|2.52 | **Timeout** |40.023s |32 actions resolved; Ante2 Big, computing33 |

The first16 actions match. At step17,2.46 leaves the shop;2.52 buys Juggler for$4,
increasing its hand size to9. The candidate later records completed hand
decisions with roughly112k–127k score calls and3.35–4.02s CPU durations. It makes
less observed progress before the same40s cap. These changed states and single
attempts do not prove a general performance regression or eventual loss, but
they do **not** support a time-adjusted improvement. They expose the cost of
larger hands as a concrete priority for subsequent profiling/decision valuation.

Both timeout traces lack the profile record that the adapter emits at normal
exit. The audit explicitly keeps `nonterminal_or_invalid_attempts` and
`unlock_profile_mismatch_or_missing` blockers along with unqualified adapter,
development-seed and unmeasured-live-action-time blockers. No elapsed attempt,
missing completion or profile-at-kill limitation was dropped to improve results.

## Interpretation

Across this registration: one intentional source censor, one loss, and three
timeouts; no terminal win. Selected earlier-decision progress improved in2.52,
while the unseen holdout progressed less before its time cap. There is no
measured win-rate gain, successful coefficient calibration, qualified challenge
rate, or revised numeric forecast. Runtime coefficients remain unchanged.
No result is imputed to2.53; final regression/source verification belongs to the
parent task's separate current checkpoint.
