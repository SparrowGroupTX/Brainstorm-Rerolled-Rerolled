local base='tools/advisor_eval/development333/'
local journal=dofile(base..'logger_component/player_journal.lua')
local hooks=dofile(base..'observer_component/acorn_public_hooks.lua')
local registry_module=dofile(base..'observer_component/callback_hooks.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local callbacks={'play_cards_from_highlighted','discard_cards_from_highlighted','buy_from_shop','use_card','sell_card','select_blind','cash_out','toggle_shop'}
local function fixture(logging)
  local counts={events=0,observes=0,source={},begins={},records=0}
  local g={GAME={},CONTROLLER={locks={}},jokers={cards={}},hand={cards={},highlighted={}},FUNCS={}}
  for _,name in ipairs(callbacks)do
    g.FUNCS[name]=function(a,b)counts.source[name]=(counts.source[name]or 0)+1;return nil,a,b,nil end
  end
  local t={reset=function()counts.reset=(counts.reset or 0)+1 end,invalidate=function()counts.invalid=(counts.invalid or 0)+1 end,
    begin_action=function(_,kind)counts.begins[kind]=(counts.begins[kind]or 0)+1 end,
    sync=function()end,drag_active=function()return false end,drag_finish=function()end}
  local registry=registry_module.new();local real_record=registry.record
  function registry:record(...)counts.records=counts.records+1;return real_record(self,...)end
  G=g
  local a={callback_hooks=registry};local b={config={advisor={player_logging=logging}}}
  local j=journal.attach(a,b,{game=function()return g end,observe=function()counts.observes=counts.observes+1;return {}end,
    now=function()return 'fixture'end,clock=function()return 1 end,
    append=function()counts.events=counts.events+1;return true end,notice=function()end})
  local h=hooks.attach(t,{callback_hooks=registry,env={G=g},game=function()return g end})
  return g,j,h,t,counts,registry,b
end
for _,logging in ipairs({true,false})do
  local g,j,h,t,c,r=fixture(logging)
  local entries={};for _,name in ipairs(callbacks)do entries[name]=g.FUNCS[name]end
  local records=c.records
  for i=1,1000 do j:install_hooks(g);h:update();collectgarbage('collect')end
  check(c.records==records,'idle ticks allocate no new retained callback wrappers')
  for _,name in ipairs(callbacks)do check(g.FUNCS[name]==entries[name],'1000 idle ticks retain stable '..name)end
  check(c.observes==0 and c.events==0,'idle ticks never log full observations')
  local function packed(...)return {n=select('#',...),...}end
  local result=packed(g.FUNCS.play_cards_from_highlighted('payload',42))
  check(result.n==4 and result[1]==nil and result[2]=='payload' and result[3]==42 and result[4]==nil,'return nil tuple preserved')
  check(c.source.play_cards_from_highlighted==1 and c.begins.play==1,'one callback and one public activation after1000 ticks')
  check(c.events==(logging and 2 or 0) and c.observes==(logging and 1 or 0),'one journal entry/outcome pair per callback')
  for i=1,100 do h:update();j:install_hooks(g)end
  check(c.records==records,'reverse installation order stable')
  -- A replaced base callback gets both hooks, without retaining or calling the old base.
  local replacements=0
  g.FUNCS.play_cards_from_highlighted=function()replacements=replacements+1;return 'replacement'end
  j:install_hooks(g);h:update();local replaced=g.FUNCS.play_cards_from_highlighted
  local new_records=c.records
  for i=1,100 do j:install_hooks(g);h:update()end
  check(g.FUNCS.play_cards_from_highlighted==replaced and c.records==new_records,'genuine replacement hooked once then stable')
  check(g.FUNCS.play_cards_from_highlighted()=='replacement' and replacements==1,'replacement callback preserved')
  check(c.source.play_cards_from_highlighted==1 and c.begins.play==2,'retired base not called')
  -- Legitimate nested gameplay callbacks must not be globally suppressed.
  g.FUNCS.play_cards_from_highlighted=function()g.FUNCS.discard_cards_from_highlighted();return 'nested'end
  j:install_hooks(g);h:update();local prior=c.events
  check(g.FUNCS.play_cards_from_highlighted()=='nested','nested call returns intact')
  check(c.begins.play==3 and c.begins.discard==1,'nested distinct actions both reach observer')
  check(c.events-prior==(logging and 4 or 0),'nested legitimate actions both recorded')
  -- Errors and explicit rejection propagate through the complete cooperative chain.
  g.FUNCS.use_card=function()error('fixture rejection',0)end
  h:update();j:install_hooks(g)
  local ok,err=pcall(g.FUNCS.use_card)
  check(not ok and tostring(err)=='fixture rejection','original callback error propagated')
  check(c.reset==1 and c.begins.use==1,'error resets inference once')
  g.FUNCS.use_card=function()return false,'not accepted'end
  j:install_hooks(g);h:update()
  local accepted,why=g.FUNCS.use_card()
  check(accepted==false and why=='not accepted' and c.invalid==1,'rejection preserved and invalidates once')
  -- Callback table replacement is a real installation boundary, including reused names.
  local fresh=0;g.FUNCS={play_cards_from_highlighted=function()fresh=fresh+1 end}
  j:install_hooks(g);h:update();g.FUNCS.play_cards_from_highlighted()
  check(fresh==1 and c.begins.play==4,'new callback owner gets both hooks once')
end
-- Metadata cannot retain a retired owner/closure graph through a weak-key value.
local r=registry_module.new();local weak=setmetatable({},{__mode='v'})
do
  local owner={};local original=function()return owner.current end
  local wrapper=function()return original()end
  owner.current=wrapper;r:record(wrapper,original)
  weak[1],weak[2],weak[3]=owner,original,wrapper
  check(r:contains(wrapper,original),'known parent recognized')
end
collectgarbage('collect');collectgarbage('collect')
check(weak[1]==nil and weak[2]==nil and weak[3]==nil,'retired owner/wrapper/parent cycle collectible')
-- Live wrapper strongly retains its parent so weak values do not lose ancestry.
do
  local original=function()return 1 end
  local wrapper=function()return original()end
  r:record(wrapper,original);collectgarbage('collect')
  check(r:contains(wrapper,original) and wrapper()==1,'live ancestry retained by actual callback closure')
  check(not pcall(r.record,r,wrapper,original),'metadata cannot be overwritten')
  check(not pcall(r.record,r,original,wrapper),'metadata cycle rejected')
  check(not pcall(r.record,r,original,original),'self-parent metadata rejected')
  check(not r:contains(wrapper,nil),'missing target never matches')
end
-- Ancestry walks stop at the explicit bound, even on a long manufactured chain.
do
  local chain=registry_module.new();local bottom=function()end;local current=bottom
  for i=1,registry_module.MAX_CHAIN+2 do
    local parent=current;local wrapper=function(...)return parent(...)end
    chain:record(wrapper,parent);current=wrapper
  end
  check(not chain:contains(current,bottom),'ancestry scan obeys128entry bound')
  check(chain:contains(current,current),'current wrapper remains a direct match')
end
-- Opaque external wrappers remain intact. Unknown ancestry is deliberately not
-- inspected; exact-once guarantees cover the registered product hook graph.
do
  local g,j,h,t,c,r=fixture(true)
  local inside=g.FUNCS.play_cards_from_highlighted;local external_calls=0
  g.FUNCS.play_cards_from_highlighted=function(...)external_calls=external_calls+1;return inside(...)end
  j:install_hooks(g);h:update();local stable=g.FUNCS.play_cards_from_highlighted;local records=c.records
  for i=1,100 do j:install_hooks(g);h:update()end
  check(stable==g.FUNCS.play_cards_from_highlighted and records==c.records,'opaque external wrapper never restarts idle growth')
  g.FUNCS.play_cards_from_highlighted()
  check(external_calls==1 and c.source.play_cards_from_highlighted==1,'opaque third-party callback preserved')
  check(c.begins.play==2 and c.observes==2,'opaque ancestry limitation explicit; no debug or global suppression')
end
print('callback_hooks333: '..checks..' checks passed')
