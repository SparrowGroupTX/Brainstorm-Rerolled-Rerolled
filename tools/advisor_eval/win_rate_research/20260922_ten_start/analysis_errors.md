# Audit tooling errors retained — 2026-09-22

No game error is inferred from these analysis-command errors. Frozen journal decoding
and the existing teacher converter completed without errors.

* Several targeted `rg` calls supplied a wildcard in a Windows path argument
  (`source*.py`, `research*`, `Brainstorm/Advisor/*.lua`) and returned filename syntax
  error123. Follow-up searches used directory arguments and `-g` filters. Two guessed
  source filenames (`search_core.lua`, `recommendation.lua`, plus concealed_future.lua)
  did not exist; actual modules were located with targeted directory searches.
* An ad-hoc summary of final Joker abilities failed with
  `AttributeError: 'NoneType' object has no attribute 'get'` for redacted Acorn cards.
  It was corrected to preserve unknown abilities as unknown. No identities were
  filled from later observations or internal fingerprints.
* One multi-file documentation patch failed expected-line verification in
  REPAIR_SPEC.md. Inspection confirmed the earlier REPORT hunk was also not applied;
  both were then applied with correct contexts. No runtime file was involved.
* A terminal-detail console request was too verbose and truncated its displayed
  output. Full extracted data remains in actions.json/deep_dive.json; subsequent
  summaries selected only relevant fields. No original evidence was discarded.
