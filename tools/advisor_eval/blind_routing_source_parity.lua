local Route=dofile('Brainstorm/Advisor/blind_routing.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local defs={tag_economy={name='Economy Tag',config={type='immediate',max=40}},
  tag_handy={name='Handy Tag',config={type='immediate',dollars_per_hand=1}},
  tag_garbage={name='Garbage Tag',config={type='immediate',dollars_per_discard=1}},
  tag_skip={name='Skip Tag',config={type='immediate',skip_bonus=5}},
  tag_investment={name='Investment Tag',config={type='eval',dollars=25}},
  tag_double={name='Double Tag',config={type='tag_add'}}}
local queue={};local noop=function() end
Event=function(e) return e end
stop_use=noop;play_sound=noop;save_run=noop;delay=noop;discover_card=noop;card_eval_status_text=noop
localize=function() return 'test' end
UIBox=function() return {} end
ease_dollars=function(n) G.GAME.dollars=G.GAME.dollars+n end
Tag.generate_UI=function() return {} end
Tag.yep=function(self,_,__,fn) queue[#queue+1]={func=fn} end
local serial=0
setmetatable(Tag,{__call=function(_,key)
  serial=serial+1;local d=copy(defs[key]);d.key=key;d.ID=serial;d.ability={};setmetatable(d,{__index=Tag});return d
end})
local function flush()
  local i=1;while queue[i] do assert(i<=500,'bounded tag event queue');queue[i].func();i=i+1 end
  queue={}
end
local function parity(key,cash,skips,doubles,extra,label,selection)
  cases=cases+1;queue={};serial=0
  local chosen=selection or 'Small'
  local tag=Tag(key)
  local snap={blind_on_deck=chosen,blind_states={[chosen]='Select'},dollars=cash,skips=skips,
    hands_played_total=17,unused_discards=23,route_tags={[chosen]=copy(tag)},active_tags={},
    jokers={{key='j_throwback',name='Throwback',ability={name='Throwback',set='Joker',extra=extra or 0.25,x_mult=99}},
      {key='j_blueprint',name='Blueprint',ability={name='Blueprint',set='Joker'}}}}
  for i=1,doubles do snap.active_tags[i]=copy(Tag('tag_double')) end
  local projected,meta=assert(Route.project_skip(snap))
  G={FUNCS={skip_blind=G.FUNCS.skip_blind},C={RED={},GOLD={},MONEY={},BLUE={},CLEAR={}},UIT={ROOT=1},CONTROLLER={locks={}},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},P_TAGS=defs,HAND={},
    jokers={cards=copy(snap.jokers)},GAME={dollars=cash,skips=skips,hands_played=17,unused_discards=23,
      blind_on_deck=chosen,round_resets={blind_states={[chosen]='Select'}},tags={}}}
  for _,j in ipairs(G.jokers.cards) do setmetatable(j,{__index=Card}) end
  for i=1,doubles do G.GAME.tags[i]=Tag('tag_double') end
  G.FUNCS.skip_blind({UIBox={get_UIE_by_ID=function(_,id) assert(id=='tag_container');return {config={ref_table=tag}} end}})
  flush()
  for _,j in ipairs(G.jokers.cards) do source_refresh_throwback(j) end
  eq(G.GAME.dollars,projected.dollars,label..' source cash')
  eq(G.GAME.dollars-cash,meta.cash,label..' immediate amount')
  eq(G.GAME.skips,projected.skips,label..' skip counter')
  eq(G.GAME.blind_on_deck,projected.blind_on_deck,label..' route successor')
  eq(G.GAME.round_resets.blind_states[chosen],projected.blind_states[chosen],label..' skipped state')
  eq(G.GAME.round_resets.blind_states[projected.blind_on_deck],'Select',label..' next state selectable')
  eq(G.jokers.cards[1].ability.x_mult,projected.jokers[1].ability.x_mult,label..' Throwback refresh')
  eq(G.jokers.cards[2].ability.x_mult,nil,label..' Blueprint does not grow a physical Throwback counter')
  local deferred=0;G.GAME.last_blind={boss=true}
  for _,t in ipairs(G.GAME.tags) do local r=t:apply_to_run({type='eval'});if r then deferred=deferred+r.dollars end end
  eq(deferred,meta.deferred_cash,label..' deferred boss payout')
end
parity('tag_economy',30,0,0,nil,'Economy normal')
parity('tag_economy',70,3,0,nil,'Economy cap')
parity('tag_economy',-4,0,0,nil,'Economy debt')
parity('tag_economy',12,3,2,nil,'Economy sequential Double copies')
parity('tag_economy',30,3,2,nil,'Economy copied cap')
parity('tag_handy',10,1,0,nil,'Handy live run counter')
parity('tag_handy',10,1,3,nil,'Handy copied reward')
parity('tag_garbage',10,1,2,nil,'Garbage copied reward')
parity('tag_skip',10,0,0,nil,'first Skip counts itself')
parity('tag_skip',10,4,2,0.5,'Skip new count and custom Throwback increment','Big')
parity('tag_investment',10,1,0,nil,'Investment has no immediate cash')
parity('tag_investment',10,1,2,nil,'Investment copied deferred cash','Big')
parity('tag_double',10,1,2,nil,'Double is not copied by old Doubles')
defs.tag_skip.config.skip_bonus=9;parity('tag_skip',10,2,1,nil,'live custom Skip bonus')
defs.tag_economy.config.max=20;parity('tag_economy',12,2,2,nil,'live custom Economy cap')
defs.tag_investment.config.dollars=37;parity('tag_investment',10,2,1,nil,'live custom Investment payout')
print('Blind-routing source parity: '..cases..' cases / '..checks..' checks passed; exact skip/tag boundary only, no win probability')
