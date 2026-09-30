# Release 325 finalizer inputs

Use `objective.md`, `priorities.md` and `architecture.md` as the finalizer's note inputs, and `context.json` as its experiment context. `AUTO_RESUME_325.md` is a new component note in `tools/advisor_eval/`. These inputs do not write current START, HANDOFF, RESUME, checkpoint navigation or installation.

The context uses `counts_scope=historical_closed_cycle`, status CLOSED and all-zero release counts. Original counts, outcomes, authority and closure hashes are unchanged. The limits record carries prior release-324 validation and passive public-log references in explicitly historical fields; this release reads no new external log. Product Resume authorizing a replacement search is separate from closed tool experiment authority.

`validation.json` records successful schema, reference-hash and emitted-accounting checks using read-only finalizer helpers. No finalizer main or regression suite was run while preparing these notes. `INPUT_MANIFEST.json` binds final input and component-note bytes. Final candidate and exact-installed results belong to root's generated records; the earlier failed full candidate and fixture failures remain preserved.
