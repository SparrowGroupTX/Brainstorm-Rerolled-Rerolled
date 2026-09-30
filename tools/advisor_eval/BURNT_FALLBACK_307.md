# Bounded Burnt fallback and visible search status —307

Release307 preserves304's source-matched loading-cache and main-menu readiness
repairs. It fixes two additional visible defects: immediate Start-button errors
were hidden behind stale auto-run text, and successful manual launch status
could be overwritten by the subsequent settings-change hook. The page now keeps
an explicit manual/automatic status owner, shows click refusals, and updates two
bounded status lines without reopening the menu. The completed manual owner is
retired before settings invalidation. No readiness guard is removed.

One explicit request may make two sequential native calls. The first requires
Burnt by Ante5 and receives at most9 seconds; the second removes only that fixed
Burnt requirement and receives at most18 seconds. Their allocated caps sum to
at most27 seconds and both share the original27-second search wall envelope,
inside the existing30-second outer product limit. Smaller requested budgets
shrink both phases. Only a matching, owned, exited miss/timeout can start the
second phase. Cancellation, errors, stale receipts, changed profile/input/run,
unavailable/backward clocks and an undrained worker prevent fallback.

Yorick/Perkeo, two Souls, visible Small Charm, copy target, no-Perishable rule,
missing quota, deck/stake and encounter window remain required. A missing Burnt
can still count as a later quota target. Relaxed launch metadata lists the actual
three mandatory targets and retains both phase receipts; it never claims Burnt
was acquired. Explicit required-Burnt choices remain strict. Direct query callers
remain strict unless fallback is enabled. There is no native DLL change.

| Component | Source | Fixture |
| --- | --- | --- |
| Query and optional Burnt | Advisor/collection_search.lua | advisor_collection_query.lua |
| Bounded phase ownership and launch | Core/collection_search_product.lua | advisor_burnt_fallback.lua; advisor_collection_product.lua |
| Automatic default/options | Core/auto_run_product.lua | advisor_auto_run_product.lua |
| Controls and live refusal/progress text | UI/collection_run.lua | advisor_collection_status.lua; advisor_adaptive_quota.lua; advisor_gold_layout.lua |

All source paths are beneath Brainstorm; fixtures are beneath tests. Six focused
fixtures pass482 checks; geometry adds381 checks with zero baseline bound
violations. Candidate and exact-installed full regression pass153 Lua fixtures
and315 Python tests. These are synthetic release tests, not a live UI or full
automatic-run result. Original source startup evidence remains M12/M14 with
their explicit runtime-receipt/font stand-ins and incomplete UI-click coverage.

Exact staged source/test hashes: development300/burnt_fallback/
ready307_manifest_v2.json and root_stage307.json. The earlier manifest is kept;
v2 corrects its baseline reference using frozen306. Full release records are
runs/fallback307_candidate, fallback307_installed, fallback307_installed_validation
and fallback307_final. All existing settings/native files are preserved.

The Auto quota still excludes unsupported prerequisite and other-Legendary
routes; full150 coverage, acquisition/retention, win odds, user activation and
Completionist++ speed improvement remain unproved. M15 was a separately spent
read-only source inspection; this runtime slice executes no experiment.
