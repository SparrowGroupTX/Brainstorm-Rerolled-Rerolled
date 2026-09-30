# Bounded410 review

The same sole read-only reviewer performed one substantive source/design review
and one focused implementation recheck; both allowances are complete. No reviewer
edited files, ran full gates, accessed the game or used captured states.

The source review identified the final arbitration seam, Acorn early return,
actual-index vs stored-play hazard, growth heuristic vetoes and public-model gaps.
It recommended a strong teacher preference with explicit exceptions after the
user revised the absolute prohibition. The implementation follows that scope.

Focused recheck raised three findings, corrected by the primary:

1. Early fast-clear growth ignored a smaller caller cap. The effective ceiling
   now clamps that path too. A real one-score Search+Growth fixture failed before
   the change (`caller_cap_before.log`) and passes afterward.
2. Singleton clearing anchors could newly consume held resources. Probes now use
   only a subset of the original played cards, compare population cost using the
   production population profile, and compare supported finish-reward valuation
   when present. Unknown original nonzero rewards block substitution. Gold/Blue
   controls with a different original clearing hand pass. The first implementation
   supplied the build profile to population_cost; targeted09 preserves that error,
   and targeted10 confirms the corrected population_profile API.
3. Rescore exceptions underreported work. Receipt work is updated immediately
   when charged, including nonclearing, unsupported and exhausted returns. The
   stale-proposal fixture checks exact charged work.

All new57 policy checks and the actual runtime capture/presentation/Execute
integration pass (runtime total830), along with earlier targeted budget and
ordinary-profile controls. No third review was requested. Final full frozen gate
and preservation verification are recorded separately; this document does not
assert loaded-game behavior or a below1% exception rate.

Other preserved iteration evidence: manufactured_before reproduces the policy
omission; targeted02 selected a nonexistent fixture path and ran no tests. The
Steel fixture initially expected multiplication after Joker-stage +Mult; the
production scorer probe showed1624 rather than2424, so the fixture's supported
threshold is1620. The final-action seam fixture was corrected to inject at actual
phase-copy arbitration. Runtime fixtures enable the real Gold/teacher capture
setting and preserve expected indices before Execute invalidates stale advice.
