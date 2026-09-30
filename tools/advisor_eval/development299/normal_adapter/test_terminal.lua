-- Routine pure fixture: synthetic callback/profile doubles, no original source.
local M=dofile('tools/advisor_eval/development299/normal_adapter/normal_terminal.lua')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local valid={game_over=false,final_boss=true,source_won=true,deck_progress=true,joker_progress=true,threshold_met=true}
check(M.classify(valid)=='win','all independent normal win evidence required')
for _,key in ipairs({'source_won','final_boss','deck_progress','joker_progress','threshold_met'}) do
  valid[key]=false;check(M.classify(valid)==nil,'missing '..key..' is not win');valid[key]=true
end
valid.game_over=true;check(M.classify(valid)=='loss','GAME_OVER overrides incidental win flag and progress');valid.game_over=false
valid.threshold_met=false;valid.source_saved=true
check(M.classify(valid)=='win','explicit source survival can qualify below target')
valid.game_over=true;check(M.classify(valid)=='loss','source saved cannot override actual loss')
local g={GAME={stake=8,won=true,chips=100,target=100,round_resets={ante=8},win_ante=8,blind={boss=true,chips=100},
  selected_back={effect={center={key='b_red'}}}},SETTINGS={profile=1},PROFILES={{deck_usage={},joker_usage={}}},
  jokers={cards={{config={center={key='j_yorick'}}}}},STATE=1,STATES={GAME_OVER=2}}
set_deck_win=function()g.PROFILES[1].deck_usage.b_red={wins={[8]=1}}end
set_joker_win=function()g.PROFILES[1].joker_usage.j_yorick={wins={[8]=1}}end
Card={calculate_joker=function()return {}end}
end_round=function()end
local trace={};local S=M.attach(g,function(e)trace[#trace+1]=e end,function(v)return v end)
check(not S:completed(),'GAME.won without original callback receipts rejected')
end_round();g.GAME.round_resets.ante=9
set_deck_win();check(not S:completed(),'deck callback alone rejected')
set_joker_win();check(S:completed() and #trace==3,'both callback effects plus preceding final context observed after ante advanced')
g.STATE=2;check(not S:completed(),'actual loss still overrides recorded progress')
print('normal_adapter_terminal: '..checks..' checks passed')
