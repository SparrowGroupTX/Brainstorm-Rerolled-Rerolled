-- Manufactured callbacks and append sink only. No game, logs, saves or source execution.
local journal=dofile('tools/advisor_eval/development333/logger_component/player_journal.base.lua')
local observer=dofile('tools/advisor_eval/development333/logger_component/acorn_public_hooks.base.lua')
local source_calls,observed,lines,begins=0,0,0,0
local g={GAME={},STATES={},STATE_COMPLETE=true,CONTROLLER={locks={}},FUNCS={}}
g.FUNCS.play_cards_from_highlighted=function()source_calls=source_calls+1;return 'ok'end
local A={snapshot={capture=function()observed=observed+1;return {phase='hand'}end,
 fingerprint=function()return 'fixed'end}}
local B={config={advisor={player_logging=true}}}
local J=journal.attach(A,B,{game=function()return g end,append=function()lines=lines+1;return true end,now=function()return 'fixed'end})
local tracker={}
for _,key in ipairs({'reset','invalidate','display','before_hide','drag_start','remember','shuffle','sync','drag_finish'})do tracker[key]=function()end end
tracker.begin_action=function()begins=begins+1 end
local H=observer.attach(tracker,{game=function()return g end,env={}})
for _=1,30 do J:install_hooks(g);H:update()end
assert(g.FUNCS.play_cards_from_highlighted()=='ok')
print('manufactured_frames=30 source_calls='..source_calls..' observations='..observed..' journal_lines='..lines..' observer_begins='..begins)
assert(source_calls==1 and observed==30 and lines==60 and begins==31,'Baseline reproduction changed.')
