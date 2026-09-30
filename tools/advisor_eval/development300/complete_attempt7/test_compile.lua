-- Syntax only: returned chunks are never invoked.
local P='tools/advisor_eval/development300/complete_attempt7/'
local n=0
for _,name in ipairs({'engine_probe.lua','engine_run.lua','engine_contract.lua','normal_terminal.lua','gold_objective_context.lua','policy_wiring.lua','test_wiring.lua'})do assert(loadfile(P..name));n=n+1 end
print('C07 syntax: '..n..' Lua chunks compile without source initialization')
