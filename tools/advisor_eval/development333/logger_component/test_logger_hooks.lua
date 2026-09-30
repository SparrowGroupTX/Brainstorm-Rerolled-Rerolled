-- Manufactured callbacks and write sink, no live game or source mechanics.
local base='tools/advisor_eval/development333/'
local M=dofile(base..'logger_component/player_journal.lua')
local Registry=dofile(base..'observer_component/callback_hooks.lua')
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function packed(...)return {n=select('#',...),...}end
local function contains(s,value)return s:find(value,1,true)~=nil end
local lines,captures,calls={},0,0
local g={GAME={},STATE_COMPLETE=true,STATES={},CONTROLLER={locks={}},FUNCS={}}
local function initial(a,b)calls=calls+1;check(a=='first'and b==12,'all callback arguments forwarded');return nil,'second',nil end
g.FUNCS.play_cards_from_highlighted=initial
local hooks=Registry.new()
local A={callback_hooks=hooks,snapshot={capture=function()captures=captures+1;return {phase='hand'}end,fingerprint=function()return 'same'end}}
local B={config={advisor={player_logging=true}}}
local log=M.attach(A,B,{game=function()return g end,now=function()return 'fixed'end,
 append=function(raw)lines[#lines+1]=raw;return true end})
log:install_hooks(g)
local first=g.FUNCS.play_cards_from_highlighted
local outer_calls=0
local function outer(...)outer_calls=outer_calls+1;return first(...)end
hooks:record(outer,first);g.FUNCS.play_cards_from_highlighted=outer
for _=1,1000 do log:install_hooks(g)end
check(g.FUNCS.play_cards_from_highlighted==outer,'1000 installs preserve another owned outer wrapper')
local out=packed(g.FUNCS.play_cards_from_highlighted('first',12))
check(out.n==3 and out[1]==nil and out[2]=='second'and out[3]==nil,'nil-bearing return tuple retained')
check(calls==1 and outer_calls==1 and captures==1 and #lines==2,'one physical callback has one before/after observation')
check(contains(lines[1],'"sequence":1')and contains(lines[2],'"action_sequence":1'),'continuous request/result linkage')
log:update(g)
check(captures==2 and #lines==3 and contains(lines[3],'"kind":"state_after_actions"'),'settled state still recorded')
local replacements=0
g.FUNCS.play_cards_from_highlighted=function()replacements=replacements+1;return false,'rejected',nil end
log:install_hooks(g)
local replacement_hook=g.FUNCS.play_cards_from_highlighted
for _=1,1000 do log:install_hooks(g)end
check(g.FUNCS.play_cards_from_highlighted==replacement_hook and replacement_hook~=outer,'genuine callback replacement wrapped once')
out=packed(g.FUNCS.play_cards_from_highlighted())
check(out.n==3 and out[1]==false and out[2]=='rejected'and out[3]==nil,'explicit rejection tuple retained')
check(replacements==1 and calls==1 and outer_calls==1,'replacement does not resurrect stale callback chain')
check(captures==3 and #lines==5 and contains(lines[5],'"callback_returned":false'),'rejection recorded once')
check(not log.pending_state,'rejected callback does not invent pending settled action')
g.FUNCS.play_cards_from_highlighted=function()error('synthetic callback error')end
log:install_hooks(g)
local ok,why=pcall(g.FUNCS.play_cards_from_highlighted)
check(not ok and contains(why,'synthetic callback error'),'callback exceptions remain visible')
check(captures==4 and #lines==7 and contains(lines[7],'"callback_returned":false'),'exception has one linked failed result')
B.config.advisor.player_logging=false
g.FUNCS.play_cards_from_highlighted=function()return 'disabled'end
log:install_hooks(g)
check(g.FUNCS.play_cards_from_highlighted()=='disabled','disabled recorder preserves callback')
check(captures==4 and #lines==7,'disabled recorder does no capture or writing')
-- New function table is an actual source replacement, not equivalent by name.
B.config.advisor.player_logging=true
g.FUNCS={play_cards_from_highlighted=function()return 'new table'end}
log:install_hooks(g)
check(g.FUNCS.play_cards_from_highlighted()=='new table','new callback table is installed')
check(captures==5 and #lines==9,'new callback table records once')
print('logger_shared_hooks: '..checks..' checks passed')
