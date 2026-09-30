# Architecture navigation for release 380

This is a small delta map. Use `ARCHITECTURE_MAP_378.md` and its linked maps
for the broader advisor/shop/teacher graph; do not reread their history unless
a concrete question requires it.

- Public Amber Acorn capture and settled action hooks:
  `Brainstorm/Advisor/acorn_public.lua`, `acorn_public_hooks.lua`.
  Complete pre-hide slot permutation, popup wildcards and play/discard
  ability transition: `acorn_belief.lua`. All-world bounded action comparison:
  `acorn_ordering.lua`. Concealed-state dispatch before ordinary strategy:
  `decision.lua`. Fixtures: `tests/advisor_acorn_belief.lua`,
  `tests/advisor_acorn_public.lua`, `tests/advisor_acorn_glass363.lua`.
- Auto-run state machine, exact action freshness, retirement request and
  watchdogs: `Brainstorm/Advisor/auto_run.lua`. Product observation/log
  projection/retirement callback:
  `Brainstorm/Core/auto_run_product.lua`. Manufactured fixtures:
  `tests/advisor_auto_run.lua`, `tests/advisor_auto_run_product.lua`.
- Manual public run ownership, verified terminal receipts and trailing 10+10
  archive: `Brainstorm/Advisor/manual_run_log.lua`, `player_journal.lua`,
  `player_log_archive.lua`; product/runtime hook chain in
  `Core/{Brainstorm,auto_terminal,checkpoint_runtime}.lua` and
  `Advisor/runtime.lua`. UI control in `UI/{advisor,collection_run}.lua`.
  Timing windows are in `Advisor/performance.lua` and product journal wiring.
  See `development379/SCOPE.md` and `tests/advisor_manual_run_log379.lua`.

The frozen interrupted public cohort is
`win_rate_research/20260924_132921_interrupted/REPORT.md`. Candidate,
installation and exact gates are under `runs/acorn380_{candidate,installed,
installed_validation,final}/`; `development380/{SCOPE,freeze,release}` gives
the bounded release workflow. No captured state was evaluated with policy,
scorer or original game source.
