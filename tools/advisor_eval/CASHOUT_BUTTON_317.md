# Cash-out button ownership and readiness —317

The user confirmed2.116 now searches, then reported that auto-run could not
leave its first cleared round. The opt-in public action log independently
declares loaded2.116. At20:16:26UTC it records a cash_out recommendation and
attempt, a rejection saying the game button was not ready, then execute_failed.
The user's manual cash_out at20:16:31 was accepted and the next public state
was shop at20:16:32. This is a live startup/transition diagnosis, not a policy
counterfactual or evidence of a complete win.

The read-only receipt `development299/public_cashout317.json` contains hashes
and a narrow final-event projection of three specifically identified public
log segments,138records total. It omits inventory details and contains no save
or hidden-state evaluation. Original log bytes were not changed. Reader:
`development299/read_round317.py`. The earlier2.116 search confirmation is also
recorded in `CURRENT_OBJECTIVES_316.md`.

Preserved original `functions/common_events.lua`1065–1093 creates Cash Out in
a separate UIBox after a delayed payout event, with `config.major=G.round_eval`.
Its whole source SHA522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc
matches the retained M13 provenance. The previous production execution lookup
searched only inside G.round_eval, so it could never find vanilla's detached
button. Existing execution fixtures incorrectly placed the button directly
inside that object. Source-attempt adapters invoked cash_out directly and also
bypassed this production lookup; reaching shops in those attempts did not test
the user's actual UI path.

Fresh one-use M24 inspected six complete methods in three ZIP members,
6159source bytes,0.125seconds, no Lua/policy/native/game execution. It confirms
UIBox:init retains config.major and registers the object in G.I.UIBOX;
UIElement:init assigns its UIBox; get_UIE_by_ID can traverse nested objects;
UIBox:remove unregisters it; cash_out clears the button then queues the shop
transition. Source receipts are under `runs/gold299_20260914/M24`. Node.remove
was not inspected; optional REMOVED/removed checks are conservative guards,
not a claim about that uninspected method. All24 mechanical slots are spent;
this result creates no replacement authority.

`Advisor/execution.lua` now resolves a unique visible Cash Out element from
the current results panel or a registered UIBox anchored to that exact panel.
The element must belong to its candidate UIBox. Foreign/stale anchors, hidden
or removed owners, ambiguous buttons and invalid/cyclic ancestry are rejected.
The complete registry lookup is capped at512entries and ancestry at64nodes;
exceeding either bound declines, without partial selection. Duplicate references
to the same element do not create ambiguity. An unready second candidate still
prevents choosing between two owned buttons. The existing shop subtree lookup
retains nested UIBox support.

A pure `button_ready` observation is shared with runtime's existing Execute
gate. It calls no game callback, changes no selection/latch/UI and performs no
scoring. Auto-run's existing can_execute wait occurs before an action attempt
is consumed, so payout animation can settle normally. Execution re-resolves
the button just before dispatch; callbacks still run once through vanilla.
Every prior freshness, checkpoint, logging, ownership and duplicate-action guard
remains. An action that may have started still stops on failure and is never
silently retried. Runtime and Core now preserve the actual rejection reason,
and waiting status shows it instead of a bare false or generic waiting count.

Meaningful routine fixtures cover the source-shaped detached button, delay,
ownership/visibility/ambiguity, pure repeated reads, normal shop nesting,
runtime publication/latch preservation, one eventual auto cash-out and stopped
callback failures. `tests/advisor_cashout_button.lua`, `advisor_execution.lua`,
`advisor_runtime.lua` and `advisor_auto_run_product.lua` are the main checks.
One early existing fixture expected "not ready" in its reason; that exact
wording was retained in the more specific wait message and the313-check
execution fixture then passed. No runtime guard was relaxed for that test.

Release receipts: `runs/cashout317_candidate`, `cashout317_installed`,
`cashout317_installed_validation` and `cashout317_final`. The installed update
still needs the user's normal restart and a live transition observation.
Tools have not controlled the game, pressed keys or inspected player saves.

Separate development results completed before this fix: M22 proves same physical
copy reorders with fewer scores in two dependent captured states; C06 exact315
timed out in Ante6 shop after163legalactions/20exactplays, no terminal or Gold
award. Those results belong to their frozen policies and are not transferred
to317. The optional pack five-card family remains an untested detached draft;
the additive-growth sorting issue is separate ongoing work.
