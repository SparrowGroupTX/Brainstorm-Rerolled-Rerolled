# Analysis revisions and diagnostic failures

Raw captures and earlier artifacts were preserved throughout.

* `deep_audit.py`/`deep/` initially checked Death confirmation only against the
  next hand. A chosen final pack card closes the pack and can empty that view.
  `deep_audit_v2.py`/`deep2/` checks the same owned physical recipient in public
  `playing_cards`, confirming both transformations. The first zero count was an
  analysis limitation, not evidence of runtime failure. `deep2/` is authoritative.
* `manufactured_pack_attempt1.lua` omitted the complete-finishing dependency.
  Its assertion failed; the preserved `manufactured_pack_probe.lua`/log revealed
  opening-only positive adjustment and `choose`. Wiring the actual finishing
  module/dependencies reproduced the hypothesized complete-progress cost penalty.
  `manufactured_pack_attempt2.lua`/log retain that5-check reproduction. The final
  fixture adds three causal assertions requested by the focused reviewer;8 pass.
  These are invented inputs with pure production modules, not captured replay.
* Ad hoc descriptive inspection outputs occasionally exceeded tool output limits
  or met Lua empty-table-as-object cases. The authoritative JSON files and index
  remain complete. No count relies on truncated console output. The formal
  capture/index/link verification reports have no integrity failures.

No runtime repair or pass claim is based on a failed diagnostic attempt.

The first final-verification attempt used collapsed untracked directories in
`git status --short`, against the initial exhaustive file listing. Its set
comparison failed. The preserved attempt1 script/log records this verifier
configuration error. Matching `--untracked-files=all` at both ends verifies the
existing entries rather than confusing collapsed display with missing files.
