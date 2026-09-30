# Independent read-only review of the358 surplus-development repair

Reviewed the workspace changes to `consumables.lua`, `strategy.lua`, and the ordinary-budget plumbing in `decision.lua`, together with the manufactured fixture `advisor_surplus_development358.lua`. This reviewer did not execute policy evaluations, original-source components, simulations, games, or new fixtures, and made no runtime edits.

After the author's explicit-call correction for a nil lower-bound return, no additional blocker was found in the reviewed scope:

- Candidate `lower_bound` replaces the old candidate mean-score call. An uncertain incumbent requires one additional baseline-floor call, charged inside the same six-call allowance. A failed baseline proof remains charged before ordinary fallback; it does not renew that budget. The ordinary entry caps development by its remaining allowance, and `decision.lua` supplies the shared ordinary remainder. Fast-clear development retains its existing six-call share of the70-score aggregate.
- A missing or unsupported lower-bound receipt cannot promote a mean estimate. Accepted floor results require legal, finite, non-uncertain score, `reliable_bound=true`, and `bound_kind='supported_random_floor'`. The nil receipt path now makes no uncharged fallback scoring call.
- Exact-use application remains in `M.apply`: target counts, sorted/distinct positions, forced selection, supported transformations, one inventory removal, and Negative capacity changes are unchanged. The underlying public deck/population update is unchanged.
- Last-template and whole-inventory/Observatory preservation checks remain before admission. The patch does not resolve the separate Death/Venus-versus-Hermit pool valuation problem.
- New scoring Glass exposure is still compared against the incumbent's actual per-card exposure. The floor implementation preserves real Glass probabilities. The Arm hand-level cost gate is retained.
- Target sorting changes only equal-gain Magician/Empress/Hierophant suitability. Fixed1e-9 utility buckets, then existing card utility, rank, and index give a deterministic transitive order. This is heuristic target selection; it does not claim an exhaustive target optimum or hardcode a seeded/challenge strategy.

The fix's limit is material: it develops an already supported clearing action. It does not repair the Serpent decisions whose ordinary search exhausts140,000 scores before any complete consumable comparison, and it does not add multi-use rescue or hidden-Acorn discard planning. See `EMPRESS_BUDGET_ADDENDUM.md` for those observed records.

The author/root's regression results, exact installed hashes, and runtime release record remain the authority for validation. This note is an independent source/fixture review, not an additional successful run or counterfactual win.
