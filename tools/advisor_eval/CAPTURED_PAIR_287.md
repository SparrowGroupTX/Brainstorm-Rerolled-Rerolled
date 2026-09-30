# Bounded preserved-snapshot pair driver

`captured_snapshot_pair.py` and `.lua` evaluate one frozen public hand snapshot
under exactly two separately isolated policies. They do not enter the original
source dispatcher, execute game actions, load a save, use retry memory or create
a terminal outcome. These selected development states are not unseen holdouts.

The parent authority fixes A1–A4, their original snapshot and historical receipt
hashes, frozen282/frozen286 identities and policy order. Each pair allows two
15-second policy workers within a 60-second parent process cap. Root orchestration
must impose that 60-second outer cap; the driver separately enforces each worker's
15 seconds and admits a worker only while its full cap fits. No retries or
replacement outputs are allowed. Preparation claims a one-use reservation in the
authority's fixed ledger, so another output directory cannot renew a spent job.

Preparation validates and embeds each policy's own Advisor Lua files. Frozen282
cannot acquire the newer `resource_finish` module through a worktree fallback.
Filesystem and native Lua module loaders are disabled before the detached setup.
The reviewed module setup is only the prefix of the current `engine_run.lua`
before its JSON function; setup-boundary checks reject the source dispatcher.
The source game itself is never loaded. Only the authorized isolated `lua51.dll`
is copied into the private frozen inputs.

The actual decision receives no options override. Complete returned decision
data includes common-world outcomes, resource diagnostics, uncertainty and
fallback reasons. Instrumented component calls and times are retained, but
their overhead prevents treating the result as uninstrumented product latency.
Both input fingerprints and original file hashes are checked for mutation.

A separately registered model audit checks selected play/discard indices,
remaining hands/discards and required cards. A play receives at most one extra
ordinary score call after the decision; its counter is separate from the product
score count and its diagnostics do not contaminate component timings. Other
action kinds retain unsupported audit status. This is modeled action legality,
not source-selected-action qualification or a source counterfactual.

Synthetic validation: 13 Python protocol tests and 11 Lua driver checks passed.
The initial Lua fixture had one missing closing brace in its stub decision;
compilation failed before driver execution. That failure remains recorded in
`runs/captured287_development/fixture_report.json`. No captured-state decision
was executed by these fixtures.

Fresh A-job registrations and immutable child freezes are under
`runs/diagnostic287_20260913_222344/`. A child registration is preparation evidence,
not a successful evaluation; consult its later `execution_started.json`, worker
logs and `report.json` for actual status. Timeout, error, unsupported and
not-started outcomes must remain visible. An action change is not by itself an
improvement, rescued blind or win.
