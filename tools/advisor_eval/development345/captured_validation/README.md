# Prepared public shop comparisons — no workers run

The two snapshots are exact JSON field bytes extracted from the previously
audited public journal. Their old negative Tarot-constructor certificates are
preserved. No registry identity, raw constructor parameters or source certificate
is reconstructed. These comparisons may therefore remain unsupported even if
new manufactured source-shaped capture fixtures pass.

User authorization is exactly the question and reply embedded in
`prepare_registration.py`. Root must review this adapter and invoke registration
only after freezing the final candidate policy. Preparation verifies complete
baseline344/candidate policy manifests, hashes the isolated Lua and Python
runtimes, adapter, exact public input, actual passive profile context, and the
already-preserved card.lua reference. It does not initialize Lua or evaluate a
policy. Registration creates four one-use jobs, B2070/C2070/B2192/C2192, each
reserving 30 seconds and 50,000 shop score calls. Total reserved worker time is
120 seconds. No historical quota is used or renewed.

Root command (fill exact frozen paths):

```
python prepare_registration.py --candidate-record <candidate/record.json> --lua-runtime <isolated/lua51.dll> --ledger <fresh-ledger>
```

After reviewing the frozen registrations, root can invoke the prospectively
hashed `launch_serial.py <ledger>` once. It runs the four jobs serially with
`CREATE_NO_WINDOW`, exclusive spent receipts before process creation, and an outer
30-second watchdog. It preserves raw stdout/stderr, worker results, errors,
timeouts, actual elapsed time including termination overhead, and an immutable
closure. It never retries. Preparation never invokes this launcher.

If root instead supplies its own bounded outer launcher, before launching each
registered command it must atomically create
`<ledger>/<job>/spent.json` with these exact fields and enforce a 30-second outer
process watchdog covering initialization, verification, the policy call and
serialization:

```
{"kind":"gold345_captured_policy_spent","job_id":"B2070","one_use":true,"registration_sha256":"<exact hash>","authority_sha256":"<exact hash>","reserved_seconds":30}
```

Run jobs serially. Preserve outer timeouts, verification errors and partial
outputs; none grant a replacement. `worker_started.json` is exclusive creation,
preventing a second call after a worker has started. Root's immutable spent
receipts cover any earlier verification/launch failure. Finish by writing a
ledger closure and totals; unused capacity stays closed.

Each worker derives its dependency wiring from its own frozen runtime prefix.
Only live filesystem/execution/opening integrations and retry modules are
omitted. Product decision modules and default budgets otherwise remain intact.
Lua filesystem/native loading, RNG, live global state and further dynamic loading
are disabled. One `decision.run` is invoked; no capture, action dispatch, source
gameplay, selected-action rescore or generated inventory refresh occurs.

An instruction deadline is a secondary guard. The root outer watchdog is required.
Each complete result is preserved when representable within 16 MiB; summaries
explicitly count omissions and identify any full-result gap. Input fingerprints
and original file hashes must remain unchanged. None of these results establishes
that an acquisition would win the run or improve a player-population win rate.
