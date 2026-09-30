# Release 326 independent review

No concrete defect found in the reviewed change from installed 325.

Both recorder paths use the requested 1,073,741,824-byte allowance. The archive still counts v1, v2, unknown names and partial files together; it checks the cap before appending. Event, frame, segment, file-count and session bounds remain intact. Existing storage is never automatically removed by this runtime change.

The frame hook labels only a known main-menu stage without active, busy or resuming auto-run, legacy reroll or native search as idle. The performance collector suppresses only periodic emission there, retains bounded aggregates and calls its opt-out check before suppression. Returning activity still follows the normal five-second emission interval. Explicit journal actions remain independent.

The shortened popup points to persistent recording details. Viewing those details neither clears the sticky error nor computes advice or selects a stale action. Long tokens paginate and valid UTF-8 boundaries survive display truncation. The underlying original error remains retained.

Focused validation passed five Lua fixtures with 1,203 checks and all 17 archive Python tests. The fixtures exercise idle suppression/resumption/opt-out, active-search exemptions, exact lower/upper storage-bound behavior using synthetic metadata, underlying error retention, read-only menus, pagination and UTF-8. Exact reviewed file hashes and commands are in report.json.

No external files or player-log contents were read by this reviewer. No live game action or experiment was performed. The original transient popup is not verified, and no live speed improvement or loaded-version activation is claimed. The repository cleanup receipt confirms root reported 53 removals from the two owned log directories; this review did not repeat deletion or independently enumerate those external directories.
