# Bell routing — detached candidate

This is a routine manufactured-fixture implementation. No source executable was read, no captured state was re-evaluated, and no source, seed-search or complete-attempt worker ran. All historical experiment authority remains closed.

The existing router rejects Cerulean Bell before scoring (`blind_routing.base.lua:88`), although `bell_opening.lua` already implements complete coverage of every possible forced physical card. This candidate reuses that collector only when the known Bell is on the winning ante. It completes every legal-size subset of every checked Boss opening; each forced physical card must have a legal supported score of at least twice the target. Small-blind skips retain the exact intermediate Big transition and each supported Glass outcome. Four composition samples are not all possible draws and do not estimate a win probability.

This adds no Joker-order optimization, tag identities, hidden mechanics, score allowance or faster-time assumption. The same current Joker row is used throughout. Cash, rentals, deterministic resource depletion, the complete Perkeo inventory, growth and lost shop opportunities keep their existing values and checks. When Completionist++ metadata is present, it must be complete and eligible, and its distinct missing cargo must exactly match at least one Joker actually held. This protects a meaningful existing cargo, but the skipped opportunity to obtain additional missing Jokers remains an explicitly uncalibrated shop cost.

The result remains only `skip_blind`; normal execution supplies its current-state stale-action checks. Mandatory preparation retains its existing priority. No other blind, event or animation path changes.

Existing runtime wiring already supplies `A.bell_opening` (`runtime.lua:13`) through the modules table passed to `Decision.run`. No runtime loader change is required. The dependency edge from blind_routing to bell_opening should be included in current architecture/evaluation graph navigation.

Stage exactly `blind_routing.lua` to `Brainstorm/Advisor/blind_routing.lua` and `test_advisor_bell_routing.lua` to `tests/advisor_bell_routing.lua`, after independent review. `stage.py` validates the base/hash and backs up existing bytes before mutation. It does not install or modify versions. Root runtime has not been changed by candidate authoring.

Validation cases include an exhaustive actual-forced-flag oracle for all32 branch identities across four8-card worlds, a high3OAK score that still fails for an off-rank forced card under a three-card limit, every supported intermediate Glass outcome, exact/incomplete/zero budget bounds, no Gold cargo and malformed metadata, current copy ordering, cash/rent/whole ordinary+Negative Perkeo inventory, and unchanged55-check prior routing fixture.

Known conservative limits remain: only the six previously supported skip tags; unknown concealment/random bosses decline; the scoring row can still be left arranged for Perkeo, so a later hand-phase copy reorder is not assumed; unmodeled startup effects and unsafe perishable expiry decline. Full-run speed or win benefit has not been measured.
