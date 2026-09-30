-- Compile only; no returned source or wiring chunk is invoked.
local P='tools/advisor_eval/development300/complete_attempt9/'
local n=0
for _,name in ipairs({'engine_probe.lua','engine_run.lua','engine_contract.lua','normal_terminal.lua','gold_objective_context.lua','policy_wiring.lua','test_wiring.lua'})do assert(loadfile(P..name));n=n+1 end
print('C09 syntax: '..n..' Lua chunks compile; no source, policy or wiring execution')
