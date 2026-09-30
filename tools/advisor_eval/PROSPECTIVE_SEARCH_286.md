# Fixed search measurement after 286 — ready for approval, not authorized

The runnable scope is **four serial jobs, each at most15 seconds, with a
60-second outer execution deadline**. This search-only proposal supersedes
the scheduling of D in `PROSPECTIVE_EVAL_286.md`; it neither authorizes nor
funds A/B/C. The broader captured-state/source-mechanics/complete-attempt
proposal remains unapproved and its additional harnesses remain unready.
All historical quotas remain closed. Registered, reserved and consumed are
currently zero.

The question is whether frozen286 preserves frozen285's supported opening
results on identical work while reducing measured search computation. This
is not a Jokerless win-rate test or a validation of opening affordability,
Blue retention or survival.

| Order | Policy | Target | Inclusive start | Exclusive end |
| --- | --- | --- | ---: | ---: |
| D1 | frozen285 | Mars / Four of a Kind | 11,123,177 | 11,223,177 |
| D2 | exact-installed286 | Mars / Four of a Kind | 11,123,177 | 11,223,177 |
| D3 | exact-installed286 | Jupiter / Flush | 11,223,177 | 11,323,177 |
| D4 | frozen285 | Jupiter / Flush | 11,223,177 | 11,323,177 |

Each job requests exactly100,000 indices:400,000 policy-index evaluations over
200,000 unique new indices. Paired policies intentionally share their range.
The last preserved search ended at11,123,177; its earlier censored tail is also
excluded. The JSON binds both coverage receipts. An intervening search that
uses these intervals requires a revised proposal before execution.

Use the same preserved synthetic `all_unlocked_discovered_v1` catalog and
criteria: Coupon, target Planet, Telescope, at least two eligible Blue choices
and at least one Blue Steel card. This is a static catalog comparison. No
source executable/ZIP, live game, save, native seed-search DLL, installation
or setting is read or changed. Only after approval does the runner verify and
copy the historically identified `lua51.dll` into the new evidence directory
for isolated Lua execution. It never launches Balatro.exe. It reads no saves.

The new `fixed_search_comparison.py` / `.lua` runner is independent of the
closed historical executors. It freezes only the approved two search modules,
canonical preserved catalog, its own code and the isolated Lua runtime. Full
recorded policy manifests bind the model files; only the Core search module
is executed. This does not claim that the current full source adapter works
with frozen282. Python executable/version, Lua runtime hash, profile, policy
and catalog identities are recorded separately.

Search calls use fixed batches of at most1,000 indices and a16-match return
cap. After an early match-cap return the next call starts at its exact cursor
and continues within the same100,000-index job. There is no rescanning or
extra job. Completed batches are flushed to a journal. Ordered match/recipe
digests are compared over the full common work; if either job stops early,
only its proven common prefix can be compared. The unreported tail remains
unknown. Errors, unsupported results, timeouts and not-started jobs are retained.
No replacement, fifth worker, extra warm-up, target change or new seed range
is authorized.

Per-job wall timing starts before launch setup. Process creation and setup
subtract from its original15-second deadline. The parent kills a timed-out
worker; operating-system creation/termination cleanup cannot be guaranteed
instantaneous, so any observed overshoot is recorded and further admission
stops. The60-second outer deadline includes coordinator overhead. If a full
15-second job no longer fits, it is marked not started and remaining capacity
closes. Earlier fast jobs do not increase any later job's15-second limit.

The principal timing is the observed end-to-end job wall time, including
startup and result processing. The Lua `os.clock` search-call intervals are
also recorded, explicitly without claiming portable CPU-only semantics.
An observed wall ratio is shown only for a completed identical100,000-index
comparison with identical ordered recipes. One serial timing per policy/target
supports no timing confidence interval or general speedup claim. Search output
does not become a seed recommendation or a complete-attempt input automatically.

## Concrete admission and evidence

`PROSPECTIVE_SEARCH_286.json` contains the exact approved-input candidate,
including installed286 policy digest, baseline285 record/model bytes, catalog
record/digest, runner hashes and copied historical runtime identity. Preparing
it involved only repository records/code and preserved JSON, with no DLL or
executable read. Runtime identity is checked freshly only after approval.

After the user's explicit approval, create a fresh authority JSON with kind
`fixed_search286_authority`, status `APPROVED`, `approved_by: user`, the exact
proposal SHA256, a fresh authority ID, the user's approval reference, a UTC
expiry, one absolute new ledger directory, `max_workers:4`, `worker_seconds:15`
and `total_seconds:60`. It is not created by this proposal. The ledger directory
is bound by that authority; copying the same authority to another location
does not provide another ledger or allowance.

The two user-authorized commands will be:

```text
python -B tools/advisor_eval/fixed_search_comparison.py register --authority <fresh-approved-authority.json> --proposal tools/advisor_eval/PROSPECTIVE_SEARCH_286.json
python -B tools/advisor_eval/fixed_search_comparison.py run --ledger <the-same-authority-bound-ledger>
```

Registration verifies fresh runtime bytes and all approved inputs before
creating immutable one-use registrations. Execution requires those unchanged
registrations, an active parent PID and original absolute worker deadline.
Exclusive batch/worker markers prevent reruns. A failed launch remains spent;
the worker CLI cannot be used later to bypass its parent deadline. On errors,
retain the valid prefix and close all remaining slots. Changed inputs or
additional experiments require a new concrete proposal and approval.

Synthetic tests are kept under
`runs/fixed_search286_development/test_fixed_search_comparison.py`, with fresh
logs and hash receipts in that directory. They mock process execution and
runtime access; they exercise no real seed scan and load no Lua DLL. The Lua
driver itself has been reviewed, not executed during these Python tests.
The installed runtime's earlier118Lua/275Python regression evidence remains
unchanged and separate from these tooling checks.

No verified complete Jokerless win or numerical win odds are established.
This request grants no original-source component, full attempt, calibration,
training, scheduled continuation or access to the running game.

A separate routine Lua fixture subsequently exercised the driver with an injected search stub, fake clock and captured output: 10 checks passed in `runs/fixed_search286_driver_development/focused2/report.json`. It loaded the isolated Lua runtime for this authorized synthetic fixture only; it loaded no opening model, performed no seed scan and used no original source, game or saves. The earlier focused1 fixture used the obsolete timing-field name and failed; that evidence remains preserved. The corrected fixture and both receipts are separate from any future search worker. The final Python mock suite passes 18 tests; its superseding receipt is `runs/fixed_search286_development/synthetic_20260913T211256560894Z/record.json`.
