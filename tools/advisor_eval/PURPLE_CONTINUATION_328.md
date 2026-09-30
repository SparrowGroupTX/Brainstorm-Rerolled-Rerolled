# Retained Purple cards no longer disable the remaining-blind comparison

Release 2.128.0-alpha repairs a concrete planning admission error observed during
the selected public Pillar loss. Generated `purple328` candidate, installed and
exact-installed records own final validation and deployment facts. Installation
does not confirm live activation or a rescued run; activation waits for a normal
user restart.

At public-log sequences2722,2727 and2732 the advisor discarded other cards while
retaining a Purple-sealed7S at hand index4. Each recommendation nevertheless
reported that the remaining-blind comparison was unavailable because Purple
discard generation was unmodeled. The global blocker inspected every card in hand,
including cards that would never be discarded. Its no-further-discards continuation
could have used exact supported transitions without needing that Tarot outcome.

The runtime change in `Advisor/search.lua` keeps the blanket blocker only for
approximate scorers without `after_discard`. When exact discard preparation is
available, it already excludes a selected Purple discard requiring an unknown
Tarot identity before any branch is admitted. Retained Purple cards, or selected
Purple whose generation is exactly suppressed by occupied slots/buffer, can now
participate in the complete existing common-world comparison. No future discard
is added, no unsupported Tarot is invented, and no hard score cap or candidate
count is increased. Any unsupported admitted later trajectory rejects the entire
comparison; the previous fallback and resource rules remain.

The manufactured regression places an Ace, King and retained Purple2 alongside
Banner, four hands and a known finite population of Kings. The old global blocker
chooses the tempting180-chip redraw. The repaired comparison chooses to play:
all eight paired play-first trajectories clear the constructed800-chip target,
while all eight discard-first trajectories fall short after losing Banner value.
The comparison uses1233 charged scores under the existing140000 ordinary limit.
This manufactured case is not the captured Pillar position, a fresh game, an
original-source test or a demonstrated terminal rescue.

The production fixture `tests/advisor_purple_continuation.lua` has36 checks covering
the complete comparison, deterministic private sampling, unchanged public input,
selected-Purple rejection, forced selection, full inventory, Negative extra room,
buffer reservations, unsupported later transitions and budget fallback. The
detached runner adds two explicit baseline checks. The revised existing
`advisor_discard_search.lua` asserts the corrected admission behavior while
retaining the unsupported-generation assertion. Four related fixtures plus the
detached comparison pass365 checks. Full release counts belong to the generated
verification records.

Evidence and staging: `development328/pillar_component/report.json`,
`integration_manifest.json`, `INTEGRATION.md`, `search_before.lua`, `search.lua`,
`run_detached.lua` and `run_related.lua`. The public-only source is
`development328/public_trace/run3.json` and its referenced redacted snapshots;
raw internal fingerprint payloads were not used as strategic evidence. Original
logs remain unchanged.

The observed loss still demonstrates an unresolved wider scaling failure: Big
Blind discarded2+4+1 cards and Pillar4+3+3, leaving Yorick six cards short when the
run ended592/600. Pillar entry itself was sixteen cards short, beyond its three
remaining five-card discards. Earlier development, pack choice, multistep resource
planning, and the separate Ante5/Ante8 losses require their own analysis. This
release does not claim that forcing five-card discards would have won, that Card
Sharp is always the correct pack choice, or that all observed losses are fixed.

Historical experiment allowances stay CLOSED. A separate new user authorization
permits at most six detached comparisons at30 seconds each and six complete
attempts at180 seconds each,1260 seconds total, with no search or game control.
This runtime slice uses no such job. Root must bind the actual authority, frozen
provenance, preregistration and one-use limits before any new experiment runs;
the new authorization does not reopen an old quota. Current settings, saves,
native DLLs, deterministic sampling and all retry/session caps remain protected.
