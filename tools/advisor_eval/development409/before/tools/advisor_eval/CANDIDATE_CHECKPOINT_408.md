# Frozen candidate408 — 2.196.0-alpha

Candidate3 is fully validated and **not installed**. Installed baseline remains
exact2.195 checkpoint404 while the user runs another ten-run session.

| Item | Verified candidate |
| --- | --- |
| Freeze | `runs/repair408_candidate3/freeze.json` |
| Digest | `fef67966a4056cb5028d74022189ac2753c6ce2a6935dc290c316d183029f83c` |
| Runtime / changed paths / tests |109 /11 /320 |
| Full gate |274 Lua fixtures;458 Python tests (447+9+2), all pass |
| Hash checks |Runtime, tests and validation provenance unchanged |
| Review |One substantive and one focused recheck; final narrow finding corrected and verified by primary |
| Preservation |`development408/FINAL_VERIFICATION.json` |
| Superseded evidence |Candidate1 failed Lua; candidate2 passed but precedes final observer normalization; both immutable |

Read development408/REPORT.md, REVIEW.md and NEXT_PRIORITIES_408.md. No loaded
2.196 evidence or causal win-rate claim exists. Audit407 remains four verified
wins/four losses/two nonterminal retirements across ten loaded-label2.195 starts.

Release only after the latest session completes and its normal exit is explicitly
confirmed. Check process absence passively; preserve and classify newer journals;
verify candidate/runtime/test/helper hashes, current installed baseline/settings
and all seven DLLs. Install with install_slice.py version2.196.0-alpha and the
eleven explicit paths in this freeze's changed_runtime_files (strip Brainstorm/).
Keep the backup, freeze exact installed bytes and run all installed gates. The
previous normal-exit confirmations do not apply to this current session.
No game control, saves/profile access, captured policy replay or new experiment.
