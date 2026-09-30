# Repair410 — spend discards before clearing

Repository2.197.0-alpha is frozen at `runs/repair410_candidate1`, fully validated
and **not installed**. Digest `72fbb82a3191cd61e69a73b2eccfaf5a8ba39d34fc6697ae3de7f6bea3cdae91`. Six changed runtime files,109 total
runtime dependencies and321 declared test files are bound to the freeze.
Full gate:275 Lua fixtures and458 Python tests pass with unchanged runtime,
test and helper provenance. Installed runtime remains exact409 2.196.

The user revised an absolute rule to a strong preference with rare exceptions
and a below1% observed target. That preference supersedes historical wording that
unused discards are merely qualitative hypotheses. No observed rate is claimed.

The supported cause is reproducible without captured games: the previous clear
path could reject discards because it required105% of the target, positive growth
merit, a qualifying Yorick/Burnt/Death engine or future development horizon.
The manufactured before fixture fails the requested discard behavior.

Changes:

- Teacher clear paths request bounded discard exhaustion before optional stored
  development. A supported post-discard floor reaching100% is sufficient; generic
  profile behavior and ordinary optional-growth thresholds remain unchanged.
- Low/negative heuristic merit, mature distant Yorick growth and final-Boss
  horizon no longer veto a supported retained-clear discard. Each real draw
  requires fresh advice. A maximum spare discard wins equal-utility ties.
- Up to six singleton probes can free cards from an unnecessarily large clearing
  hand, within the same12-call allowance. They use a subset of the original play
  and preserve Glass, Arm, population-cost and supported finish-reward checks.
- A final guard follows phase-copy and retry arbitration and uses actual action
  indices. It respects the existing retry restrictions and one shared work
  allowance, including smaller caller caps and the70-call fast path.
- Public receipts distinguish selected discards, nonfinishing plays and explicit
  exceptions, including exact charged work. The panel explains remaining-discards
  exceptions, and Execute uses the same selected action/indices.

The new policy fixture passes57 checks; actual capture/presentation/Execute adds
13 checks (runtime total830). Positive cases cover all three remaining discards,
final Boss, exact target, empty deck, no growth engine and mature Yorick. Negative
controls cover ordinary profile, Green/Banner/Ramen score loss, paid current cash,
forced Bell selection, unsupported Purple generation, sole clearing card,
retry constraints, hidden/public worlds and caller budgets. Gold/Blue and Steel
retention and input determinism are exercised. See REVIEW.md and raw logs for
all initial failures, fixture corrections and the three focused-review repairs.

Limits: this does not force a discard that loses the supported clear. Acorn and
concealed-card paths have explicit public-model coverage exceptions, not proof
that finishing early is strategically correct. Other draw hazards, unavailable
mechanics, failed bounded candidates and exhausted work are also visible gaps.
A future cohort must adjudicate them; exception labels do not make them acceptable
or establish a rate below1%. The Yorick sale work from409 remains unpatched.

Measurement: count physically settled round-clearing plays in the teacher profile;
report the fraction whose linked pre-play public state had positive discards.
Also report rounds that began with usable discards separately from zero-discard
blinds. Join final receipts to the settled actions, categorize every numerator
event, retain unsupported/censored runs and show numerator/denominator. Claims of
below1% require loaded-game evidence and adequate coverage, not these fixtures.

No game control, active-journal read, installed/config/DLL change, save/profile
access, captured-state policy/scorer execution, experiment or cap increase.
Preservation:436 backed files, earlier409 local artifacts and all old git status
paths verified. Candidate remains uninstalled during user play. A later release
requires current normal-exit confirmation, passive absence, newer-public-journal
preservation/classification, exact preflight, backed explicit six-file install
and separate exact-installed freeze/full gate. Installation is not activation.
