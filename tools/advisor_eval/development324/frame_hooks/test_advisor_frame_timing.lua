-- Manufactured clocks/callbacks only. No game, native call, profile or save.
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function equal(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b,label)check(type(a)=='number' and math.abs(a-b)<1e-9,label)end
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local core=read('Brainstorm/Core/Brainstorm.lua')
local first=assert(core:find('local update_ref = Game.update',1,true))
local last=assert(core:find('function Brainstorm.autoReroll()',first+1,true))
local wrapper=core:sub(first,last-1)
local function install(body,e)
  setmetatable(e,{__index=_G});local f=assert(loadstring(body));setfenv(f,e);return f()
end
local function collector(clock,enabled)
  local p={spans={},events={},calls=0,enabled=enabled~=false}
  function p:now()self.calls=self.calls+1;if self.enabled then return clock.value end end
  function p:finish(label,started)
    self.events[#self.events+1]=label
    local ended=self:now()
    if self.fail_label==label then return nil end
    if ended then self.spans[label]=(self.spans[label]or 0)+ended-started end
    return ended
  end
  function p:begin_frame(dt)
    self.begin_dt=dt;local t=self:now();local gap=t and self.previous and t-self.previous
    self.previous=t;return t,gap
  end
  function p:end_frame(start,gap,flags)
    self.events[#self.events+1]='end_frame';self.flags=flags;self.gap=gap
    self.spans.update_total=clock.value-start;self.end_time=clock.value
  end
  function p:flush(journal,flags)
    self.events[#self.events+1]='flush';self.flush_journal=journal;self.flush_flags=flags
    -- The collector owns the due gate. A fake emission costs .25 wall seconds.
    if self.emit then clock.value=clock.value+.25 end
  end
  return p
end
local function core_setup(with_perf,enabled)
  local clock={value=10};local p=collector(clock,enabled)
  local order={};local observed={};local durations={original=.1,checkpoint=.2,search=.3,hooks=.04,journal=.36,advisor=.5,auto=.6,legacy=.7}
  local function call(name,dt)
    order[#order+1]=name;observed[name]=dt;clock.value=clock.value+durations[name]
  end
  local B={config={keybinds={a_reroll='a'}},ar_active=true,ar_frames=0,ar_timer=0,AR_INTERVAL=.001,
    Checkpoints={update=function(_,dt)call('checkpoint',dt)end},
    CollectionSearchProduct={update=function()call('search')end},
    Advisor={worker={},player_log={install_hooks=function()call('hooks')end,update=function()call('journal')end},
      update=function(dt)call('advisor',dt)end},
    AutoRun={update=function(_,dt)call('auto',dt);return {active=true,secret='not copied'}end},
    autoReroll=function()call('legacy');return false end}
  if with_perf then B.Advisor.performance=p end
  local g={STATE=2,STAGE=1,SETTINGS={GAMESPEED=16,paused=false},
    GAME={round=7,round_resets={ante=3}},CONTROLLER={dragging={target={}}}}
  local e={Brainstorm=B,G=g,Game={update=function(self,dt)observed.instance=self;call('original',dt);return 'ignored'end},
    love={keyboard={isDown=function()return false end}}}
  install(wrapper,e);local instance=setmetatable({},{__index=e.Game})
  return instance,B,g,p,clock,order,observed,e
end
do
  local game,B,g,p,clock,order,observed=core_setup(true)
  p.emit=true
  equal(game:update(.037),nil,'original wrapper ignored return remains ignored')
  equal(table.concat(order,','),'original,checkpoint,search,hooks,journal,advisor,auto,legacy','callbacks retain exact order')
  equal(observed.instance,game,'original self preserved')
  for _,name in ipairs({'original','checkpoint','advisor','auto'})do equal(observed[name],.037,name..' dt forwarded unchanged')end
  equal(p.begin_dt,.037,'update argument dt independent of selected speed')
  local expected={game_update=.1,checkpoint_update=.2,search_update=.3,journal_update=.4,advisor_update=.5,auto_update=.6,legacy_reroll=.7}
  local sum=0;for key,value in pairs(expected)do near(p.spans[key],value,key..' independent duration');sum=sum+value end
  near(p.spans.update_total,sum,'total contains sequential spans exactly')
  near(clock.value-p.end_time,.25,'trailing emission excluded from total')
  equal(p.events[#p.events-1],'end_frame','total ends before emission')
  equal(p.events[#p.events],'flush','emission follows frame completion')
  equal(p.flush_journal,B.Advisor.player_log,'collector receives existing journal only')
  equal(p.flush_flags,p.flags,'same bounded scalar flags passed to collector')
  equal(p.flags.state,2,'state flag');equal(p.flags.stage,1,'stage flag');equal(p.flags.ante,3,'ante flag')
  equal(p.flags.round,7,'round flag');equal(p.flags.game_speed,16,'speed flag')
  equal(p.flags.paused,false,'paused boolean');equal(p.flags.dragging,true,'drag boolean')
  equal(p.flags.advisor_worker,true,'worker boolean');equal(p.flags.auto_active,true,'existing returned status used')
  local allowed={state=true,stage=true,ante=true,round=true,game_speed=true,paused=true,dragging=true,advisor_worker=true,auto_active=true}
  for k,v in pairs(p.flags)do check(allowed[k] and (type(v)=='number'or type(v)=='boolean'),'flags whitelist scalar '..k)end
  clock.value=clock.value+.5;game:update(.004)
  near(p.gap,sum+.25+.5,'frame gap includes prior emission and between-update wait')
end
do
  local game,B,g,p,clock,order=core_setup(false)
  game:update(.01);equal(p.calls,0,'absent optional collector receives no clock calls')
  equal(#order,8,'absent collector preserves all callbacks')
  game,B,g,p,clock,order=core_setup(true,false)
  g.GAME=setmetatable({},{__index=function()error('disabled telemetry must not inspect game flags')end})
  game:update(.01);equal(p.calls,1,'disabled collector only checks enabled at frame entry')
  equal(#p.events,0,'disabled mode has no finish flags or flush work');equal(#order,8,'disabled preserves callbacks')
end
do
  local game,B,g,p,clock,order=core_setup(true)
  B.AutoRun.update=function()order[#order+1]='auto';return false end
  g.STATE='non numeric';g.STAGE=0/0;g.GAME.round=math.huge;g.GAME.round_resets.ante=-math.huge;g.SETTINGS.GAMESPEED={}
  game:update(.01)
  equal(p.flags.state,nil,'nonnumeric state omitted');equal(p.flags.stage,nil,'NaN stage omitted')
  equal(p.flags.round,nil,'infinite round omitted');equal(p.flags.ante,nil,'infinite ante omitted')
  equal(p.flags.game_speed,nil,'nonscalar speed omitted');equal(p.flags.auto_active,nil,'unknown auto status omitted')
end
do
  local game,B,g,p,clock,order=core_setup(true)
  p.fail_label='search_update';game:update(.01)
  equal(#order,8,'failed-open finish does not suppress callbacks')
  equal(p.spans.advisor_update,nil,'invalid timing chain produces no invented later interval')
  equal(p.events[#p.events],'flush','collector still controls bounded flush after clock failure')
end
do
  local game,B,g,p,clock,order,observed,e=core_setup(true)
  local marker={error=true};B.Checkpoints.update=function()error(marker,0)end
  local ok,why=pcall(game.update,game,.01)
  check(not ok and why==marker,'checkpoint errors preserve exact error identity')
  equal(table.concat(order,','),'original','error prevents later callbacks as before')
  equal(p.end_time,nil,'failed frame has no fake completed total');equal(p.flush_flags,nil,'no flush after propagated error')
  e.Game.update=function()error(marker,0)end
  install(wrapper,e);game=setmetatable({},{__index=e.Game})
  ok,why=pcall(game.update,game,.01);check(not ok and why==marker,'original update error propagates unwrapped')
end

-- Load the full actual UI module with harmless UI globals; only call Game:draw.
local function ui_setup(with_perf,enabled)
  local clock={value=40};local p=collector(clock,enabled);local order={};local observed={}
  Brainstorm={Advisor={display={},defaults=function()end},config={advisor={}}}
  if with_perf then Brainstorm.Advisor.performance=p end
  G={FUNCS={},SETTINGS={}};love={mousepressed=function()end}
  Game={draw=function(self,...)
    order[#order+1]='original';observed.self=self;observed.n=select('#',...);observed.args={...}
    clock.value=clock.value+.2;return 'ignored'
  end}
  dofile('Brainstorm/UI/advisor.lua')
  Brainstorm.Advisor.draw=function()order[#order+1]='hud';clock.value=clock.value+.05 end
  local instance=setmetatable({},{__index=Game})
  return instance,p,clock,order,observed
end
do
  local game,p,clock,order,observed=ui_setup(true)
  equal(game:draw('a',nil,3),nil,'draw wrapper still ignores original return')
  equal(table.concat(order,','),'original,hud','draw order preserved');equal(observed.self,game,'draw self preserved')
  equal(observed.n,3,'draw nil vararg arity preserved');equal(observed.args[1],'a','first draw argument');equal(observed.args[3],3,'last draw argument')
  near(p.spans.original_draw,.2,'original draw duration');near(p.spans.advisor_hud_draw,.05,'HUD draw duration')
  near(p.spans.draw_total,.25,'draw total inclusive of original and HUD')
  equal(p.flush_flags,nil,'draw never emits a journal record')
  local marker={draw_error=true};Brainstorm.Advisor.draw=function()error(marker,0)end
  local ok,why=pcall(game.draw,game);check(not ok and why==marker,'HUD error propagates unchanged')
  near(p.spans.draw_total,.25,'failed draw does not add a fake completed total')
end
do
  local game,p,clock,order=ui_setup(false)
  game:draw();equal(p.calls,0,'absent draw collector has no clocks');equal(#order,2,'absent collector preserves both draws')
  game,p,clock,order=ui_setup(true,false)
  game:draw();equal(p.calls,1,'disabled draw collector only enabled check');equal(#p.events,0,'disabled draw has no span or emission')
  local marker={original_draw_error=true};Game.draw=function()error(marker,0)end
  Brainstorm.advisor_ui_hooks=nil;dofile('Brainstorm/UI/advisor.lua')
  game=setmetatable({},{__index=Game});local ok,why=pcall(game.draw,game)
  check(not ok and why==marker,'original draw error propagates unwrapped')
end
print('advisor_frame_timing: '..checks..' checks passed')
