# Cash-out readiness fixtures 317

This detached package adds one standalone execution fixture and appends focused cases to the existing runtime and automatic-run facade fixtures. It changes no runtime, policy, settings, saves, installed files or source experiment evidence. Root owns staging and release.

The source-shaped synthetic detached UIBox has config.major equal to the current round_eval, is registered in G.I.UIBOX, and returns a cash_out_button whose UIBox is the detached owner. All callbacks and game tables are manufactured. No source worker, game process, user log, save or profile is accessed.

Verified behavior: disabled buttons wait for readiness without consuming published advice, duplicate latches, automatic attempts or callbacks. Enabling the same button dispatches once. Callback failures retain their actual reason and consumed automatic failures stop without retry. Automatic waiting status exposes the exact readiness reason. Ordinary nonbutton legality still runs.

Ownership and bounded lookup checks cover stale or foreign anchors; foreign element owner; hidden element, ancestor or box; removed roots and boxes; disabled, substituted or missing callbacks; distinct direct/detached ambiguity even if one button is disabled; duplicate identical box/element deduplication; 512 versus 513 registry entries; cyclic and over-64 ancestry; malformed scalar config/state on the element and owner, which must fail safely without throwing. The existing nested shop subtree lookup is preserved and tested separately; this package makes no stronger shop ownership qualification claim.

Focused validation: 3/3 Lua fixtures, 801 checks (100 execution-button + 499 runtime + 202 automatic product), using the ordinary Lua fixture runner and isolated Lua 5.1 DLL. Tests load production module paths, never historical policy or draft modules. These are fixture checks, not source execution or live game acceptance evidence.

Root staging: run stage.py --check, review integration_manifest.json, then stage.py --stage --expected-manifest SHA. The helper validates all reviewed draft hashes and all current target base hashes before creating backups, rechecks before each write, preserves exact old fixture bytes, and creates the new test only if absent. It does not install or change versions. Full root regression and release remain separate.
