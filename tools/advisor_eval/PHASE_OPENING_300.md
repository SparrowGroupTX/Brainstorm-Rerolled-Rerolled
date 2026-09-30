# Phase copying and normal searched opening

Runtime: Advisor/phase_copy.lua, normal_opening.lua, decision.lua, snapshot.lua,
runtime.lua; Core/Brainstorm.lua first-pack marker and version; compatibility
version. New fixtures: tests/advisor_phase_copy.lua (184 checks, including actual
shared-decision integration) and advisor_normal_opening.lua (65 checks, including
production capture). Focused five-fixture receipt:
development294/phaseopening300a/report.json. Full139 Lua/299 Python validation.

Phase copying compares the actual next reorder action before shop exit (Perkeo)
and before the first actual discard (Burnt). The Burnt comparison preserves the
same held-card finishing option in a separately certified scoring order, with
exact discard effects equal apart from the extra Burnt levels. Fresh advice
discards once prepared, then restores a useful scoring order, avoiding an
otherwise observed reorder oscillation. Extra work uses only the remaining70
fastclear/140000 ordinary/50000 shop budget. Whole-inventory Perkeo values,
Negative pools, copying chains/cycles, pinned/hidden/debuffed rows, Dagger victims,
cash and population remain guarded. Arrangement actions have a cost; no blind
five-card discard rule or claimed win probability was added.

Normal opening follows only a run-bound declared two-Soul filter and actual
first Small Charm Tag. It skips that blind, then chooses actual visible Souls
one at a time with available Joker slots, checking the real first acquisition
before the second. It never assumes future offers affordable or acquired. Raw
seed/search timing is omitted from policy snapshots. Generic target identities
and normal decks are supported; no seed/challenge-name recommendation exists.

Detailed unchanged module contracts and source navigation:
development299/drafts/copy_order/INTEGRATION.md and
development299/drafts/normal_route/INTEGRATION.md. Draft notes' preintegration
wording is historical; the current runtime and tests above are integrated.

Fresh mechanical M06 used exact frozen candidate300 and original-source
callbacks plus the existing declared Core/lovely multi-Soul hook. On selected
S04 seed M4BVSY11, three advisor actions (skipSmall, chooseSoul, chooseSoul)
actually acquired Perkeo and Yorick, spent no cash, then stopped before playing
a blind. This proves this selected opening acquisition, not early survival,
the later Rare offers, retention, a complete run or an achievement. Source and
profile remain synthetic/unqualified; exact records are under
runs/gold299_20260914/M06. NativeS04 discovery used frozen v9 but the disclosed
fixed-target recipe reproduces existing API8 product opening behavior.

M05 separately verified original normal terminal callbacks and loss precedence
on four synthetic final states, including the explicit Mr Bones exception.
It is not a complete attempt. M02's missing display cursor and M03's missing
native fixture index dependencies remain recorded as spent failures. M07
verified active native cancellation; no native DLL changes ship in300.
