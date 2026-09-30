-- Manufactured public states only. No original source execution or save data.
local P=FIVE_PACK_PATH or 'Brainstorm/Advisor/'
local C=dofile('Brainstorm/Advisor/certificate.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua');Snap.certificate=C
local Shop=dofile(P..'shop_scoring.lua')
local Q=P
local Finish=dofile(Q..'blind_finishing.lua')
local Pack=dofile(Q..'pack_survival.lua');Finish.pack_survival=Pack
local Discard=dofile(P..'multi_discard.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua');Strategy.pack_survival=Pack
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua');Liquidity.snapshot=Snap
for _,name in ipairs({'search','draws','sampled_outcomes','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.multi_discard=Discard;Finish.strategy=Strategy
Shop.blind_finishing=Finish;Shop.strategy=Strategy;Shop.liquidity=Liquidity
Shop.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua');Shop.certificate=C
Strategy.liquidity=Liquidity
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m)check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local copy=Snap.copy
local function registry()
  local fronts={};local names={[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'}
  for _,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'}) do for rank=2,14 do
    fronts[suit..rank]={id=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit,value=names[rank] or tostring(rank)}
  end end
  return {P_CARDS=fronts,P_CENTERS={c_base={key='c_base',set='Default',name='Default Base',config={}}},
    jokers={cards={{config={center={key='j_certificate'}}}}}}
end
local function joker(key,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {id=key,key=key,name=name,ability=a,cost=4,sell_cost=2,blueprint_compat=true,face_down=false,debuff=false}
end
local function state()
  local s={phase='shop',ante=1,win_ante=8,dollars=6,bankrupt_at=0,joker_limit=5,consumeables={},consumeable_buffer=0,
    consumable_limit=2,jokers={},hands={},modifiers={},probabilities={normal=1},hand_size=8,hand_limit=1,
    round_resets={hands=4,discards=3},current_round={},playing_cards={},next_blind={key='bl_small',chips=150},
    next_blind_chips=150,shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5,certificate_pool=C.capture(registry())}
  for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
    'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}) do
    s.hands[hand]={level=1,chips=20,mult=1,played=0,l_chips=10,l_mult=1,s_chips=20,s_mult=1}
  end
  for i=1,24 do s.playing_cards[i]={id='p'..i,rank=2,nominal=2,suit=({'Clubs','Diamonds','Hearts','Spades'})[(i-1)%4+1],
    key='c_base',name='Default Base',face_down=false,debuff=false,ability={}} end
  return s
end
local function drawn(s)
  local r=copy(s);r.phase='hand';r.hand,r.deck={},{}
  r.blind={key='bl_small',chips=150,disabled=false,debuff={}}
  r.hands_left=4;r.discards_left=3;r.chips=0
  for i,c in ipairs(r.playing_cards) do if i<=8 then r.hand[#r.hand+1]=c else r.deck[#r.deck+1]=c end end
  return r
end
local old_random,old_seed=math.random,math.randomseed
math.random=function()error('Touched game RNG')end;math.randomseed=function()error('Reseeded game RNG')end


local function ordinary52()
 local s=state();s.phase='pack';s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.interest_amount=1;s.interest_cap=25
 s.hand_limit=5;s.playing_cards={}
 for si,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'})do for rank=2,14 do
  s.playing_cards[#s.playing_cards+1]={id='ordinary'..si..'_'..rank,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
   suit=suit,key='c_base',name='Default Base',face_down=false,debuff=false,ability={}}
 end end
 local levels={['High Card']={5,1},Pair={10,2},['Two Pair']={20,2},['Three of a Kind']={30,3},Straight={30,4},Flush={35,4},
  ['Full House']={40,4},['Four of a Kind']={60,7},['Straight Flush']={100,8},['Five of a Kind']={120,12},['Flush House']={140,14},['Flush Five']={160,16}}
 for name,values in pairs(levels)do s.hands[name].chips=values[1];s.hands[name].mult=values[2] end
 s.next_blind={key='bl_small',chips=600};s.next_blind_chips=600
 s.jokers={joker('j_yorick','Yorick',{x_mult=1,yorick_discards=5,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')}
 s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
 return s
end
local s=ordinary52();s.hands.Pair.chips=40;s.hands.Pair.mult=4;s.hands.Pair.level=3;s.next_blind.chips=1809;s.next_blind_chips=1809;local cert,sharp=copy(s),copy(s)
cert.jokers[#cert.jokers+1]=copy(s.pack_cards[1]);sharp.jokers[#sharp.jokers+1]=copy(s.pack_cards[2])
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000});s._shop_scoring=ctx
local ce=ctx:compare(s,cert);local se=ctx:compare(s,sharp)
check(ce and se and ce.complete_finishing and se.complete_finishing,'manufactured52-card joint families complete')
local cc={{index=1,card=s.pack_cards[1],score=100,scoring_evidence=ce},{index=2,card=s.pack_cards[2],score=50,scoring_evidence=se}}
for label,e in pairs({certificate=ce,sharp=se})do for _,p in ipairs(e.after_finishing.policies)do
 local rows={};for i,w in ipairs(p.worlds)do
  local counts={};for _,a in ipairs(w.actions)do if a.kind=='discard'then counts[#counts+1]=#a.indices end end
  rows[i]=w.score..'/'..w.hands_used..'h/'..table.concat(counts,',')..'d/'..w.endpoint_resources.jokers[1].ability.yorick_discards
 end
 print(label..':'..p.name..' selected='..e.after_finishing.selected.name..' '..table.concat(rows,' | '))
end end
local chosen,d=Pack.choose(s,cc,cc[1],{});print('choice='..tostring(chosen and chosen.index)..' reason='..tostring(d.reason)..' selected='..tostring(d.selected_policy)..' calls='..ctx.evaluations)
local function up(fn,want)
 for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==want then return v end end
end
local chooser=up(Pack.choose,'choose');local policies=up(chooser,'policies');local protect=up(chooser,'protected')
local cards=up(chooser,'cards');local qual=up(chooser,'qualified_row');local hands=up(chooser,'hand_state');local id=up(chooser,'identity')
local root={population=cards(s.playing_cards),jokers=qual(s.jokers,s.consumeables),hands=hands(s.hands),inventory=s.consumeables}
local ap,asp=policies(se.after_finishing,s.next_blind.chips);local bp,bsp=policies(ce.after_finishing,s.next_blind.chips)
local equal=up(protect,'equal')
local function diff(a,b,path,depth)
 if depth>7 then return end
 if type(a)~='table'or type(b)~='table'then if a~=b then print('DIFF '..path..' '..tostring(a)..'/'..tostring(b))end;return end
 for k,v in pairs(a)do diff(v,b[k],path..'.'..tostring(k),depth+1)end
 for k,v in pairs(b)do if a[k]==nil then print('DIFF '..path..'.'..tostring(k)..' nil/'..tostring(v))end end
end
local a=asp.worlds[1].endpoint
for k,v in pairs(root.population)do if not equal(a.raw.population[k],v)then print('POP '..k);diff(a.raw.population[k],v,k,0);break end end
for k,v in pairs(root.hands)do local av=a.hands[k];if not av or av.level<v.level or av.chips<v.chips or av.mult<v.mult then diff(av,v,k,0)end end
for k,j in pairs(root.jokers)do diff(a.jokers[k].ability,j.ability,k,0)end
for i=1,4 do local a,b=asp.worlds[i],bsp.worlds[i];local aw,bw=a.world,b.world
 print('GUARD'..i..' '..tostring(protect(a.endpoint,{raw={population=root.population,inventory=root.inventory},hands=root.hands,jokers=root.jokers},root))..' hands='..aw.hands_used..'/'..bw.hands_used..' disc='..aw.discards_used..'/'..bw.discards_used..' act='..aw.action_count..'/'..bw.action_count..' pop='..aw.population_loss..'/'..bw.population_loss..' cash='..aw.dollars_after..' root='..s.dollars..' received='..tostring(a.endpoint.jokers[id(cc[2].card.id)].key))
end
math.random,math.randomseed=old_random,old_seed
print('Five-card pack exploratory fixture: '..checks..' checks')
