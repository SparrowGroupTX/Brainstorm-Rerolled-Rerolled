-- Routine syntax-only checks: loadfile compiles but does not execute any
-- source game, policy startup, fixture body or native call.
local base='tools/advisor_eval/development300/mechanics12/'
assert(type(assert(loadfile(base..'startup_fixture.lua'))())=='function')
assert(loadfile(base..'adapter/engine_run.lua'))
assert(loadfile(base..'adapter/engine_probe.lua'))
print('M12 syntax-only fixture: 3 checks passed; no source execution')
