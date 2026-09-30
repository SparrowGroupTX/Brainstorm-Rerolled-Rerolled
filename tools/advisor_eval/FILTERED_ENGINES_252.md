# Fresh retained-engine cohort — installed 2.52

Later status: 2.53 corrects startup scoring to use the actual published preparation
order and protected victims. This cohort remains historical 2.52 evidence; it is
not a source evaluation of the corrected 2.53 policy. No cohort was rerun or extended.

This bounded cohort produced three native-search misses and one acquired
Yorick/Canio pair. Both Legendaries were then consumed by Ceremonial Dagger.
The resulting row cleared six blinds before the registered 40-action censor;
it did not establish a win or a preferred filter.

## Registration and provenance

`runs/filtered_engines252_fresh/manifest.json` registered two fresh search starts,
`ROI252A1` and `ROI252B1`, each with Any and Perkeo filters on `c_knife_1`.
Each cell had the same 100,000-seed native cap and 40-second/40-action source
limits. Filter order was reversed for the second start. There were no extensions,
continuation searches, repeated attempts, or retrospective seed selection.
Jokerless was excluded.

- Installed frozen policy: `runs/development252_installed/policy`;
  digest `c44d81bd84e7c6f83ec8c1e72be8463173140ef59713fb6370b9f3139ab61f8c`.
- Frozen adapter: `af7611b872e7a2f515b4a0c6639818e62927398f397296002f5ade8e61ada2a7`.
- Cohort manifest: `197293cc2538167853dc581edf61c719a466d4a7e469da2baf5a3ddf507a3291`.
- All four raw logs, the full policy/adapter copies, workflow hashes and initial
  report remain in `runs/filtered_engines252_fresh`.
- `verified_summary.json` independently rechecks every registered request,
  trace hash, source/policy/adapter provenance, native setup, acquired pair and
  continuation identifiers, and reextracts observed resource counters using the frozen workflow.
  Four records/four initial chains passed; no verification errors occurred.

## Outcomes and costs

| Registered start | Filter | Native result | Final observed result | Whole attempt seconds |
|---|---|---|---|---:|
| ROI252A1 | Any | Found QYA352A1, Yorick/Canio | Six cashouts; 40-action censor | 13.6030 |
| ROI252A1 | Perkeo | Miss | Opening-not-found censor | 0.2975 |
| ROI252B1 | Perkeo | Miss | Opening-not-found censor | 0.2887 |
| ROI252B1 | Any | Miss | Opening-not-found censor | 0.2775 |

All attempt costs total **14.4667 seconds**, including the three misses. Measured
native-search components total 0.04167 seconds. The found cell spent 0.79915 seconds
on source setup after its 0.01226-second search, or 0.81142 seconds combined. These
components are already inside whole-attempt time and must not be added again.
Search misses retain the returned unused continuation starts `AZR452A1` and
`AZR452B1`; none was executed. There were no timeouts or tool/source errors.

## Actual retention

The pair was acquired after three setup actions. Yorick disappeared when Big Blind
was selected at step 4; Canio disappeared at the Boss selection at step 11. Dagger
Mult was subsequently observed at **20, 40, 44, 46, 52 and 58** across the six
completed rounds. These counters record scoring transferred into the retained
row instead of treating both missing Legendaries as either still active or
automatically worthless. At the final Ante 3 Small cashout, the observed row was
Dagger, Turtle Bean and Blackboard. The pair itself was absent.

The one found Any opening does not show Any has better expected completion time
than Perkeo. No Perkeo source attempt launched because both registered searches
missed. Acquisition, six clears and a surviving replacement row are all weaker
evidence than a terminal win. Human clicks, animation/restart time and the external
filter setup overhead remain unmeasured. The source adapter still uses its
synthetic unlock profile, so this cohort cannot qualify challenge win rates.

No runtime/native filter changed. The game process/window and user saves were
untouched. Original source was read from the executable ZIP and executed only
through hidden, bounded isolated Lua workers. Thirteen existing filtered-protocol
tests pass. Historical 2.45 and 2.46 cohorts were not pooled with this policy.
