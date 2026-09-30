# Normal filtered opening route: component and integration note

Draft files are outside runtime/tests so the earlier slice can freeze/install
independently. `normal_opening.lua` is a pure receipt/capture/advice module;
`advisor_normal_opening.lua` has 65 ordinary synthetic checks.

## Concrete failure

The normal API 8 search writes a complete `G.GAME.filter_info` receipt, including
two requested starting Souls, target names/timings, deck, stake and actual run
seed. `snapshot.lua` currently retains only challenge/Jokerless receipts, and
only the challenge Charm pack has an observed pack-area marker. Thus a normal
deck advisor cannot follow the expressly searched first-Small Charm opening.
The ordinary blind policy can play Small instead, never acquiring the requested
initial Legendary engine. This is a routing gap, not evidence that such an
engine survives or wins Gold Stake.

## Runtime integration

1. Copy `normal_opening.lua` into `Brainstorm/Advisor/normal_opening.lua`.
2. Copy the fixture to `tests/advisor_normal_opening.lua`, changing its first
   dofile to the runtime path. Its local capture wrapper currently supplies the
   two planned snapshot fields explicitly; after integration, replace that
   wrapper with `Snapshot.normal_opening=Opening` and direct `Snapshot.capture`
   so the fixture tests actual production capture.
3. Next to runtime's Gold modules:

   ```lua
   A.normal_opening=module('normal_opening')
   A.normal_opening.gold_stickers=A.gold_stickers
   A.normal_opening.gold_search=A.gold_search
   A.snapshot.normal_opening=A.normal_opening
   ```

   Registry calls use only pure `target_keys()` and `name(key)`, never loaded
   profile progress. The module is not coupled to Gold tracking being enabled.
4. In `snapshot.lua`'s returned snapshot table add:

   ```lua
   stake = game.stake,
   normal_opening = M.normal_opening and M.normal_opening.capture(g) or nil,
   ```

   Keep the existing `filter_info` rule for challenge/Jokerless unchanged. Do
   not copy raw normal filter_params or run seed into deterministic inputs.
5. In the non-hand branch of `decision.lua`, before the existing Jokerless /
   blind-preparation / challenge-opening routes, add:

   ```lua
   local normal=modules.normal_opening and modules.normal_opening.advice(snapshot)
   if normal then
     return {kind='strategy',strategy=normal,action=normal.action,evaluations=0}
   end
   ```

   No hand action or later blind is intercepted. Every unsupported/bad receipt
   returns nil so the complete ordinary advisor can operate as before.
6. In `Brainstorm.createCharmArcanaCard`, inside the block that first sets
   `pack.brainstorm_multi_soul_pack=true` and
   `filter_info.multi_soul_pack_consumed=true`, next to the existing challenge
   pack-area mark add:

   ```lua
   if not G.GAME.challenge and area and G.GAME.round==0 and
       (G.GAME.round_resets or {}).ante==1 and G.GAME.blind_on_deck=='Big' and
       ((G.GAME.round_resets or {}).blind_states or {}).Small=='Skipped' and
       (G.GAME.skips or 0)==1 then
     area.brainstorm_normal_opening=true
   end
   ```

   This records only the real, already-claimed first Charm pack. It adds no RNG
   calls, duplicate bypasses, card generation, or renewals of the consumed flag.
   Snapshot validation separately requires a verified normal two-Soul receipt.
7. In the freshly frozen normal source adapter, after optional preload of
   `probe_policy_normal_opening`, load both Gold registry modules and assign
   those same three dependencies to `modules.normal_opening` and `snapshot`.
   Attach before the first capture of the initialized normal recipe. Freeze the
   actual changed Core Charm hook with the adapter; otherwise `pack_marked`
   correctly remains false and the route cannot claim that source pack.
8. Add normal_opening to syntax/navigation/explicit deployment manifests.

## Receipt contract

Existing API 8 receipts are accepted only when all repeated native arguments
agree, the actual loaded run seed/deck/stake match, required_soul_count is two,
and exactly two different known Legendary targets use supported starting
timings. Five byte-31-separated names and timing fields are parsed exactly;
byte-30 `N` is the existing Negative edition suffix. Any additional declared
targets must have known identities/timings. No third starting-pack choice is
invented. Malformed/duplicate targets, stale seeds, mismatched decks/stakes and
unknown editions/timings fail closed.

An explicitly registered alternative is `filter_info.normal_opening`:

```lua
{schema=1,kind='normal_two_soul_v1',seed='<actual registered run seed>',
 deck_key='b_red',stake=8,required_souls=2,no_perishable_targets=true,
 targets={{key='j_yorick',location='soul_pack',edition='any'},
          {key='j_perkeo',location='soul_pack',edition='any'},
          {key='j_blueprint',location='by_ante_5',edition='any'},
          {key='j_burnt',location='by_ante_5',edition='any'}}}
```

The enclosing filter_info still needs the actual boolean
multi_soul_pack_consumed marker and `GAME.used_filter=true`. This example
documents a generic schema, not a hardcoded recommendation. Any valid pair of
distinct Legendary keys and normal vanilla deck/stake can use this route.

The public observation contains only canonical targets, deck/stake and current
one-use/pack/buffer status; the seed and search telemetry are removed.

## Actions and safeguards

- Skip only fresh Ante 1 / round 0 / Small Select / zero skips, with the actual
  public Charm Tag, no owned Jokers and at least two current Joker slots.
- Choose only an ordinary, visible, usable Soul from the actual marked first
  Charm pack. It uses no held consumable slot, so a full Magic-deck Tarot
  inventory is allowed. A held Soul or unknown inventory is outside the route.
- Require actual current Joker capacity and zero pending Joker buffer. After
  the first choice, compare the observed Legendary against the declared pair
  and its edition/nonperishable request before another choice. Wrong or
  unsupported acquisition is preserved as an ordinary fallback, never imputed.
- Every returned action is the next actual skip or choose callback. No sale,
  hidden card, later skip, scheduled acquisition, cash reserve or survival
  guarantee is manufactured.

Relevant read-only source: Core/Brainstorm.lua normal receipt at 1959 onward,
serialized target fields at 365 onward, shared Charm claim at 1643 onward;
Advisor/snapshot.lua normal receipt omission at 203 and pack mark at 213;
Core/challenge_opening.lua advice at 273 onward. Preserved original card.lua
under diagnostic287/b_preparation2/source has consumeable config copying at
302, Soul creation at 1415 and its capacity/use gate at 1557. Source methods
were read only, never executed by this task.

## Evidence scope

65 synthetic checks cover the successful three-action route through existing
Execution callbacks (mock game generation explicitly controlled by the fixture),
both receipt schemas, seed-free capture, source immutability, current slots,
full Tarot inventory, actual first acquisition, pending events, exhausted pack,
stale/bad inputs and no later skips. No original-source component, captured
replay, search, full attempt, game process, player profile or save was accessed.
No acquisition, terminal win or win-rate qualification follows from fixtures.
