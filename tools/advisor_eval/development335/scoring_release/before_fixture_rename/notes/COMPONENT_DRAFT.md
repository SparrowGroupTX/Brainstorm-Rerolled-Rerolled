# Exact scoring work reuse — 336

`scoring.lua` reuses five private immutable lookup tables, skips the lowest-held
card scan when the row has no active Raised Fist, and returns explicit numeric
nominal values without eagerly calculating an unused rank fallback. If nominal
is nonnumeric, rank is calculated once. Every complete scoring call remains.

The enhancement and blind lookup precedence and each suit iteration order are
unchanged. Numeric nominal zero, NaN and infinities retain their original
behavior. `c.nominal or base.nominal` chooses exactly the same input, including
false and nonnumeric values. No new card, state, population or result cache is
introduced, so each call reads the current input.

Raised Fist is the only consumer of the lowest-held result. Flags and copy
routes share the same name resolver; a resolved Fist implies its nondebuffed
source appears in the row flags. The original scan and equal-low-rank tie
order remain when the flag is present. Direct, copied, chained, debuffed,
incompatible, cyclic, unknown and overridden-name routes are covered.

The manufactured fixture compares complete score outputs, floor/ceiling and
unsupported guards, ordered transition cards/states/creation, input integrity,
held inventory editions and Observatory order, Lucky events and Glass loss.
Same-card and same-row input changes are checked with raw scoring and fresh
prepared scopes; the preexisting classification cache remains immutable within
a decision. No scoring budget, sampled world, selected action or population
quantity is removed by this slice.

Final manufactured evidence is
`development335/scoring_component/fixture_receipt3.json` and
`development335/scoring_release/standalone_validation2/receipt.json`:
3,402 checks / 476 cases, with 2,217 full score calls on both sides. Across that
workload, constructed constant tables decrease from 88,706 to five module-load
tables, rank helper calls from 41,945 to 11,914, enhancement helper calls from
97,041 to 57,556, and lowest-held visits from 11,232 to 1,778. All 7,765 nominal
lookups remain. These are instrumented manufactured counts, not measured live
latency, FPS or gameplay outcomes.

The independent production test is `tests/advisor_scoring_reuse.lua`; its
unchanged before-module is
`tests/fixtures/advisor_scoring_reuse336/scoring_before.lua`. Both are included
in the frozen regression test manifest; all instrumentation resides in the
fixture. Source helper modules are part of the frozen runtime policy. The test
does not depend on development directories.

Release receipts bind full candidate and exact-installed suites separately:
`runs/scoring336_candidate/validation/report.json`,
`runs/scoring336_installed/record.json` and `policy/`,
`runs/scoring336_installed_validation/report.json`, and
`runs/scoring336_final/final_verification.json`. Their existence and verified
counts determine completion; this draft does not assert they have run.

The preceding journal335 change and callback lifetime repair remain preserved
as prior work, with their own evidence. No measured journal or live game gains
are attributed to these scoring counts. Activation and live responsiveness
still await the user's normal restart and observation. All source, captured,
search and complete-attempt allowances remain closed, and this slice starts
zero such jobs. Preserve current settings, native dependencies, logs and all
tracked/untracked work. No game control or save/profile reads are involved.
