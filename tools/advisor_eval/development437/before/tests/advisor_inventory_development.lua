local S=dofile('Brainstorm/Advisor/strategy.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local E=dofile('Brainstorm/Advisor/economy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function equal(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,m) check(math.abs(a-b)<0.000001,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local function card(rank,id) return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(10,rank),suit='Spades',enhancement='c_base',ability={}} end
local function item(key,negative) return {key=key,name=key,cost=0,edition=negative and {negative=true} or nil,ability={set='Tarot',consumeable={}}} end
local function joker(key)
  local name=({j_perkeo='Perkeo',j_blueprint='Blueprint',j_brainstorm='Brainstorm'})[key] or key
  return {key=key,name=name,ability={name=name},blueprint_compat=true,sell_cost=10}
end
local function state()
  local s={phase='hand',ante=2,hand={},playing_cards={},deck={},jokers={},consumeables={},dollars=30,
    hand_limit=5,hand_size=7,hands_left=3,discards_left=2,hands_played=0,discards_used=0,chips=0,
    blind={chips=1000},hands={['Five of a Kind']={level=5,played=12,chips=260,mult=24,l_chips=35,l_mult=3}},
    modifiers={},probabilities={normal=1},current_round={},consumable_limit=12,joker_limit=5,
    shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5}
  for i=1,20 do s.playing_cards[#s.playing_cards+1]=card(13,'k'..i) end
  for i=1,8 do s.playing_cards[#s.playing_cards+1]=card(12,'q'..i) end
  for i=1,5 do s.hand[i]=s.playing_cards[i] end
  s.hand[6]=s.playing_cards[21];s.hand[7]=s.playing_cards[22]
  return s
end
local function clear(s) local p=Score.score(s,{1,2,3,4,5});p.indices={1,2,3,4,5};check(p.score>=s.blind.chips,'fixture has a current clear');return p end
local function develop(s,scorer) return C.develop(s,scorer or Score,clear(s),{strategy=S}) end

do
  local s=state();s.consumeables={item('c_strength')}
  equal(S.build_profile(s).rank,13,'full deck identifies established King plan')
  local result,calls=develop(s)
  check(result and result.action.kind=='use','develop despite existing clear')
  equal(table.concat(result.action.targets,','),'6,7','Strength develops both Queens into Kings')
  check(calls<=6,'bounded rescore count')
  equal(s.hand[6].rank,12,'development leaves source state unchanged')
  local after=C.apply(s,1,result.action.targets)
  equal(after.hand[6].rank,13,'exact transition adds King')
  equal(after.playing_cards[21].rank,13,'full deck reflects transformed card')
  s.ante=8;s.blind.boss=true
  check(not develop(s),'final challenge boss skips development')
end

do
  local s=state();s.jokers={joker('j_perkeo'),joker('j_perkeo')};s.consumeables={item('c_strength')}
  local use,_,diag=develop(s)
  check(not use,'retains sole useful Perkeo Strength')
  check(#diag.retention_reasons==1,'retention explanation available')
  s.consumeables[1].edition={negative=true}
  check(not develop(s),'sole Negative remains a useful copying source')
  local negative_after=C.apply(s,1,{6,7})
  equal(negative_after.consumable_limit,s.consumable_limit-1,'using Negative removes its granted consumable slot')
  s.consumeables[2]=item('c_heirophant')
  local mixed=develop(s)
  check(not mixed or mixed.action.index~=1,'unrelated inventory does not preserve preferred source')
  s.consumeables[3]=item('c_strength',true)
  s.consumeables={s.consumeables[1],s.consumeables[3]}
  local use=develop(s)
  check(use and use.action.index==1,'spend ordinary surplus while retaining Negative source')
  local after=C.apply(s,1,use.action.targets)
  local last_state=C.apply(after,1,{6})
  local _,_,last=S.preservation_cost(after,last_state,1)
  check(last,'recompute sequence retention after first use')
  s.consumeables={item('c_strength')};s.jokers[1].debuff=true;s.jokers[2].debuff=true
  check(develop(s),'disabled generators remove source retention')
  s.jokers={}
  check(develop(s),'no generator removes source retention')
end

do
  local s=state();s.jokers={joker('j_blueprint'),joker('j_perkeo'),joker('j_brainstorm')}
  equal(S.perkeo_effects(s),3,'ordered Blueprint and Brainstorm chains resolve')
  s.jokers[2].blueprint_compat=false
  equal(S.perkeo_effects(s),1,'incompatible target blocks copy chain')
  s.jokers={joker('j_blueprint'),joker('j_brainstorm')}
  equal(S.perkeo_effects(s),0,'copy cycle does not fabricate generator')
end

do
  local s=state();s.phase='shop';s.jokers={joker('j_perkeo'),joker('j_perkeo')}
  s.hands={['Four of a Kind']={level=1,played=12,chips=60,mult=7}}
  s.consumeables={item('c_strength')};s.shop_jokers={item('c_heirophant')}
  local proposal=clone(s);proposal.consumeables[2]=item('c_heirophant')
  local _,p=S.inventory_value(proposal)
  near(p.probabilities.c_strength,0.5,'one plus one copy odds')
  local delta,info=S.inventory_marginal(s,proposal)
  check(info.future<0 and delta<0,'weak addition has net harmful whole-inventory value')
  check(S.advise(s).action.kind~='buy','reject harmful dilution purchase')
  for i=2,9 do s.consumeables[i]=item('c_strength',true) end
  proposal=clone(s);proposal.consumeables[10]=item('c_heirophant')
  local _,p2=S.inventory_value(proposal)
  near(p2.probabilities.c_strength,0.9,'nine plus one count Negative copies')
  local delta2,info2=S.inventory_marginal(s,proposal)
  check(info2.future>info.future,'accumulated copies reduce marginal dilution penalty')
  check(delta2>0,'secondary card becomes worth retaining')
  equal(S.advise(s).action.kind,'buy','useful secondary purchase allowed with mature inventory')
  local sold=clone(proposal);table.remove(sold.consumeables,1)
  local _,p3=S.inventory_value(sold)
  near(p3.probabilities.c_strength,8/9,'selling preferred copy changes odds')
  local removed=clone(proposal);table.remove(removed.consumeables,10)
  local loss,_,last=S.preservation_cost(proposal,removed,10)
  equal(loss,0,'using weaker inventory improves future copy mix')
  check(not last,'last-of-type rule does not hoard a weaker dilution source')
  s=state();s.phase='shop';s.jokers={joker('j_perkeo')};s.consumeables={item('c_strength')}
  s.playing_cards={};for rank=2,14 do for i=1,4 do s.playing_cards[#s.playing_cards+1]=card(rank,rank..':'..i) end end
  s.hands={Pair={level=1,played=4,chips=10,mult=2}};s.shop_jokers={item('c_heirophant')}
  equal(S.advise(s).action.kind,'buy','same named card accepted when build values reverse')
  check(not S.build_profile(s).rank,'mixed early deck does not invent rank commitment')
end

do
  local s=state();s.hand={card(13,'survival')};s.playing_cards=s.hand
  s.jokers={joker('j_perkeo'),{key='j_scholar',name='Scholar',ability={name='Scholar',extra={chips=20,mult=4}}}}
  s.consumeables={item('c_strength')};s.hands={};s.blind.chips=100;s.hands_left=1;s.discards_left=0
  local p=Score.score(s,{1});p.indices={1}
  local result=C.suggest(s,Score,{play=p,kind='play'},nil,{strategy=S,max_evaluations=10})
  check(result and result.action.kind=='use','survival exception spends final copying source')
  check(result.play.score>=100 and not result.play.uncertain,'survival exception has deterministic modeled clear')
  s.ante=8;s.blind.boss=true
  local _,info=S.inventory_value(s)
  equal(info.events,0,'final challenge boss has no future shop exit premium')
  result=C.suggest(s,Score,{play=p,kind='play'},nil,{strategy=S,max_evaluations=10})
  check(result and result.action.kind=='use','final winning use remains allowed')
end

do
  local s=state();s.phase='shop';s.ante=8;s.teacher_profile='perkeo_yorick_win_v1'
  s.jokers={joker('j_perkeo')};s.consumeables={item('c_strength')}
  s.next_blind={ante=8,boss=false,label='Small'}
  local _,info=S.inventory_value(s)
  equal(info.events,2,'pre-Small stock retains the existing bounded two-exit forecast')
  s.next_blind={ante=8,boss=false,label='Big'}
  _,info=S.inventory_value(s)
  equal(info.events,2,'pre-Big stock retains its two-exit forecast')
  s.next_blind={ante=8,boss=true,label='Boss'}
  _,info=S.inventory_value(s)
  equal(info.events,1,'final pre-boss shop has one remaining Perkeo exit')
  s.jokers={joker('j_perkeo'),joker('j_perkeo')}
  _,info=S.inventory_value(s)
  equal(info.events,2,'two current Perkeos can make two copies on one exit')
  s.jokers={joker('j_perkeo')};s.next_blind=nil
  _,info=S.inventory_value(s)
  equal(info.events,2,'missing route evidence does not invent a final exit')
  s.next_blind={ante=8,boss=true,label='Boss'};s.teacher_profile=nil
  _,info=S.inventory_value(s)
  equal(info.events,2,'normal collection profile keeps its former stock horizon')
  s.teacher_profile='perkeo_yorick_win_v1';s.win_ante=9
  _,info=S.inventory_value(s)
  equal(info.events,2,'ante eight boss is not terminal when the win objective is later')
  s.win_ante=8;s.jokers={}
  _,info=S.inventory_value(s)
  equal(info.events,0,'no Perkeo makes no future copy events')
end

do
  local s=state();s.jokers={joker('j_perkeo')};s.used_vouchers={v_observatory=true}
  s.consumeables={item('c_planet_x'),item('c_strength')}
  s.consumeables[1].ability={set='Planet',consumeable={hand_type='Five of a Kind'}}
  local _,info=S.inventory_value(s,nil,{events=2})
  local projected=info.held+info.future-2*info.direct/2
  near(projected,24*((1.5+2.25+3.375)/3-1),'two sequential copies use reinforced nonlinear distribution')
  check(not info.approximate,'small copying pool distribution is exact within event bound')
  s.consumeables={s.consumeables[1]};s.jokers={};s.hands['Five of a Kind']={level=50,played=12,chips=1835,mult=159,l_chips=35,l_mult=3}
  check(not develop(s),'high-level matching Observatory Planet held rather than spent')
  s.used_vouchers={}
  local _,no_obs=S.inventory_value(s)
  equal(no_obs.held,0,'no Observatory means no held multiplier utility')
  s.used_vouchers={v_observatory=true};s.consumeables[1].debuff=true
  local _,debuff=S.inventory_value(s)
  equal(debuff.held,0,'debuffed Planet has no current held value')
  s.consumeables[1].debuff=false;s.consumeables[1].key='c_pluto';s.consumeables[1].ability.consumeable.hand_type='High Card'
  local _,unmatched=S.inventory_value(s)
  equal(unmatched.held,0,'unmatched Planet does not grant main-hand Observatory value')
  s=state();s.phase='shop';s.jokers={joker('j_perkeo')};s.consumeables={item('c_planet_x')}
  s.shop_vouchers={{key='v_observatory',name='Observatory',cost=10,ability={set='Voucher'}}}
  local advice=S.advise(s)
  equal(advice.action.area,'shop_vouchers','Observatory purchase recognizes existing matching Planet-copy engine')
end

do
  local s=state();s.consumeables={item('c_heirophant')};s.hand={card(14,'a'),s.playing_cards[1]}
  local targets=S.development_targets(s,s.consumeables[1]);equal(targets[1],1,'two available enhancement targets retained')
  s.consumeables[1].ability.consumeable.max_highlighted=1
  targets=S.development_targets(s,s.consumeables[1]);equal(targets[1],2,'same enhancement favors King over incidental Ace')
  s.consumeables={item('c_death')}
  targets=S.development_targets(s,s.consumeables[1]);equal(table.concat(targets,','),'1,2','Death copies King right onto off-plan Ace left')
  s.consumeables={item('c_strength')};s.hand={s.playing_cards[1]}
  check(not S.development_targets(s,s.consumeables[1]),'avoid harmful King-to-Ace development')
end

do
  local s=state();s.consumeables={item('c_strength')};local calls=0
  local fake={score=function() calls=calls+1;return {legal=true,score=0,hand='Five of a Kind'} end}
  check(not develop(s,fake),'reject development if known clear no longer survives')
  equal(calls,1,'one exact rescore no hidden hand search')
  fake.score=function() return {legal=true,score=100000,hand='Five of a Kind',uncertain=true} end
  check(not develop(s,fake),'uncertain recheck is not a guaranteed finishing line')
end

do
  local s=state();s.hand={card(14,'safe_ace')};s.playing_cards=s.hand;s.hands={};s.blind.chips=10
  s.consumeables={item('c_justice')}
  local p=Score.score(s,{1});p.indices={1}
  equal(p.score,16,'plain Ace already clears without Glass')
  check(not C.develop(s,Score,p,{strategy=S}),'Justice must not expose already-clearing Ace to Glass breakage')
  s.hand[2]=card(13,'glass_source');s.hand[2].enhancement='m_glass';s.playing_cards=s.hand
  s.consumeables={item('c_death')}
  p=Score.score(s,{1});p.indices={1}
  check(not C.develop(s,Score,p,{strategy=S}),'Death must not add Glass exposure to scoring destination')
  s.hand={card(2,'future_glass'),card(14,'retained_ace')};s.playing_cards=s.hand
  s.consumeables={item('c_justice')}
  p=Score.score(s,{2});p.indices={2}
  local result=C.develop(s,Score,p,{strategy=S})
  check(result and result.action.targets[1]==1,'Justice may develop an unplayed card without exposing the finish')
  equal(#result.play.glass_exposure,0,'unplayed new Glass remains protected')
end

do
  local s=state();s.consumeables={item('c_strength')}
  local result=Decision.run(s,{strategy=S,scoring=Score,search=Search,consumables=C},nil,
    {search={max_evaluations=2000}})
  check(result.fast_clear,'complete decision uses reliable-clear fast path')
  equal(result.action.kind,'use','complete decision publishes development use for Execute')
  equal(table.concat(result.action.targets,','),'6,7','complete decision keeps both Queen targets')
  check(result.consumable.play.score>=s.blind.chips,'published use preserves verified finishing line')
  s.jokers={joker('j_perkeo'),joker('j_perkeo')}
  result=Decision.run(s,{strategy=S,scoring=Score,search=Search,consumables=C},nil,{search={max_evaluations=2000}})
  equal(result.action.kind,'play','complete decision retains last useful copying source')
  s.jokers={};s.ante=8;s.blind.boss=true
  result=Decision.run(s,{strategy=S,scoring=Score,search=Search,consumables=C},nil,{search={max_evaluations=2000}})
  equal(result.action.kind,'play','complete decision takes final challenge win without development')
end

do
  local s=state();s.phase='shop';s.jokers={joker('j_perkeo')};s.consumeables={item('c_hermit')}
  local base={title='Leave',lines={},action={kind='leave_shop'}}
  check(not E.suggest(s,S,C,base),'economy preserves final cash copying source at payout cap')
  check(#base.lines>0,'economy explains source retention')
  s.consumeables[2]=item('c_hermit',true)
  check(E.suggest(s,S,C,{title='Leave',lines={},action={kind='leave_shop'}}),'economy can spend surplus cash source')
end

print('advisor_inventory_development: '..checks..' checks passed')
