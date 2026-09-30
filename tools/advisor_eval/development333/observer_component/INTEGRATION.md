# Callback hook cooperation333

Core calls player journal install_hooks each frame; Advisor update calls Acorn hook install each frame. Eight overlapping callbacks each recognize only their own outer wrapper, so they wrap one another indefinitely. All layers remain reachable, and a later action repeats every logging and observation hook. This occurs even with logging off.

Manufactured production-module reproduction: after100idle frames one action invokes101public action beginnings and202journal events. Eight-callback1000idle-frame workload retains16000new wrappers and2059.52KiB aftercollection; candidate retains0new wrappers and3.43KiB. Synthetic workcount/allocation measurements, not measured liveFPS or sole-cause attribution.

Integration: NEW Advisor/callback_hooks.lua. Before player_journal.attach runtime sets A.callback_hooks=module('callback_hooks').new(). Pass {callback_hooks=A.callback_hooks} to acorn_public_hooks.attach. Copy detached acorn_public_hooks.lua after baseline hash check. Separate logger_component supplies player_journal.lua. Add test_callback_hooks.lua as production fixture, changing its three module paths to production modules. Existing Acorn fixture unchanged.

Registry metadata uses weak keys AND values. Values are direct original FUNCTIONS, never ephemeral metadata tables. Live wrapper closure already retains original strongly. Forced GC preserves live ancestry while retired original-owner-wrapper cycles disappear on Lua5.1. Bounded128-entry scan knows only product-registered ancestry; normal current ownedgraph has two layers. No debug/upvalue or hidden-state inspection.

Tests:60new assertions including1000idle frames with fullGC everytick, both installorders, zero newwrappers, one publicbegin/logpair, loggingoff, nilreturntuples, errors/rejections, callback/table replacement, legitimatenestedcallbacks, ancestrybound andweakcyclecollection. Existing115Acornobserver assertions pass. No source/game/profile/save initialization, captured-state replay or authority consumption.

Opaque third-party wrappers can close over prior product wrappers without exposing ancestry. We preserve them; duplicate inner/outer observations can occur after that unknown chain is newly wrapped. Repeated idle growth still stops. No global in_action suppression drops legitimate nested actions. No unsupported arbitrary-mod exactly-once claim is made. Original errors/returns unchanged.

No production/version/settings/save/DLL/installation edits by this component.
