-- Compile fixture/adapters only, never execute source or the scenario body.
local root='tools/advisor_eval/development300/mechanics14/adapter/'
assert(type(assert(loadfile(root..'startup_fixture.lua'))())=='function')
assert(loadfile(root..'engine_run.lua'))
assert(loadfile(root..'engine_probe.lua'))
print('M14 syntax-only: 3 checks passed; no source execution')
