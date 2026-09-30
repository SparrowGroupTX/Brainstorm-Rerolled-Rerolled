# 358: supported-floor surplus consumable development

## Problem and scope

The cheap development path preserves an already selected clearing play while investing one consumable in the deck. Before 358, adding Lucky to a scoring card made the recalculated score uncertain, so the path rejected the investment even when the same play cleared with every random activation failing. It also rejected an uncertain baseline before checking whether its supported minimum already cleared. This could leave useful surplus Magician copies unused beside a safe finish.

Passive development357 logs show the teacher sometimes used these cards: M4BVSY11 used Empress 21 times and I8VUSV31 used Magician 17 times. Surplus still accumulated, including 18 held Magicians in the latter run. Those observations motivated source review; no recorded state was replayed to measure this change, and no run was rescued or improvement in win odds demonstrated.

## Runtime changes

- `Brainstorm/Advisor/consumables.lua`: retain the original selected play and use `scorer.lower_bound` for each changed-state proof when available. Accept only a finite legal supported random floor at or above the remaining target, with no uncertainty or unmodeled warning. An uncertain baseline first needs the same supported-floor proof. Keep its original indices, scoring context, Glass exposure and Arm cost for the comparison. Without the bound API, the prior deterministic scoring route remains available.
- Keep the existing six-score development cap. An uncertain baseline proof consumes one of those calls; failed proofs remain charged when ordinary consumable analysis continues. A nil bound returns no proof and never silently invokes a second scorer. Candidate scores are copied before attaching indices.
- `Brainstorm/Advisor/strategy.lua`: for Magician, Empress and Hierophant target selection only, equal positive enhancement gains favor the existing build-specific card value, then higher rank, then stable hand index. Precomputed 1e-9 gain buckets prevent floating-point cancellation from turning otherwise equal gains into arbitrary hand-order preferences; the actual development utility is unchanged. Existing rank synergy, deck frequency, improvements and participation still take precedence. This is not a fixed King preference.

The path still selects one target set per distinct consumable type, with no additional subset search, draw rollout or multi-use sequence. It preserves last useful Perkeo template protection, whole-inventory copy value, Negative capacity, supported identity/configuration checks, legal forced selections, deck population conservation, no additional scoring Glass risk, no increased Arm cost, future-development horizon and positive utility after action/scarcity cost. Global score caps are unchanged.

## Manufactured validation

Evidence directory: `development358/surplus_component/`.

- `consumables.before.lua` and `strategy.before.lua` preserve the pre-change bytes.
- `baseline.log` / `baseline.json`: the initial new fixture failed against the previous implementation on surplus Magician development beside a retained clear.
- `validation.log` / `validation.json`: six relevant fixtures passed, with exact runtime/test SHA-256 hashes. New `tests/advisor_surplus_development358.lua` passed 53 manufactured checks; existing inventory development, consumables, duplicate consumables, spectral development and deck development fixtures passed 75, 79, 209, 45 and 30 checks respectively.

The new fixture covers a zero-Lucky-trigger retained clear, an uncertain but floor-safe baseline, unsupported/insufficient/nonfinite/nil floors, exact budget charging and fallback, last-template and Negative inventory conservation, input/population preservation, forced selection, modified consumable rejection, added Glass exposure, final-boss horizon, reversed-hand rank selection, Wee synergy and the directed Death target contract.

During test authoring, three expectations were corrected rather than weakening guards: deck-frequency value correctly preferred Nine over King in the initial build; the Glass case originally allowed a harmless unplayed target and was restricted to actual scoring exposure; the first forced-card case omitted its mandatory card from the proposed baseline and was corrected. The reversed-hand test then exposed the real floating-point tie issue addressed by deterministic sort buckets. The original baseline failure remains separate from the passing receipt.

The first full candidate regression also preserved a compatibility-test failure in `runs/teacher358_candidate/validation/lua.log`: `advisor_inventory_reuse.lua` compares complete outputs with frozen 337 and rejected the newly exposed development counters. Its repair asserts zero baseline floor calls in its scorer-without-floor compatibility scenario, and independently checks both reported work counts against actual scorer calls. Only the two new counters are removed from a copied diagnostics table before the historical comparison; actions, preservation, all other diagnostics and score-call parity remain checked. The corrected fixture passed 263 checks, with its before-copy and `inventory_reuse_validation.json` / `.log` in the component evidence directory. Historical baseline sources and the failed full-regression evidence were preserved. No runtime change followed this test repair; the fresh full release validation uses a separate record.

## Remaining limits

This only develops beside a supported current clear. A nominal average above target whose supported floor is below target still cannot use this proof; the ordinary path's uncertain-average clearing behavior is unchanged. Logged Serpent positions that exhausted the shared ordinary score budget before consumable analysis remain a separate issue. This slice does not add generic surplus selling, account for saturation of Perkeo copy-template values, or establish a better complete-run outcome. Full candidate/installed release validation is recorded separately by the release process.

## Installed release

2.158.0-alpha installed2026-09-16T14:04:06.2961767-05:00 with backup
`deployment-backups/advisor-20260916-140405`. All89deployment and105frozen
runtime/dependency files match; settings and all seven native DLLs were preserved.
Candidate validation2 and exact-installed validation both pass229Lua fixtures
and391Python tests with unchanged policy/test hashes. The original failed
candidate validation remains separately preserved. Policy digest:
`fd1d44e8a72ee2e98c7ffc65416938af64f85888635c0326b2189e7b632ff1a2`.

Final actual product outcomes remain loaded2.156: two wins, four losses and one
unfinished HUD-stopped opening; zero new Gold in win-first collection. The
complete passive audit is `development357/shop_review/FINAL_POSTMORTEM.md`, with
separate `EMPRESS_BUDGET_ADDENDUM.md` and independent `CONSUMABLE358_REVIEW.md`.
No repaired-policy gameplay, counterfactual evaluation or measured improvement
was performed. Activation awaits the user's normal restart.
