#420 review disposition

One substantive read-only review and one focused recheck by the same reviewer
are complete. No additional review cycle was started. Reviewer ran no tests or
gameplay. The initial findings led to complete inventory-endpoint comparison and
budget/source controls documented in REPORT.md.

Focused review identified a compact Death-anchor resource defect: playing a Gold
or Blue-seal card originally held by the baseline finish could lose that held
reward. The implementation now preserves those physical held cards using mapped
indices after reordering. A new fixture verifies the baseline clear and refusal;
review_regression.lua proves exact candidate2 fails specifically this assertion.
The existing positive Mult-to-Pair five-card-discard fixture still passes.

The focused reviewer accepted that correction, conditional work accounting and
the smaller-anchor explanation. Final disposition: no remaining blocker in the
reviewed420 scope; review allocation exhausted.

The user's later Ante5–6 spending threshold, Burnt valuation, bounded pre-discard
fishing and copy-arrangement/restoration changes are
explicitly outside the reviewer's disposition. They have independent manufactured
boundary/production regressions and share the combined exact full validation.
Do not represent those late additions as independently reviewed.
