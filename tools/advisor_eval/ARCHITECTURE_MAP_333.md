# Current architecture —333

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_333.md`
and `.json`. Current work: `NEXT_PRIORITIES_333.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `COOPERATIVE_OBSERVATION_HOOKS_333.md`.

# Observation hook architecture — 333

Read the finalized session checkpoint and component note for installed hashes,
validation counts and limitations. This navigation grants no experiment authority.
The strategic capture, belief, immediate-order and execution boundaries remain
those documented in `ARCHITECTURE_MAP_332.md` and
`PUBLIC_JOKER_OBSERVATION_332.md`.

| Layer | Current source and navigation |
| --- | --- |
| Owned callback metadata | New `callback_hooks.lua` creates a registry with weak function keys and values and performs bounded ancestry recognition. No third-party closure inspection. |
| Action journal | `player_journal.lua` shares that registry and recognizes a retained journal wrapper beneath an owned observer wrapper. Action/result sequence linkage and settled-state capture are unchanged. |
| Public Joker observation | `acorn_public_hooks.lua` uses the same registry for passive callback installation. The evidence interpretation and hidden-identity safeguards remain in `acorn_public.lua` and its existing component note. |
| Runtime lifetime | `runtime.lua` creates one registry before journal attachment and injects it into public-hook attachment. Repeated update calls no longer alternate fresh wrappers for the same owned chain. |
| Stored evidence | `player_log_archive.lua` is unchanged: byte-preserving frames, compression, hashes, append readback and bounds retain their previous contract. |
| Regression map | New shared-hook/joint fixture under `development333/observer_component`; journal replacement/return/error fixture and existing journal/timing/archive checks under `development333/logger_component`. Root's production test map and exact-installed record supersede detached counts. |
| Player timing analysis | `development333/captured_log/timing.json` and `stall_index.json` summarize 78 supplied compact windows. Raw segment retained; no action or loaded-version records, no complete-tail claim. |

The component note is `COOPERATIVE_OBSERVATION_HOOKS_333.md`. The compact windows
locate most observed stall time inside the measured original game update. They
do not measure garbage-collector attribution or establish restored performance.
An existing loaded wrapper chain disappears only with the user's normal restart.

Historical source evidence remains under
`runs/loss328_validation_20260915/FINAL_SOURCE_EVIDENCE_332.json` and its closed
budget. No release-333 source experiment was run and none is pending.

Production tests: `tests/advisor_callback_hooks.lua`, `tests/advisor_logger_hooks.lua`, plus unchanged journal/timing/archive and public-Joker fixtures. Deployment and policy discovery include the new runtime-only helper automatically. Source adapters and pure scoring graph are unchanged.


Preserved earlier navigation: `ARCHITECTURE_MAP_332.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
