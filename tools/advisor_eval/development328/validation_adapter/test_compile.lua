local P='tools/advisor_eval/development328/validation_adapter/'
local n=0
for _,name in ipairs({'engine_run.lua','engine_probe.lua','engine_contract.lua','normal_terminal.lua','gold_objective_context.lua','policy_wiring.lua','information_scope.lua'})do
  assert(loadfile(P..name));n=n+1
end
local boundary=dofile(P..'information_scope.lua')
assert(boundary.check({jokers={{face_down=false}}}))
local poison=setmetatable({face_down=true},{__index=function(_,key)error('Concealed identity field must not be read: '..key)end})
local accepted,gap=boundary.check({phase='hand',ante=8,round=23,blind={key='bl_final_acorn'},jokers={poison}})
assert(not accepted and gap.hidden_joker_count==1 and gap.policy_evaluated==false)
assert(not boundary.check({jokers={{facing='back'}}}))
assert(not boundary.check({jokers={{identity_redacted=true}}}))
print(n..' Lua chunks compile; pure concealed-Joker boundary checks pass; source initialization=0')
