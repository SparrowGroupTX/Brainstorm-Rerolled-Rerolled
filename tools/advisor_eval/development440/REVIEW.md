# Review440

One primary implementer and the same read-only reviewer were used. One
substantive assessment and one focused recheck are now exhausted. The reviewer
ran no tests, captured policies or scorer evaluations.

Design review retained the Bell physical-selection boundary: a discard must
remove the currently forced card and subsequent sampled draws must select their
own forced card. The deterministic retained-card Bell veto was not lifted.
Mixed Glass/Mult sorting cannot be assumed to commute. The repair therefore
uses the existing complete sampled-comparison route with explicit limitations.

The substantive assessment found one blocker in candidate2. Decision's new
larger one-play discard comparison called suggest_portfolio, which could reserve
work for and return a two-play finish. Rejecting that result afterward could hide
an available one-play proposal or starve its proof budget. Candidate3 adds
disable_two_play before generation/reservation; only this new comparison opts out.
The existing general two-play behavior remains covered by retained_two438.

The new admission440 fixture uses the real two-play generator with a controlled
one-play proposal requiring either one or eight calls. It demonstrates both
replacement and budget reservation, then checks that opting out preserves the
one-play proposal and its full allowance. The real Photo/Chad Decision integration
checks that the option is forwarded. arbitration3.log passes2799 admission,
673 unchanged discard_order423 and404 retained_two438 assertions.

Focused recheck: the blocker is resolved; generation and reservation are both
disabled before portfolio selection, reviewed files match candidate3's frozen
manifest, and no remaining blocker was found in this scope. This is not a general
strategy optimality or full-game simulator certification. Candidate3's complete
321-Lua/458-Python gate is independently recorded in its validation directory.

Preserved earlier failures: candidate1's full gate exposed a real regression
where a sampled smaller discard displaced a proven larger retained discard.
The unchanged423 fixture caught it; Decision now checks the retained one-play
portfolio within the same12-call allowance. Legacy417/382/424 expectations were
updated only for deliberate legal sampled Bell, mature/final and Red-seal
admission; forced-card, held-resource, paid-discard, partial-comparison and
continuation-loss negatives remain. Candidate2 passed its gate but was superseded
by the review correction. All candidate freezes and raw logs are retained.

Limits: sampled draws are not guarantees; deterministic retained Bell remains
excluded, last-hand progress is unchanged, and wider Matador triggers and
Lucky-with-Matador rows remain unsupported. Canonical Wild/Lucky are included in
the disposable-card helper but do not each have a new dedicated production
integration fixture. Do not claim that all enhancement families, discard gaps,
the12-card benchmark, or a loaded-game win rate have been verified.
