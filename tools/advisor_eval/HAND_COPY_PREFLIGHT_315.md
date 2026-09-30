# Earlier complete Yorick copy comparison — 315

Release 2.115.0-alpha adds a narrow reversible Joker-order decision before
expensive discard/continuation planning. It can move actual resolved copying
from Perkeo to Yorick when a complete current-hand comparison establishes a new
clear with no lower paired score or changed non-score resources. It returns only
reorder_jokers and requires fresh advice; the diagnostic clear is not permission
to play. Existing clear/growth paths run first and still retain safe five-card
Yorick discards after the reorder.

Scope is public settled rows containing only Perkeo, Yorick, Blueprint,
Brainstorm, Droll Joker and Supernova, ordinary Joker editions and up to eight
held cards. Actual Yorick XMult must exceed1. All other resolved copy targets
stay unchanged. All legal held subsets are scored in both arrangements and
their full after_play states/effects compared after normalizing only physical
Joker order and scored chips. With discards remaining, all legal current
discard transitions must also match, normalizing only row order. These are
pre-replacement states; no unseen draws, future cashout or run odds are proven.

Cash, every owned consumable including Negative/Observatory metadata, population,
hand histories/levels, physical Yorick counters and destruction remain in the
comparison. Burnt, unsupported callbacks, random Glass/Lucky, concealed cards,
possible Purple generation and active/matched/pending/unavailable retry context
decline. Whole incoming data must be plain, finite and acyclic within32768 value
nodes/depth12/4096-byte strings/512KiB total text,128 population/deck cards and32
consumables. Exceeding a bound declines the shortcut; it never truncates assets.

At most218 held subsets and436 extra scoring transitions are charged to the
existing140000 ordinary allowance; the complete cost must fit before starting.
Including original held scores and existing lower bounds, the narrow path is
at most658 calls. Supported remaining discards add at most436 explicitly counted
non-scoring transitions. The existing70-call fast clear is unchanged. All work
remains charged on fallback. State-copy cost is real; no speedup is established
by implementation or fixture counts.

205 focused checks and416 legacy checks passed before staging; the production
fixture has no historical or draft dependency. Candidate and exact installed
full regression passed163 Lua fixtures and315 Python tests. A read-only scan of
198 C04 observations found at most9001 value nodes and52 population cards, but
some14-card hands remain outside this feature's eight-card scope. No captured
decision or source attempt of315 has yet executed at this release checkpoint.

Runtime: Advisor/hand_copy_preflight.lua, search.lua, decision.lua, runtime.lua.
Fixture: tests/advisor_hand_copy_preflight.lua. Detached exact manifest, source
scope, size audit and staging backups:
development299/drafts/hand_copy_preflight315/. Existing preserved source Card
SHA5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453
grounds physical Yorick and copy semantics; no new original-source execution was
used for this implementation. Future adapters must load and verify the new root
module. Current settings and every existing DLL remain preserved.
