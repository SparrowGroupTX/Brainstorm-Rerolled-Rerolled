-- Compile only. The returned source-adapter chunks are never called.
local p='tools/advisor_eval/development300/complete_attempt8/'
local n=0
for _,name in ipairs({'engine_probe.lua','engine_run.lua','engine_contract.lua','normal_terminal.lua',
 'gold_objective_context.lua','policy_wiring.lua','test_wiring.lua'}) do
 assert(loadfile(p..name));n=n+1
end
print('C08 syntax: '..n..' chunks compiled; no source initialization')
