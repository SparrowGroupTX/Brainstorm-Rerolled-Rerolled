local T=dofile('Brainstorm/Core/auto_terminal.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function fixture(asynchronous)
  local g={STATES={GAME_OVER=99},STATE=3,SETTINGS={profile=1},PROFILES={[1]={deck_usage={},joker_usage={}}},
    GAME={stake=8,round=23,round_resets={ante=8},win_ante=8,chips=1000,blind={boss=true,chips=1000},
      selected_back={effect={center={key='b_red'}}},seeded=false},
    jokers={cards={{config={center_key='j_yorick',center={key='j_yorick'}}}}}}
  local function increment(kind,key)
    local profile=g.PROFILES[g.SETTINGS.profile];profile[kind][key]=profile[kind][key]or{wins={}}
    local w=profile[kind][key].wins;w[8]=(w[8]or 0)+1
  end
  local gl={end_round=function()g.GAME.won=true;g.GAME.round_resets.ante=9;return 'end',nil,3 end,
    set_joker_win=function()increment('joker_usage','j_yorick');return 17 end,
    set_deck_win=function()increment('deck_usage','b_red');return 19 end}
  gl.create_UIBox_win=function()return{config={id='you_win_UI'}},nil,4 end
  g.FUNCS={overlay_menu=function(args)g.OVERLAY_MENU={kind='original_result',definition=args.definition};return 29 end}
  gl.win_game=function()
    gl.set_joker_win();gl.set_deck_win()
    if asynchronous then gl.queued=function()return g.FUNCS.overlay_menu({definition=gl.create_UIBox_win()})end
    else g.OVERLAY_MENU={kind='original_result'} end
    return 23
  end
  local card={calculate_joker=function(_,context)return context.end_of_round and {saved=context.save==true} or nil,7 end}
  local game_class={update_game_over=function(self)
    if not self.STATE_COMPLETE then self.OVERLAY_MENU={original_loss=true};self.STATE_COMPLETE=true end
    return 'loss_update'
  end}
  local t=T.attach({game=function()return g end,globals=gl,card=card,game_class=game_class})
  return t,g,gl,card,game_class
end
do
  local t,g,f=fixture();check(t:arm('run1'),'arm binds real game/profile tables')
  g.GAME.won=true;check(not t:poll('run1'),'won alone cannot qualify')
  g.GAME.won=false;local a,b,c=f.end_round();check(a=='end'and b==nil and c==3,'original end-round returns are preserved')
  check(not t:poll('run1'),'final chips and won need original callbacks')
  check(f.win_game()==23,'original win return is preserved')
  local r=t:poll('run1');check(r and r.verified and r.kind=='win'and r.final_context.ante==8,'actual final context plus original progress qualifies')
  check(r.callbacks[1].after.jokers.j_yorick==1 and r.callbacks[2].after.deck_wins==1,'both original loaded Gold increments are retained')
  check(t:owned_overlay('run1')==g.OVERLAY_MENU,'only original winning overlay is owned')
  g.OVERLAY_MENU={kind='manual'};check(not t:owned_overlay('run1'),'later unrelated menu is not owned')
  g.STATE=99;r=t:poll('run1');check(r and r.kind=='loss'and r.source=='GAME_OVER','GAME_OVER overrides earlier successful-looking flags and callbacks')
  check(not t:poll('different'),'foreign run ids are refused')
end
do
  local t,g,f=fixture();t:arm('a');g.GAME.chips=999;f.end_round();f.win_game()
  check(not t:poll('a'),'unmet threshold cannot be converted into win by counters')
end
do
  local t,g,f,card=fixture();t:arm('a');g.GAME.chips=250
  local result,extra=card.calculate_joker({}, {end_of_round=true,save=true})
  check(result.saved and extra==7,'original saved callback returns are preserved')
  f.end_round();f.win_game();local r=t:poll('a')
  check(r and r.source_saved and not r.threshold_met,'actual same-round source saved result permits original terminal exception')
end
do
  local t,g,f,card=fixture();t:arm('a');g.GAME.chips=250;g.GAME.round=22
  card.calculate_joker({}, {end_of_round=true,save=true});g.GAME.round=23;f.end_round();f.win_game()
  check(not t:poll('a'),'old round saved callback cannot rescue current final')
end
do
  local t,g,f=fixture();t:arm('a');f.end_round();f.win_game()
  g.PROFILES[1]={deck_usage={},joker_usage={}}
  check(not t:poll('a'),'same-number replacement profile table invalidates evidence')
end
do
  local t,g,f=fixture();t:arm('a');f.end_round();f.win_game();g.GAME={won=true}
  check(not t:poll('a'),'same-id replacement game table invalidates evidence')
end
do
  local t,g,f=fixture();t:arm('a');g.GAME.seeded=true;f.end_round();f.win_game()
  check(not t:poll('a'),'ordinary seeded games cannot claim Gold progress')
end
do
  local t,g,f=fixture();t:arm('a');f.end_round();f.set_deck_win();f.set_joker_win()
  check(not t:poll('a'),'unexpected callback order is explicit unsupported evidence')
end
do
  local t,g,f=fixture();t:arm('a');f.end_round();f.win_game();f.set_deck_win()
  check(not t:poll('a'),'duplicate progress callback sequence does not silently qualify')
end
do
  local t,g,f=fixture();t:arm('a');g.GAME.won=true;f.win_game();g.GAME.won=false;f.end_round()
  check(not t:poll('a'),'callbacks before authentic final-round context are ignored')
end
do
  local t,g,f=fixture();t:arm('a');f.end_round();f.win_game();t:disarm()
  check(not t:poll('a'),'manual/checkpoint disarm clears all terminal authority')
end
do
  local t,g,_,_,game_class=fixture();t:arm('a');g.STATE=99
  check(game_class.update_game_over(g)=='loss_update','original GAME_OVER update returns are preserved')
  check(t:poll('a').kind=='loss'and t:owned_overlay('a')==g.OVERLAY_MENU,'only original loss-update-created overlay is owned')
  g.OVERLAY_MENU={manual=true};game_class.update_game_over(g)
  check(not t:owned_overlay('a'),'repeated original loss update cannot adopt an unchanged manual overlay')
end
do
  local t,g,f=fixture(true);t:arm('a');f.end_round();f.win_game()
  check(t:poll('a').kind=='win'and not t:poll('a').result_surface_seen,'source accounting qualifies before queued UI, with explicit unseen surface')
  g.FUNCS.overlay_menu({definition={config={id='you_win_UI'}}})
  check(not t:owned_overlay('a'),'same UI id without original definition identity cannot be adopted')
  g.OVERLAY_MENU=nil
  check(f.queued()==29,'delayed original UI callback return is preserved')
  check(t:owned_overlay('a')==g.OVERLAY_MENU and t:poll('a').result_surface_seen,'queued original definition binds only its actual result overlay')
  local definition=g.OVERLAY_MENU.definition;g.FUNCS.overlay_menu({definition=definition})
  check(not t:owned_overlay('a'),'consumed winning definition cannot authorize a second overlay')
end
do
  local t,g,f,card,game_class=fixture()
  local calls={}
  t:subscribe_source(function(kind,observed)
    calls[#calls+1]=kind
    check(observed==g,'passive source receipt binds the current game')
  end)
  check(not pcall(function()t:subscribe_source(function()end)end),'a second source listener is refused')
  card.calculate_joker({}, {end_of_round=true,save=true})
  f.end_round();f.win_game();g.STATE=99;game_class.update_game_over(g)
  check(table.concat(calls,',')=='end_round_saved,end_round_entry,win_game_returned,game_over_returned',
    'one existing hook chain reports original callback milestones without arming auto')
  check(not t:poll('unarmed'),'passive manual receipt does not arm automatic completion')
end
print('advisor_auto_terminal: '..checks..' checks passed')
