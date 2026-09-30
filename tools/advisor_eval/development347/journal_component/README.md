# Compact order-family diagnostics

This staged `player_journal.lua` change only extends the existing current-only
`advice.gold_review` scalar summary. It adds no event, capture, fingerprint,
callback or observation trigger. Source and test copies before the change are
preserved in `before/`; production files were not edited by this component.

Endpoint-array counting is now bounded at128 entries, covering the expanded
acquisition family's maximum127. Sparse, oversized and metatable-bearing arrays
remain omitted. Element payloads are never traversed. The existing scalar type,
integer, finite-number, length and control-character guards remain in force.

New acquisition/retention scalar fields:

- `acquisition_order_rows` / `retention_order_rows`: declared physical order
  family row count, at most6; no row contents copied.
- `acquisition_preflight_*` / `retention_preflight_*`: `complete`, `supported`,
  `fits`, `required_evaluations`, `available_evaluations`, `unique_profiles`.
  Work counts retain the existing nonnegative-integer limit1,000,000,000;
  unique profiles are bounded at128.
- Corresponding `*_expanded_preflight_*`: the same six scalar fields for the
  larger original family when a budget fallback occurred.
- `acquisition_order_fallback`: the existing bounded string;
  `retention_order_budget_fallback`: the existing Boolean.
- `acquisition_arrangement_actions`: selected endpoint's `setup_actions`;
  `retention_arrangement_actions`: retained diagnostic's arrangement count.
  Both accept only integer0 or1.
- `retention_rows`: actually compared retained rows, bounded at6, distinct
  from the original declared family size.

Acquisition already stores its final/current receipt in `order_preflight` and
its expanded attempt in `order_preflight_expanded`. Retention stores the
expanded attempt in `preflight` and its smaller attempt in `fallback_preflight`.
The logger presents that smaller receipt as `retention_preflight_*` and the
original as `retention_expanded_preflight_*`. Without a fallback, the ordinary
retention receipt is current. A malformed fallback is omitted rather than
silently relabeling the original receipt as current. Complete/supported/fits
remain separate Boolean facts: preparation support or an arithmetic fit is
not a completed score comparison or proof of a safe purchase.

No candidate arrays, card IDs/order keys, projected states, profile caches,
certificates, nested receipts or full comparison data enter this summary.
Existing complete passive snapshots and original advice/action fields remain
unchanged. Missing or invalid optional diagnostics cannot stop ordinary logs;
they retain the existing omitted-field count. Stale/computing/unavailable advice
still cannot attach current Gold diagnostics.

`validation_01.json` records the expected old-logger failure against the new
manufactured diagnostic assertion, followed by **4/4 passing fixtures** with
the staged logger:227 Gold-journal checks,25 ordinary journal checks,105 timing
checks and236 journal-reuse checks. The reuse fixture preserves all serialized
event bytes when these optional diagnostics are absent. The expanded valid
summary is under4KiB in its fixture; arbitrary nested diagnostic size does not
affect the summary. Every manufactured action request is asserted to add
exactly one existing journal event. These are local fixtures, not live log
observations or game experiments.

Final staged hashes:

- `Brainstorm/Advisor/player_journal.lua`:
  `97d83097e2f91cd30d34c3c75bc63a635eec97a5ecd9c4b4eedbc93e4cb2215d`.
- `tests/advisor_gold_journal.lua`:
  `6b0d035ea643bc15244460478abc904da7e81185d21da96547b0797ce4298687`.
- Before runtime:
  `e4374657c4d84dce1350ea4631e1bf0cdfde73d575e0ba3e5286b9a5a34a6ffd`.

Inputs remained unchanged during both validations. The expected-before check
took0.125seconds and the candidate suite0.14000000001396984seconds, each under
its60-second fixture cap. These timings are not a live performance benchmark.
