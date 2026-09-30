# RNG guard scope clarification

The sealed burnt_inert_component/README.md says "The fixtures poison
math.random, math.randomseed, and pseudorandom." That wording is too broad.
The new advisor_burnt_pair_inert.lua explicitly poisons all three; its final
baseline02 and candidate01 runs use that fixture. The earlier baseline01 used
the preserved pre-poison version. The margin01 fixture poisons math.random
only. The reused pair01 fixture has no explicit RNG poison. Its deterministic
finite-population enumeration is otherwise unchanged.

The original README, component receipt, input fixture copies and execution
records are preserved without rewriting their hashes. This clarification
supersedes only that blanket statement. The complete finite-family counts,
score/resource assertions, before/after dependency checks, statuses, caps and
no captured/source/search/terminal execution boundaries are unchanged.
