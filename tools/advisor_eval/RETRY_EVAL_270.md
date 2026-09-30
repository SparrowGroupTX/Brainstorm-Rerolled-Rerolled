# Manual checkpoint retry: evaluator boundary, 2.70

The runtime's user-reported checkpoint feature is **not evaluated** by the
current source dispatcher. Frozen product presence does not establish activation:
`engine_run.lua` constructs detached decision modules without runtime/UI hooks,
persistent retry journals, manual SaveManager restoration or retry history.
No user journal, settings or saves are read or written by this evaluator change.

New paired registrations use manifest schema2 and bind `retry_context_spec` plus
its canonical SHA256 digest. The only supported specification is:

```json
{"schema":1,"mode":"disabled_clean_attempt_v1","journal_access":"none","checkpoint_restore":"unsupported","initial_memory":"empty","max_checkpoint_reloads":0,"retry_advice_evaluated":false}
```

The host provenance declares it. The Lua source dispatcher independently emits
one `engine_probe_retry_context` receipt before episode decisions, with the same
specification/digest, zero observed checkpoint reloads and no qualification.
The auditor requires both declarations to match exactly, including numeric and
boolean types. Missing, duplicate, late or altered receipts, unsupported retry
specifications and checkpoint/retry events are rejected before an outcome enters
a paired comparison. Outcome validation preserves the rejected raw record and
elapsed time as unverified evidence; it does not convert it into a win or loss.

Historical schema1 manifests and traces with no retry metadata remain auditable
as `historical_unreported`. This is an explicit limit, not retrospective proof
that retry support was exercised. Added retry claims on an unbound historical
registration are rejected. Existing frozen directories/registrations/reports are
unchanged. New reports explicitly state that checkpoint restoration, persistent
history and the manual retry policy were not evaluated.
Existing diagnostic retry-overhead scenarios describe restarting failed clean
attempts; they do not account for or establish manual checkpoint retry behavior.

`engine_probe.verified_replay` also verifies the source retry context when one
was declared, and rejects unsupported contexts. Existing frozen source adapter
hash requirements still apply; this change does not authorize replaying any
spent source attempt. Other historical tooling/evidence does not acquire retry
qualification merely because the current product contains retry modules.

A future separately authorized retry-aware experiment would need a different
adapter and prospectively bound context: frozen initial memory and checkpoint
schema, run-lineage/branch IDs, reported versus observed restores, exact public
checkpoint evidence, applied policy history, per-line actions/outcomes and
one-use cap receipts. All branch losses/errors/timeouts/censors and checkpoint,
reload, action, computation and retry costs must remain visible. Branches of one
run are dependent observations, not separate independent successful starts.
Clean attempts, manual checkpoint runs and filtered routes must remain separate.

Validation is limited to bounded Python protocol/unit tests with fresh logs.
`runs/retry_eval270_protocol_20260912_141205` records 220 passing Python tests
in 11.446 seconds under a 30-second hard timeout. A final static Lua receipt
consistency test was then added; all seven focused retry tests passed in
`runs/retry_eval270_receipt_20260912_141326` under a 15-second hard timeout.
The final installed release then passed all 221 Python tests and 97 Lua fixtures
with unchanged frozen bytes, separate 60-second caps, in
`runs/development270_installed_validation`. This remains unit/protocol evidence.
No source worker, full attempt, journal access or save restoration was run.
Current player odds, retry-aware completion time and per-challenge50%/75% remain
unknown. Source profiles remain synthetic and unqualified.
