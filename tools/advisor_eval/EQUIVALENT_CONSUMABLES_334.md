# Equivalent owned-consumable candidates — 334

This note describes the completed source change and its bounds. The root release's
candidate, exact-installed and final-verification records own the actual test
counts, hashes, installed version, backup and activation status. This note grants
no experiment authority.

The general hand-phase consumable planner created a target group for every
physical held card. Identical adjacent copies consequently repeated the same
transformation and complete play-subset comparison. The shared classification
cache reused hand categories, but every score call still executed the scorer.
This wasted the consumable budget and could leave different targets unexamined.

For example, static enumeration for an eight-card hand gives 218 playable
subsets and 28 Death target pairs. One Death's complete target family therefore
requires 6,104 calls in this planner. Ten equivalent copies create 280 physical
target candidates, or 61,040 calls before the unchanged 25,000-score cap. These
are source-derived counts, not a measured live timing or simulation result.

`consumables.lua` now builds one group per contiguous run of equivalent, visible,
supported cards. Equivalence compares the complete public card metadata except
the top-level physical `id`. Abilities, editions, prices, copy-source metadata
and nested IDs remain significant. The comparison is bounded and rejects
unsupported values, cycles and excessive metadata. Every intervening unequal
or ineligible card ends the run.

Adjacency is deliberate: consuming either adjacent equal card leaves the same
ordered scoring metadata in the inventory. The scorer applies held editions
and Observatory in inventory order, so matching names at separated positions
are not a sufficient proof of equivalence. Ordinary and Negative cards remain
separate because a Negative use removes its granted slot. The representative
keeps its original inventory index; no real inventory entry is removed by
grouping, and the actual use still consumes exactly one physical card.

The resulting candidate family also feeds the existing bounded upgrade-then-
targeted-consumable shortlist. Original indices and its existing shift after the
first use remain intact. This does not add arbitrary two-Tarot or longer
consumable sequences. Recommendations still refresh after each executed use.

The new diagnostics distinguish physical supported candidates, retained
representative candidates, skipped duplicate copies and skipped duplicate
target candidates. These counts explain saved comparisons; they are not win
probabilities or a claim about all time spent evaluating consumables.

## Preserved mechanics and limitations

- Whole-inventory Perkeo copying utility, remaining copy-source protection,
  Observatory value, cash, capacity and actual use counts are preserved.
- Interspersed copies and metadata-distinct copies still receive separate
  comparisons. Keyless name aliases and unknown identities are not treated as
  interchangeable merely because they display the same name.
- Targeted Spectral projections use the target playing card's identity and full
  population for generated IDs; the consumed Spectral ID does not enter those
  projections. Original representative objects remain available to the
  Spectral capacity calculation.
- The fast development path and mixed-rescue shortlist already selected one
  card per definition key. Their existing narrower behavior is unchanged.
  Homogeneous qualified Planet hold/use planning already groups by ordinary
  and Negative use counts; this slice does not broaden that separate family.
- Scoring, deterministic sampling, common-world comparisons, score budgets,
  population/Glass, retry protections, logging format and native code are
  unchanged. The reduction proves equivalence within current built-in modeled
  mechanics, not arbitrary external callbacks that inspect physical IDs.

## Source and evidence navigation

| Responsibility | Source or evidence |
| --- | --- |
| Equivalent-card check and hand-phase candidate construction | `Brainstorm/Advisor/consumables.lua`: `equivalent_owned`, `M.suggest` |
| Exact single use and index removal | `consumables.lua`: `M.apply` |
| Existing cheap per-type choices | `consumables.lua`: `M.develop`, `M.rescue_candidates` |
| Classification-only reuse | `Brainstorm/Advisor/score_cache.lua`: `M.new` |
| Ordered held-consumable scoring | `Brainstorm/Advisor/scoring.lua`: held consumable loop |
| Whole-inventory preservation | `Brainstorm/Advisor/strategy.lua`: `inventory_value`, `preservation_cost` |
| Count-based homogeneous Planet family | `Brainstorm/Advisor/perkeo_inventory.lua`: `planet_family` |
| Spectral target and capacity identity | `Brainstorm/Advisor/spectral_development.lua`: `apply`, `free_after_use` |
| Preserved pre-change module | `development334/before/consumables.lua`, SHA-256 `cffd8e739ac8f02c3ce14ba31bdc2d432322a79bacbe47f95fc01084ad9963d2` |

Production regression: `tests/advisor_consumable_duplicates.lua` passes 209 checks.
The candidate and exact-installed receipts listed below bind all complete-suite
counts and frozen hashes; final verification records installation and preservation.

No source attempt, source component, captured-policy comparison or seed search
is part of release 334. All historical experiment authority remains closed.
The loss328 batch remains three losses, one error, one timeout and one
unsupported result, with zero wins; its four public pairs and six source
attempts used 1,200 reserved seconds and 685.3740000000689 actual worker seconds.
Unused P05/P06 and 60 seconds remain closed. These are historical results under
earlier policies, not evaluation of this change.

Activation and live FPS recovery from the earlier 333 callback repair have not
been confirmed. Fewer modeled duplicate comparisons do not establish recovered
FPS, a rescued run, achievement completion or numerical win odds. The running
game remains undisturbed; activation waits for the user's normal restart. Keep
all logs, current settings, saves, native files and dirty/untracked work.

## Measured manufactured evidence and release records

`development334/comparison_receipt1.json` records the ten-Negative-Death
workload using instrumented mock scores: baseline 24,852 calls / 114 physical
candidate comparisons / 12 distinct targets, truncated by the 25,000 cap;
candidate 6,104 calls / 28 complete distinct targets, with no truncation.
The source snapshot remains unchanged. This is a work-count measurement and
coverage check, not a wall-time benchmark or gameplay result.

`development334/fixture_receipt3.json` records 209 passing checks, including
real-scorer upgrade/Tarot sequences in both inventory orders, repeated public
decisions, all retained copying probabilities, actual one-card removals,
Negative capacity and metadata/visibility/depth/cycle fallback boundaries.
Earlier passing fixture receipts remain separately preserved.

Full evidence: `runs/duplicates334_candidate/validation/report.json`,
`runs/duplicates334_installed/record.json` and `policy/`,
`runs/duplicates334_installed_validation/report.json`, and
`runs/duplicates334_final/final_verification.json`.
