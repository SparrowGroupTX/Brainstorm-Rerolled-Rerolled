# Owned-consumable budget reservation — 360

Ordinary search could spend all140000 score evaluations before an owned-consumable pass. Passive explicit examples are development357/shop_review/EMPRESS_BUDGET_ADDENDUM.md and development359/log_review/POSTMORTEM.md. This repair reserves work inside those existing caps; it does not claim those recorded runs would have been rescued.

## Behavior and boundaries

Advisor/consumables.lua now provides comparison_reserve. It inspects at most eight existing apply transitions, using the same metadata, forced-target, module, full-population and Negative guards as the actual planner. Reservation requires a nonempty transformed hand of at most20 cards and capacity for a complete play pass. Generators do not qualify. No scoring, unknown draws, RNG, selected Perkeo source or live action is invented.

Advisor/decision.lua leaves up to25000 evaluations for owned consumables within the140000 ordinary total. A smaller consumable cap is honored; reservation is omitted if a complete pass cannot fit. Lower caller search caps remain lower, and initial-play enumeration plus score-floor probes and the70-score fast-clear allowance retain capacity. Existing suggest/apply candidate selection, complete common-world comparisons, inventory retention, cash and boss guards remain unchanged. Shared unused work remains available to later specialists. Result diagnostics expose consumable_reserved_evaluations.

The eight-probe admission shortlist can miss a later supported target; that leaves allocation unchanged. Reservation does not guarantee a useful recommendation, exhaustive target search or an improved discard comparison. It trades some ordinary draw-search samples for completed consumable candidates. Generic inventory saturation/selling, uncertain-mean risk and concealed-order planning remain unresolved.

## Verification

- New tests/advisor_consumable_reserve360.lua:200 manufactured checks, including production ordinary search, full consumable scoring, exact score-call accounting in an exhausting-search integration, caller caps, unsupported metadata, forced targets, empty removal, missing modules/population, Negative inventory, immutable input, nil search and fast clear.
- Preserved before-decision fails the new reservation assertion (baseline_regression.log). No baseline bytes were restored into the workspace.
- Twelve paired manufactured cases (8/12/14/20 cards, owned/empty/unsupported inventory) use identical before/after inputs. At12/14/20 cards, old ordinary search reaches140000 with zero completed consumable candidates; new completes15/7/1 respectively within138775/139304/136699 scores. Selected next-play estimates become632/640/544 vs316/320/320. These are current-score comparisons after a proposed use, not survival probabilities or realized chips. The20-card ordinary discard mean also changes363 to328.5714: less search can change its comparison, and no universal dominance is claimed.
- Empty/unsupported controls retain prior actions, scores and evaluation counts. One timing per case is recorded, not a latency distribution. Owned cases before/after seconds:0.792/0.762,1.211/1.141,1.476/1.379,2.220/2.228. Full raw output, exact fixture/source hashes and summaries: development360/manufactured_comparison.log, manufactured_provenance.json, comparison_summary.json.
- One independent read-only Astra Medium review and one focused recheck resolved initial nil-guard/admission findings; no remaining release blocker. See development360/REVIEW.md. No extra reviewers or tests delegated.
- Full candidate AND exact-installed validation pass232 Lua fixtures and391 Python tests, policy/test hashes unchanged,60s per suite. Candidate Lua/Python39.016/14.563 seconds; installed36.891/12.765 seconds. Evidence: runs/reserve360_candidate/validation and runs/reserve360_installed_validation.

## Installation and evidence

Installed2.160.0-alpha at2026-09-22T11:40:58.3492402-05:00 using install_slice.py with explicit Advisor/decision.lua and Advisor/consumables.lua, plus consistent version-field stamping. All89 deployment files and105 frozen runtime/dependency files match. Digest:81293cad23d26248233391c6066c9e3f2c6a59e63239151e8cbc416cc9b05857.
Backup:`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260922-114057`.
Current configuration preserved with SHA256`b0d07c76fdd48c94816ba34061a1fc8aa0092e6e72a323c7a2eed681ec7f3629`; its change since359 was legitimate and never restored. All seven native DLLs remain unchanged. No game/save/profile control, hidden search/source/captured-policy/simulation/GPU work or automation. All old experiment allowances remain closed.

Fresh passive logs confirm loaded2.159 in normal collection mode, not the win-first teacher. Four starts / three GAME_OVER losses / one without terminal in the frozen prefix through2026-09-22T16:31:52Z sequence1995. Exact originals, profile and outcome anchors: development360/logs1 and POSTMORTEM.md/passive_report.json. The strict teacher converter rejects this ordinary journal schema; no teacher-label success is claimed. No later outcome inferred. No2.160 activation or real-game result is established; activation awaits normal user restart.
