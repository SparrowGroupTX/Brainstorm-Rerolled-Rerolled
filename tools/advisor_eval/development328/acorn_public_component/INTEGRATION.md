# Public Joker observation component

This detached component observes visible popup text, colors, animation locations,
and literal slot movement. It does not inspect a hidden Joker key, ability, ID,
or pre-shuffle object association. The root owns integration and installation.

`Brainstorm/Advisor/acorn_public.lua` owns the volatile tracker. Before the first
flip it copies the currently public fronts, strips identity/reference fields
recursively, sorts the resulting payloads, and passes that unordered inventory
to `acorn_belief.start`. Every shuffle forgets the previous slot permutation.
Only public-derived counter changes survive a later shuffle. A prior model gap
does not become qualified again just because the row was shuffled.

`acorn_public_hooks.lua` wraps final `attention_text`, after the source applies
any `extra.focus` redirection and schedules its displayed popup. It reads only
the rendered text, color, offset and current visible anchor/slot. A number is
recognized only when re-rendering it with the current localization produces the
identical text and the displayed channel color matches. Expected candidate
amounts are also re-rendered by the belief engine: a rounded display is not an
exact measurement of the hidden scalar. Blueprint/Brainstorm ambiguity remains
in the belief engine. Juice alone records an activation and removes no world.

The observer advances Yorick only after a public discard callback's selected
count and the subsequent settled resource counters agree on one completed
discard in the same round and epoch. It never rereads a hidden ability. A
completed play is likewise recorded once. Unsupported uses, sales, population
changes, missing action completion, callback errors and value gaps cannot be
filled from concealed data.

Manual movement requires the observed origin immediately before `Card:drag`,
followed by a completely matching slot insertion after release. References
exist only during that visible movement, and are never associated with a
pre-concealment identity. Product Execute uses a separate transient
`prepare_reorder`/`finish_reorder` receipt around the existing executor, checking
every final destination against the requested old slot. A preflight rejection
that leaves the row unchanged retains its belief; partial or ambiguous
movement invalidates it.

The hidden-row execution exception requires the current belief's exact epoch,
revision and complete world count, a complete order comparison, an all-world
clear certificate, the public-world-floor bound kind, known current abilities,
and a settled visible arrangement. Existing callback legality, population,
pinned-card, movement and freshness guards remain. Arbitrary face-down rows
still cannot obtain this exception.

## Root integration

1. Install the two new observer modules beside the belief/ordering modules from
   `acorn_belief_component`. Apply this component's `runtime.patch`,
   `execution.patch`, `snapshot.patch` and `gold_stickers.patch`; matching full
   detached files are also provided. Hidden Joker redaction precedes `M.card`,
   including its identity/ability/copy-source reads. Certificate registry capture
   is omitted during concealment. Gold held summaries use only remembered public
   unordered keys or explicitly remain unavailable. The runtime patch binds the
   observer, sanitizes snapshots before
   they reach advice/fingerprints/logs, ticks passive hooks before readiness
   checks, transports successful Execute movement, and presents a conservative
   public-world score floor instead of guessed Joker names.
2. The runtime patch now includes `A.acorn_ordering=module('acorn_ordering')`.
   Compose pillar's `decision.lua` early interception. It must run
   before any ordinary strategy/search path whenever Jokers are concealed and
   must provide `result.strategy` even when unavailable. Missing memory or an
   incomplete comparison returns explicit unsupported advice.
3. Keep source validation's already frozen baseline327/candidate329 adapter
   unchanged. Its concealed-row stop remains the correct scope for those jobs.
   Any future evaluation of this feature needs a newly frozen complete graph,
   observer path and the appropriate fresh authority.
4. Add production fixtures/module/deployment entries and run the full candidate
   and installed regression before release. The root owns version, backup,
   installation, exact installed hashes and checkpoint/navigation records.

No game state is persisted, loaded or restored by this tracker. A new/restored
game object, start/delete-run callback or a round transition expires previous
memory. A loaded game already inside concealment remains unsupported unless a
new public front observation supplies its inventory. Logical facing-front is
insufficient while the sprite still displays its back.

## Validation and limits

Manufactured validation passes 115 observer/real-executor/capture checks, the existing
642 runtime checks plus four new public-display checks, and the existing 313
execution, 110 snapshot and 316 Gold metadata checks. Poisoned hidden fields prove the exercised hook/capture paths
do not revisit concealed identities. Detached fixture-authoring/interface
failures are retained in `fixture_revision_evidence.json`.

The exact preserved source and original receipts are bound in
`source_evidence.json`. No new executable archive was opened and no original
source/game action ran for this component. The earlier failed source fixture
that preserved those bytes remains a failure; static reading does not change
its outcome.

This is a bounded public-observation mechanism, not a terminal rescue or a win
rate result. Its engine must keep all compatible worlds, including ambiguous
copy effects, unknown mechanics and rounded displays. Missing origins,
unmodelled mutations, contradictory evidence and the 256-event bound are
explicit. The separate planner's immediate score comparison does not establish
optimal information-gathering plays, blind survival, long-term consumable use,
or a complete win.
