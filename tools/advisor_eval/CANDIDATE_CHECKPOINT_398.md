# 398 candidate checkpoint — 2026-09-26

Repository **2.193.0-alpha** is frozen and full-candidate-validated, but
**not installed**. Balatro was passively observed running during this work
(PID 46268, started 09:35:34 local); leave the process and installed 2.192
files alone. The latest audited completed ten-start cohort has a public 2.191
label, four wins, five losses and one nonterminal unsupported stop. Exact
loaded process bytes and the effect of either 2.192 or 2.193 on full-run
outcomes are unconfirmed.

The candidate digest is
`811132f6cad69aa86e00c19fc63d514e174bfa0b90f848bfdea3935b5e720bd8`.
`runs/acorn398_candidate/freeze.json` freezes 109 runtime/dependency and 303
test files against the exact installed-2.192 checkpoint in
`SESSION_RESET_397.json`. The full gate at
`runs/acorn398_candidate/validation/` passed **263 Lua fixtures and 392
Python tests** with unchanged frozen policy and test hashes. Intermediate
targeted failures remain in `development398/`; the final manufactured
fixture has 43 checks, including every order of a five-Joker row.

The six changed runtime paths from installed 2.192 are:

- `Brainstorm/Advisor/acorn_discard.lua`
- `Brainstorm/Advisor/acorn_ordering.lua`
- `Brainstorm/Advisor/decision.lua`
- `Brainstorm/Advisor/runtime.lua`
- `Brainstorm/Core/Brainstorm.lua`
- `Brainstorm/steamodded_compat.lua`

The repair compares a first discard at Amber Acorn's last hand when no
current play has a supported all-world clear. It uses public deck composition,
24 deterministic common draw samples, every retained Joker order, exact
discard/Yorick changes, and a declared bounded next-play family within the
shared 140,000 ordinary score cap. It recommends a discard only for at least
0.125 more supported sampled clears than the best immediate fixed play, then
requires fresh observation. It declines hidden playing-card composition,
unsupported effects, ability-transition disagreement, divergent world
resources and incomplete budgets. `development398/SCOPE.md`,
`tests/advisor_acorn_last_discard398.lua` and WR-049 give the contract and
evidence. No captured game state was evaluated, and no lost game was rescued.

After the user's normal game exit, first preserve any new completed public
journals that could be cleared, then verify installed 2.192 deployment/runtime
hashes, current config without restoring old bytes, all seven DLL hashes, and
the frozen candidate/test hashes. If they match, run `install_slice.py` for
the six explicit paths above with `--version 2.193.0-alpha`; inspect the
backup and installation receipt, freeze exact installed bytes, run the full
exact-installed gate and verify every deployment/config/DLL hash. Do not
install while Balatro runs. Installation alone does not prove activation or
a higher win rate. The standing execution/experiment/release rules remain in
`ADVISOR_RESUME_PROMPT.md`.
