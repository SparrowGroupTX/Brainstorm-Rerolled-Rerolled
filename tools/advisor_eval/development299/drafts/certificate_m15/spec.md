# Prospective M15 Certificate and first-draw source inspection

Hypothesis: Certificate's source callback timing, generated card insertion and
seal distribution may require a different first-hand population than ordinary
deck draws. Its effect must be represented as a complete joint transition
before expanding the Gold cargo comparison's supported Joker set.

Read exactly the three named ZIP members `card.lua`,
`functions/state_events.lua` and `functions/common_events.lua`. Preserve
member hashes, six bounded function excerpts and bounded neighborhoods for
Certificate, first-hand-drawn, playing-card-generation callbacks and seal pools.
The inspected text must establish where generation occurs relative to drawing,
where the generated physical card is inserted, whether it changes capacity,
which seal identities/random key are used, and which follow-on Joker callbacks
run. Missing or truncated evidence remains an explicit unanswered question.

Caps: one fresh root-registered M15 lease, 30 seconds including inspection;
three members at most4MiB each; 20,000 archive entries; total excerpt bytes at
most120,000. No Lua/source callback/policy execution, native search, player data,
game process launch/control, complete attempt, or follow-up worker.

The source archive and Python runtime hashes plus every inspector/lexer input
are frozen by the registration. `inspect_source.py` requires the matching M15
registration and spent receipt before opening the actual archive. Root alone
may register and dispatch; preparing this directory spends no job.

Synthetic tests use temporary ZIP files containing manufactured Lua text only.
They do not read the actual executable or import any runtime policy.
