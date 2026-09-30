-- Parse only: no source/module/game execution.
local root='tools/advisor_eval/development300/mechanics18/adapter/'
for _,name in ipairs({'startup_fixture.lua','startup_menu_support.lua','engine_probe.lua','engine_run.lua'})do
  assert(loadfile(root..name))
end
print('M18: four Lua chunks parsed without execution')
