# P01: comparison restored, first Pillar action unchanged

The read-only audit passes57 checks. Exact receipts and hashes are in
`P01_audit.json` (SHA256
`988a3fe7c13fea1c721b6858f25a77f5d3c3c8b0d0c52bb6449c73f0247bdfa7`).

P01 evaluated frozen2.127 and2.129 once each on the exact redacted public state
at sequence2722. Both select the same recorded discard: indices3,7,8,9, retaining
the active Purple7S at index4. The baseline reports the blanket Purple-generation
blocker and no remaining-blind comparison. Candidate completes eight common worlds
over all four remaining hands. Its incumbent discard clears five of those worlds;
playing the current Full House clears three. The candidate therefore retains the
discard, and its original one-draw discard evidence is unchanged.

The eight sample outcomes are conditional composition evidence, not calibrated
win probabilities. No later discard is searched by this comparison. This job
evaluates only the captured first Pillar discard; it neither replays later actions
nor rescues the observed592/600 terminal loss.

Actual and reported scores agree: baseline71701, candidate91318, aggregate163019.
Each remains below140000; the candidate spends19617 additional calls. The root
worker completed and was reaped in3.219000000040978 seconds under its shared30-second
cap. Frozen inputs, complete policies, external runtime files, registration and
trace hashes still match. Inputs remain unchanged and retries are disabled.

Both full results are preserved in
`runs/loss328_validation_20260915/P01/baseline_result.json` and
`candidate_result.json`; compact summaries omit diagnostic rows explicitly and
reference those exact files. The public hand, deck, normal-opening and objective
fields are present. `shop_forecast` is absent and remains absent; this is a hand
decision, and no hidden shop context is reconstructed.

The initial read-only audit incorrectly expected40 raw wiring connection entries.
The frozen verifier actually returns49 module-path entries and34 explicit identity
connections. `audit_p01_failed1.py` and `P01_audit_failed1.json` preserve that audit
tool error. The corrected audit checks the exact receipt shape. Neither audit
executes policy/source code, changes original evidence or consumes a new job.
