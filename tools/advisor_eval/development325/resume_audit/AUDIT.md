# Auto-run Stop/Resume design audit — prospective325

This is a read-only audit of the current324 controller/product and existing manufactured fixtures, before325 implementation. It is not acceptance of a future implementation. Exact inspected hashes and line references are in `report.json`. No fixtures, policy decisions, search, source workers, captured replay, player logs, saves or profiles were executed/read. Historical experiment authority remains CLOSED.

The requested behavior requires a distinct Resume transition. Calling current `start()` would reset the session and can replace an existing run. The narrow safe design retains the same controller session, recipe, limits, run identity, action counters, terminal monitor and uncertain pending action while revalidating fresh live state before further work.

## Concrete hazards

- **Start resets history.** Controller `start` resets session serial, search number, total/run actions, runs, outcomes, clocks, found result and pending action. Product `start` also increments consent, changes advisor settings and builds a new arming request. Resume must have its own path and must not emit another `session_started` or `run_start_requested` for an existing run.
- **Stop currently destroys resume context.** Product `stop` clears its pending start and profile-table binding and disarms terminal monitoring. Controller stop overwrites its phase with `stopped`. Preserve the pre-stop phase and product ownership state for resumable explicit Stop. A hard invalidation must remain distinguishable from a user pause.
- **Ordinary input has two independent stopping mechanisms.** Product `manual` both increments `manual_generation` and stops. Removing only the stop call still fails controller generation matching on the next tick. Core keyboard/mouse hooks and HUD Stop currently use that same method. Route explicit Stop separately; ordinary input may delay readiness or invalidate advice, but must not masquerade as session revocation. Settings/checkpoint/profile changes retain their separate provenance checks.
- **Pending action is already spent.** Attempts are counted before logging/Execute. Stop can occur after callback acceptance, during animation, or after a thrown/false callback. Resume must never clear or re-dispatch that pending action merely because the same advice token exists. A changed, settled, freshly published public state can acknowledge it once, including a publication with no next action. Preserve uncertainty when acceptance/settlement is not established.
- **Search has ownership and an absolute deadline.** Stop cancels a pending owned search once; polling continues until actual exit. Wrong identities, failed polling and uncertain dispatch retain drain obligations. Resume while draining cannot start another search or launch a late result. A cancelled request's found result is discarded. Resume must not recreate that same request with a new budget/deadline; any distinct new search needs truthful new-work semantics and its original session limits.
- **Found and starting are different phases.** A found result already accepted before Stop can be retained with its original product object/key, request and profile binding; revalidate before launch. Stop after accepted `start_run` but before settled run binding must resume `starting` and recognize the already-created run, never invoke startup twice. Uncertain startup stays uncertain.
- **Elapsed limits and watchdogs are different.** Preserve session/run time origins and original search deadline; paused wall time must not silently renew these budgets. Repeated Resume must not reset action observation time or all progress timers. Menus/drags now block readiness, and the existing30-second watchdog can otherwise turn benign input into an indirect stop. Specify that boundary explicitly: a benign input wait may be reported separately, while genuinely missing advice/action settlement remains bounded and hard elapsed caps remain truthful.
- **Terminal evidence must survive Stop.** `auto_terminal:arm` replaces its bound final context/callback history. Rearming the same run on Resume destroys evidence; disarming on Stop misses delayed callbacks. Retain the original binding and counted-terminal identity through a resumable Stop. Terminal processing after Resume is once-only, followed by a separate fresh Gold-metadata observation before further search.
- **Run/profile equivalence cannot be guessed.** Product run IDs bind actual `G.GAME` table identity; profile validation includes actual loaded table identity. A same-seed replacement/checkpoint reload or same-number replacement profile is not the original context. Reject implicit rebinding. If a fresh product instance supports explicit adoption of an existing run, label it as adoption with unavailable prior accounting/terminal evidence, and never infer earlier success from `GAME.won`.
- **Resume itself may fail.** Check monotonic finite time, logging, full binding, limits, current owned/external search state, terminal evidence and fresh publication before any dispatch. A failed Resume must preserve original reason, pending action, counters and ownership. Stop during the final gate, log failure and callback exceptions must still prevent unintended dispatch; reentrant tick/Resume must not cause duplicate work.

## Required phase behavior

| Stopped phase | Safe continuation | Work that must not occur on Resume |
| --- | --- | --- |
| Product arming before controller start | Retain exact options/context and original startup deadline; wait for readiness | Reset startup allowance or accept replacement GAME/profile |
| Waiting for first search | Continue same unused request opportunity within same session limits | Reset session or search numbering |
| Owned search pending/cancel draining | Retain ownership and drain; explain cancelled request disposition | Start concurrent/replacement worker or launch late found |
| Accepted found, not launched | Revalidate retained exact result/request/profile and continue once | Re-search or fabricate a replacement found object |
| Accepted run starting | Wait for the already-created run to become ready | Invoke start_run again |
| Playing or waiting advice | Revalidate same run and current publication | Reset counters or use a stale action token |
| Pending action | Observe fresh settled completion once; otherwise preserve uncertainty | Reissue the action or reset its spent attempt |
| Verified terminal | Preserve counted outcome; separately refresh loaded collection metadata | Count again or infer an unobserved win |
| Hard invalidation/limit/unknown callback | Expose concrete non-resumable or explicitly reconciled condition | Clear evidence/limits merely to enable the button |

## Manufactured validation required before release

Test Stop/Resume at each phase above, including before/after every callback. Assert zero duplicate search/start/Execute calls and exact unchanged session/run counters, IDs, options and elapsed origins. Cover repeated Stop/Resume, resume while active/draining, cancel failure/throw, late/wrong-request found, deadlines crossed during Stop and during poll, and current run present in every resumable phase.

Update old tests that intentionally expect keyboard/mouse/menu to stop. New input tests must cover pending arming, search, run startup, pending action and ready gameplay; verify exact advice refresh after manual card changes and no action during drag/menu/locks. Preserve ready-unsupported pending acknowledgement, final-gate staleness and stop reentrancy tests.

Cover profile number/table replacement, same-seed new GAME, checkpoint/settings generation change, unavailable/regressing clock, disabled/failed log, unchanged-token pending action, false/thrown execution, action-log rejection, all four hard limits, original terminal callbacks occurring while explicitly stopped, repeated terminal receipt, and no terminal evidence on a newly adopted already-ended run. Verify status reads are pure and UI Stop and Resume remain distinct from input notification.

Existing relevant suites are `advisor_auto_run.lua`, `advisor_auto_run_product.lua`, `advisor_auto_observation.lua` and terminal-monitor fixtures. Their current passes establish324 behavior only. This audit ran no tests and makes no gameplay, outcome, performance or odds claim.
