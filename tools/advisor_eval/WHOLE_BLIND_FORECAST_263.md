# Whole-blind shop forecast — development263

This addresses the repeated-opening capacity weakness in installed262. It is
bounded decision evidence, not full-run or win-rate evidence. The root checkpoint
records the eventual installation version and deployment hashes.

## Resulting behavior

`Brainstorm/Advisor/blind_finishing.lua` carries real play/discard transitions
through each of the four composition worlds already used by shop scoring. It
compares two complete policies: play without discarding, or use at most one
targeted discard at the first observed nonclear hand before continuing to play.
The discard is selected from the observed hand by the existing targeted family.
Future plays exhaust the existing `search.obvious_candidates` family (at most32).
One policy is selected over all four worlds; it cannot choose whichever policy
wins separately after seeing each hidden deck. Deck order is used only to draw.
This is evidence that an admitted policy can finish the sampled blind. It is
not queued, and does not bind later live hand advice; each user action replans.

The current actual Joker row is retained. If blind startup applies, the same
executable setup and exact startup projection used in opening scoring is retained.
The opening play is reused from exhaustive opening scores only for that exact row.
Clear plays prefer population conservation, Arm preservation and held finish
rewards. Physical cards, Glass outcomes, permanent debuffs, hand levels, Joker
growth/expiration, cash and hand/discard counts flow through existing exact
transitions. Neither consumables nor hypothetical purchases are spent mid-blind.

Every admitted endpoint and policy must complete all four worlds. Unknown or
concealed transitions retain explicit fallback. The scope is one to four hands,
one to eight held cards, at most120 remaining deck cards, and the existing50,000
shared shop scoring cap. Exhaustion invalidates the whole paired comparison;
no partial result creates purchase credit. Larger hands, long Burglar horizons,
random scoring/startup and unmodeled conditional cash remain outside the scope.

`shop_scoring.lua` keeps raw opening metrics separate and reports all policy/world
actions, played physical identities, accumulated score, shortfall, cash and
resources. Readiness uses completed outcomes instead of repeating an opening
score. Both endpoints must complete before cumulative progress changes a paired
build adjustment. If they cannot, readiness says unresolved and purchase scoring
retains its explicit opening-only fallback. No optimistic proxy is called a
whole-blind plan.
Within admitted whole-blind scope, legacy invented last-hand/repeat/all-discards-
spent scenarios are bypassed. Exact observed transitions establish these effects;
unsupported continuations stay unresolved instead of reviving assumed resources.

`strategy.lua` uses the same paired cumulative progress for timely-scoring urgency
when available. A completed all-world clear can produce a resource certificate
for `liquidity.lua`. The certificate binds the actual shop endpoint with
`Liquidity.observation_key`, excluding derived readiness/context fields; cash,
inventory, row or other observation changes invalidate it. It releases only the
largest actual discard count in the selected complete policy. Rentals remain
reserved, unseen draws remain uncertain, and no sample guarantee is claimed.

## Meaningful acceptance cases

`tests/advisor_blind_finishing.lua` has41 checks:

- Actual four-hand Green Joker growth has opening max30, so the old capacity
  proxy120 misses a150 target. Complete policies average195.25 and clear all four
  worlds. With $3 and a $3 Golden Joker offered, actual advice changes from
  leaving the shop to buying the income investment; no weights or seed cases
  are hardcoded in runtime logic.
- Ice Cream30Chips decaying20 per play has opening proxy180 against150, yet actual
  cumulative score averages96.75 after expiry. The deficit now appears. An
  affordable ordinary +4Mult Joker repairs it, with emergency value explicitly
  based on cumulative progress.
- Completed play-only worlds release paid-discard reserves; changing endpoint
  cash invalidates the certificate. The alternate funded discard policy carries
  exactly one dollar of actual cost through each world's later plays.
- Glass conservation, exhausted physical population, known concealed future
  draws, conditional random cash, deterministic reuse, input immutability and
  entire-comparison budget fallback have focused regressions.
- Green plus Mystic Summit no longer fails a fictional all-discards-spent
  scenario before real transitions can be evaluated. Card Sharp repetitions and
  Acrobat's actual last hand carry their true effects through the complete path.

`runs/shop_finishing263_focus1/validation.log` contains18 focused Lua fixtures,
976 printed checks, all passing. `manifest.json` records before/after runtime and
test hashes (unchanged), hidden60s cap, and elapsed time. This includes prior
shop/copy/startup/reroll/sequence, liquidity, fast-clear, population/Glass,
growth/opportunity, owned finish, two/three-hand finish and reward regressions.
The follow-up `runs/shop_finishing263_focus2` reruns the changed fixture and
adjacent shop/temporal/growth regressions after the temporal correction; its
manifest is the final source/test hash record for this subtask.

## Bounded component evidence

`runs/shop_finishing263_profile1` freezes the whole candidate product and the
profiling adapter before six hidden workers. Three fixed synthetic shop workloads,
two cache modes, two repetitions per worker,15s cap each: all12 decisions complete
with matching complete result/action/score-count fingerprints across cache modes.

| Workload | Total score evaluations | Finishing evaluations | Prepared median |
|---|---:|---:|---:|
| Safe shop | 4,392 | 32 | 0.038s |
| Weak full row | 3,653 | 165 | 0.068s |
| Dagger startup | 8,498 | 650 | 0.172s |

No workload exhausted its shop cap. These are small instrumented synthetic
timings, not a population speed claim or evaluation of completed runs. The
profile froze all current policy files, including independent development; it
is not an installed-product checkpoint. No game process, saves or executable
launch were involved.
The profile precedes the temporal-assumption correction; its three registered
workloads do not exercise that corrected temporal path. It is preserved as
component evidence for the tested precursor, not relabelled as a final freeze.

Remaining limits include omitted future-play/discard policies, no mid-blind
joint consumable optimization, unsupported concealed horizons and unqualified
source-episode population. These changes establish specific decision repairs,
not a calibrated overall improvement or per-challenge win rate.

## Demonstrated survival-dominance correction after installation263

A final bounded review reproduced a real remaining decision error. Bull at $5
with a valid24-Ace deck, one-card play limit, four hands and target95 finishes
all four sampled worlds. Buying a $3 Golden Joker drops retained scoring to zero
clears, yet frozen263 still bought it because delayed income kept its strategic
rating. `runs/shop_survival263_reproduction` preserves that exact frozen263
reproduction, the fixture and policy-record fingerprints, and its hidden20s cap.
This is a constructed deterministic decision, not a challenge seed or episode.

The correction in `strategy.lua` and `shop_sequences.lua` introduces a categorical
final-endpoint check, without new numeric weights: when both common-world
forecasts are complete and known, losing any clear from a baseline that already
clears all four is dominated on supported near-term survival. Such a stand-alone
purchase or complete replacement endpoint is declined. Its evidence remains
reviewable under `survival_rejections`; uncertainty does not fabricate dominance.

Sequence expansion retains intermediate purchases and uses. Only the final
endpoint is rejected. A guarded purchase may admit the existing bounded visible
rescue graph even from a currently safe state. The fixture retains a Golden-first,
owned-Pluto-second continuation that restores every sampled clear; safe lower-
target Golden investment remains buyable. No action queue is installed.

`runs/shop_survival263_focus1` contains eight focused fixtures/241 checks, all
passing with unchanged runtime/test hashes under a hidden60s cap. The new
`advisor_shop_survival.lua` has15 checks covering the real failure, visible rescue,
safe investment, complete endpoint evidence, immutability and determinism.
The root checkpoint records the separate correction release/backup. Existing
whole-decision fallback after a later budget failure remains unchanged; these
guards require completed paired evidence and do not qualify unseen outcomes.
