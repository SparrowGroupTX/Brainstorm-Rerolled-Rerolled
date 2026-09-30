# Public teacher data interface, component 356

The legacy base 80-dimensional and specialized 530-dimensional global inputs in
the frozen 355 experiment describe the current blind, but do not contain the
visible Small/Big/Boss route with separate exact thresholds and boss restriction
metadata. The 355 checkpoint remains unchanged, rejected, and uninstalled.

`tools/advisor_learning/public_context.py` defines
`brainstorm_public_context_v1` for the journal's explicitly redacted
`brainstorm_public_snapshot_v1` input. The new runtime snapshot exposes the
visible route throughout decision phases. This adapter retains:

- Small/Big/Boss identity, exact chips, ante, state, multiplier, reward and
  restrictions, with explicit absent/unknown flags. A named 3-by-24 numeric
  projection accompanies exact categorical identities and restriction records.
- Public ordered hand/Joker/consumable/shop/pack state, unordered deck
  composition, dynamic abilities, economy, counters, played-hand history,
  vouchers, tags and current boss restrictions.
- Actual three-state Gold collection status. `collection_progress` is metadata
  for the win-oriented teacher; `completionist_goal` is the normal objective.

No target is invented from future antes or from a static boss catalog. Physical
card IDs live in separate action-reference metadata. Seed, run identity,
timestamps, teacher advice/scores and outcomes remain outside policy features.
Concealed identities and draw-pile subtraction protections survive conversion.

`tools/advisor_learning/teacher_demonstrations.py` accepts complete ordered
`teacher_collection_v1` journals. It verifies full-observation references,
recommendation references, actual macro/callback requests, exact pre-action
callback references and first settled post-action observations. It keeps a
recommendation, requested action, accepted callback and completed game outcome
as distinct evidence. Macro and nested game callbacks are labeled separately
to avoid treating them as two independent strategic decisions.

Only run-bound `original_win_callback` evidence can establish a logged win;
`GAME_OVER` establishes a logged loss. Stall abandonment, unsupported and error
records remain separate. Missing/repeated events, stale/foreign references and
duplicate outcomes fail conversion. Incomplete actions remain incomplete.
No example is automatically declared expert or assigned a punitive label.

Command, after a collection is stopped and its ordered archives are stable:

```powershell
python -m tools.advisor_learning.teacher_demonstrations --input path\segment1.brj --input path\segment2.brj --output path\new_dataset.jsonl
```

The existing bounded archive reader supports JSONL and BRJ2. Inputs are read
only and hashed before/after conversion. Output is new only; errors leave an
explicit `.incomplete` artifact. Original logs remain the lossless source;
normalized policy inputs deliberately exclude provenance and unsupported fields.

Validation: 30 manufactured Python tests pass, including actual Lua journal
`M.new` through a fake archive with nested callbacks and the Python linker,
plus JSONL CLI success/refusal tests. No game was launched, no simulation
episode or policy experiment was run, no save/profile was read, and no training
or GPU job occurred for this component.

Limits: this interface is not connected to the frozen network. A separately
versioned model/action representation, legal candidate reconstruction,
sequence/history strategy and training/evaluation protocol are still required.
First settled observations do not prove every queued game effect completed.
Journal terminal evidence is not an independent replay verification. These
tests establish data boundaries and links, not teacher quality or win rate.
