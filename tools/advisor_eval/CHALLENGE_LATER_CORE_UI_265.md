# Conditional later target: Core/UI evidence for 2.65

2026-09-11. Core/UI work is complete and paused for the parent integration freeze, full regression and installation. This record does not claim installation itself.

## Product behavior

- Keeps the existing first Charm pack/two different Legendary opening. The optional later filter defaults off. Disabled mode still uses the original three-argument v1 callback.
- Adds one optional target from the complete original 20-Rare catalog and a by-end-of-Ante deadline from 2 through 8. Native v2 reports a conditional initial-shop offer. Purchasing, affording, surviving to and retaining it are unverified. Typecast's admitted offer horizon ends at Ante 4; Bram has no admitted later-shop route; Jokerless remains excluded entirely.
- Before v2 search and again before attaching a candidate, validates the original fresh challenge, exact starting row/Eternal/Negative/pinned state, fixed Rare pool and public unlock/ban/ownership mask, expected shop slots/rates, relevant modifiers, and absence of pending tags, forced tutorial stock or saved shop stock. An unsupported or changed profile fails closed.
- Stores detached `filter_info.later` metadata: target, deadline, pool mask and permitted keys, original shop rates/slots, versioned schedule/source, predicted offer position/edition/Eternal, and explicit false acquisition/retention verification flags. Parent Advisor integration consumes this record to qualify the route against current observations.
- Stores cumulative search batches, complete miss batches, cursors and measured native-call time in `filter_info.search`. `ChallengeOpening.last_search` also retains stopped/error searches. Missing/invalid clocks are explicit; batch limits are never described as actual evaluated-seed counts. Native-call timing excludes gameplay and other setup/action costs.
- The two-column settings page retains the Legendary controls and adds later controls, conditional restrictions, current predicted offer and search costs. Rendering or changing preferences never starts native search or gameplay. Run replacement remains behind the existing explicit user start path.

The conditional schedule is `first_charm_then_play_all_fixed_rare_pool`: play later blinds without further skips, rerolls, packs or voucher purchases; retain both opening Legendaries; do not acquire, sell or generate another Rare before the target offer; no Showman or Joker-generating consumables. Other Common/Uncommon support purchases and sales are allowed. The separate native original-source Riff-Raff boundary evidence permits its Common generation; the UI does not prohibit it. Target purchase ends the forecast.

## Focused validation

Final focused evidence: `runs/challenge_later265_focus8/output.log`, three fixtures, 310 checks passed under a hidden 45-second worker cap:

- `tests/advisor_challenge_opening.lua`: 70 legacy checks.
- `tests/advisor_challenge_opening_ui.lua`: 55 checks, including all four selectors/two toggles, malformed events, no implicit starts, two columns, all route disclosures and the maximum-height found-offer/search-cost layout.
- `tests/advisor_challenge_later.lua`: 185 checks, including exact source profiles, strict v2 echoes, Typecast cap, metadata isolation, stale configuration/profile rejection, disabled v1 dispatch, cursor continuity, cumulative 3-batch/2-miss/3.75-second timing, error/stop preservation and unavailable clocks.

`challenge_later_core_source.py` and `.lua` additionally tested the final Core against original fresh challenge starts, before opening packs or playing any blinds. `runs/challenge_later265_core_source3/summary.json` records 36/36 passes (18 supported challenges times `source_defaults_v1` and `all_unlocked_discovered_v1`), 1.625 seconds under a hidden 45-second cap. Each case preserves its declared profile digest, result and durable status; `provenance.json` records Core, driver, payload, engine bootstrap, Lua runtime and all ZIP Lua source hashes. Frozen inputs are copied into that output directory. Complete stdout is retained in `runs/challenge_later265_core_source3_host/output.log`.

These are admission/protocol/UI checks, not survival, acquisition, retention, seed-search throughput or win-rate evidence. The source harness uses declared synthetic profiles and isolated Lua execution. It reads the executable as a ZIP; it does not launch the executable, access physical saves or control the running game. Mock UI checks do not establish pixel-perfect rendering in the live game.

Earlier runs remain preserved. `challenge_later265_core_source1` records a driver Lua literal-spacing failure before any case ran; source2 passed 36 cases before later search-cost-only bookkeeping changed the Core hash. Focus6 preserves a Lua fixture's `and nil or` clock-mock error; it was corrected in the fixture, and focus7/focus8 passed. No failure directories were removed or rewritten.

## Final owned file hashes

SHA256, after the final edits and before the parent integration freeze:

| File | SHA256 |
| --- | --- |
| `Brainstorm/Core/challenge_opening.lua` | `972d8c8ad5a46ceb9c2323c18bbb060cbb0cd2e9810bc6593e3fae5967e87843` |
| `Brainstorm/UI/challenge_opening.lua` | `9af9961ea639d9d31958c7af7a8a5104d804a55d5dc6d4e2278e1666410cb846` |
| `tests/advisor_challenge_later.lua` | `f2d0a3426ef4fe41eab69dfbe32bb554e8dd87be053289adb9121d7dcee75c08` |
| `tests/advisor_challenge_opening_ui.lua` | `bd0c2d67e5bfedcd4bca1e999c5a1e57b45451264d52621f44b9f1b232477c4e` |
| `tools/advisor_eval/challenge_later_core_source.py` | `394b252d4ef8f18dbd0f9181765a6452dfef2d78342e6be5c1d9e105480426d2` |
| `tools/advisor_eval/challenge_later_core_source.lua` | `7371536d9a4c16d7656605d516717fb871c42e6827d9397a1d57b1f675e63c0c` |

Native source/sidecar evidence, Advisor route guidance, whole-product validation, release version and deployment receipts are owned by the parent integration record and supersede this component readiness note.
