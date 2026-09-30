# Public Acorn belief component (detached development)

Active runtime candidates are `acorn_belief.lua`, `acorn_ordering.lua` and the
full detached `decision.lua` integration. The
earlier `acorn_ordering_final_hand_v1.lua` is preserved development history and
must not be installed. Root owns integration, policy freezing, installation and
any prospectively registered experiments. This directory grants no experiment
authority.

## Evidence and scope

`python tools/advisor_eval/development328/acorn_belief_component/run_tests.py`
passes 126 manufactured checks with the production detached scorer. It executes
no captured snapshot, original game source, game callback, search or full run.
`manufactured_report.json` records exact candidate/fixture hashes. No recorded
loss has been rescued and no terminal win follows from these fixtures.

The initial complete unordered inventory is copied from public fronts before
concealment. Physical identities, coordinates and object references are removed.
Payloads receive canonical public ordinals; at most six Jokers and 720 complete
permutations are admitted. Equal complete public payloads are exchangeable.
The matcher never compares a concealed object's identity to those ordinals.

Visible numeric popup observations narrow only supported contradictions. A
Blueprint/Brainstorm popup can match the copier or original; equal signatures
and unqualified effects retain ambiguity. Supported edition emissions are part
of the union. The observer supplies exact localized rendering of candidate
amounts so display rounding cannot masquerade as an exact hidden value. Juice,
unrecognized text, stale epochs and incomplete observations do not identify a
Joker. Contradictions invalidate the inference instead of inventing an identity.

The first complete current-order family compares every legal public hand
subset with every consistent identity world, up to the existing ordinary
140000-score allowance. It never gives different first actions to different
hidden worlds. Held consumables and Observatory are retained in actual scored
states; no consumable or discard is spent in these projections. The fixed play
is ranked by all-world immediate clear, then conservative minimum and mean
immediate score. An all-world clear avoids optimizing excess score. A nonclear
play is explicitly an information fallback, not a joint resource continuation
or a blind-survival claim; it cannot replace a supplied supported public
non-play incumbent.

Optional reorders compare the same full family across every slot permutation.
The extra work must fit both30000 order calls and the remaining ordinary
allowance. If it cannot finish, the independently completed current-order
play remains available. A reorder requires the same immediate clearing play
in all consistent worlds. Current-order all-world clears do not reorder.
Only public slot indices are emitted, and the observer must transport every
world only after the actual public movement is verified.

## Remaining limits

- The planner is an immediate scoring policy. It does not claim that playing
  now is optimal against future discard/development/consumable continuations.
- Unknown or invalid current ability values, incomplete worlds, score warnings,
  uncertain mechanics, unsupported legality or exhausted bounds remain explicit.
  Caller integration must never fall back to scoring the raw hidden Joker row.
- Visible nonrandom Bonus/Mult/Steel/Stone/Wild cards, supported editions and Red
  seals are admitted. Concealed playing cards, Lucky/Glass, Blue/Purple seals and
  Gold playing-card retention effects remain outside this component's action
  scope; those require a qualified resource comparison. This may still pause
  real developed runs rather than invent missing mechanics.
- Exact physical Yorick growth advances once per observed discarded card;
  copying Jokers do not repeat it. Qualified static rows, including Fortune
  Teller/Swashbuckler/Scary Face, remain valid through ordinary play/discard.
  Their variable additive popup amount can remain ambiguous. Unsupported
  actions/changes invalidate values; the tracker expires beliefs on new rounds,
  shuffles, restored/new runs and unqualified population changes.
- No routine tests or successful local score comparison establish an Acorn
  terminal rescue, achievement completion, win rate or human superiority.

## Integration contract

The separate `../acorn_public_component` observer supplies
`snapshot.public_joker_belief` and rendered observations. Its runtime hooks
observe final displayed text and visually ordered slots, not raw effect results.

The decision integration intercepts every hidden/identity-redacted Joker before
score-cache creation, concealed playing-card inference, ordinary search,
specialists, phase copying or retry-policy callbacks. It counts actual scorer
calls, preserves the supplied snapshot and returns explicit unsupported advice
when the belief/support is missing. Existing active retry protections remain
review-only. Conservative local scores carry
`bound_kind=public_joker_world_floor`, `uncertain=true` and
`deterministic_exact=false`; a finite world floor is never mislabeled as one
known hidden arrangement. Reorder actions include a public epoch/revision/world
count and complete-order/all-world-clear certificate; executor freshness and
observed movement checks remain required.

The scorer receives each sanitized world state once per compared slot order,
reusing that immutable state across the common subset family. A manufactured
five-Joker/four-card comparison preserves all1800 scores, complete profiles and
the selected action while reducing observed distinct projected states from1800
to120. Every repeated production score leaves its input unchanged. This is
allocation evidence, not a measured live speedup. Nine visible cards are admitted
when their entire381-subset common-world family fits; an inadequate allowance
declines before scoring instead of dropping worlds or subsets.

`belief.start(inventory, epoch, {public_before_shuffle=true,max_worlds=720})`
returns a complete initial belief ornil/reason. `observe(b,event,{render=fn})`,
`reorder(b,slot_order,epoch)`, `advance_public(b,completed_action)` and
`invalidate_values(b,reason)` return detached next beliefs; they never mutate
their inputs. A rendered event requires epoch/slot, type`rendered_status`,
phase`play`, qualified_render, channel, amount and exact displayed text.
`advance_public` requires observed_complete and matching epoch; a discard also
requires its actual1–5 discarded-card count.

`ordering.suggest(snapshot,b,scorer,belief,{max_evaluations=remaining_ordinary,
max_order_evaluations=30000,yield_fn=fn,public_incumbent=optional})` returns
suggestion/evaluation_count/diagnostics. `public_incumbent` is only an already
supported public action; it must not be derived from a raw concealed row.

Manufactured coverage includes complete ambiguity, distinct/colliding/copied
signatures, edition/unknown wildcards, exact display rounding, dynamic Yorick
counts, stable late-run rows, contradictory observations, poisoned nested raw
hidden payloads, complete current-order and reorder caps, common actions with
some identities unresolved, Observatory, forced selection/Psychic legality,
score-warning fallback, and preservation of actual inventory/resources.
