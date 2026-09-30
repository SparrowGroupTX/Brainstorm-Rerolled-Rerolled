-- Manufactured public states only. No original source execution or save data.
local P='Brainstorm/Advisor/'
local C=dofile(P..'certificate.lua')
local Snap=dofile(P..'snapshot.lua');Snap.certificate=C
local Shop=dofile(P..'shop_scoring.lua')
local Finish=dofile(P..'blind_finishing.lua')
local Discard=dofile(P..'multi_discard.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
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
    fronts[suit..rank]={suit=suit,value=names[rank] or tostring(rank)}
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
do
  local g=registry();local untouched=Snap.fingerprint(g);local p=C.capture(g)
  check(p.status=='complete' and #p.fronts==52,'loaded52 fronts validated')
  for _,f in ipairs(p.fronts) do
    eq(f.value,({[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'})[f.id] or tostring(f.id),'source value maps to constructed rank')
    eq(f.nominal,f.id==14 and 11 or math.min(f.id,10),'source value maps to constructed nominal')
  end
  eq(Snap.fingerprint(g),untouched,'public front definitions are not mutated')
  for _,field in ipairs({'id','nominal'}) do
    local invalid=registry();invalid.P_CARDS.Clubs2[field]=3
    check(C.capture(invalid).status=='unsupported','conflicting constructed metadata rejects')
  end
  local invalid=registry();invalid.P_CARDS.Clubs2.value='Two'
  check(C.capture(invalid).status=='unsupported','unknown raw rank spelling rejects')
  local s=drawn(state());s.jokers={joker('j_certificate','Certificate')}
  local before=Snap.fingerprint(s);local seen={}
  for sample=1,4 do
    local out,r=C.project(s,p,sample)
    check(out and r.stochastic and not r.complete_outcome_coverage,'generation has explicit composition uncertainty')
    eq(#out.hand,9,'one extra card follows eight ordinary drawn cards')
    eq(out.hand_size,8,'extra held card is not a permanent capacity increase')
    eq(#out.deck,16,'the original remaining draw is unchanged')
    eq(#out.playing_cards,25,'one physical card added to full population')
    for i=1,16 do eq(out.deck[i].id,s.deck[i].id,'common original draw order preserved') end
    eq(out.hand[9].id,out.playing_cards[25].id,'generated held and population identities agree')
    seen[out.hand[9].seal]=true
    local again=C.project(s,p,sample);eq(Snap.fingerprint(again),Snap.fingerprint(out),'same world is deterministic')
  end
  check(seen.Purple and seen.Gold and seen.Blue and seen.Red,'all four seal classes represented once without claiming all fronts')
  eq(Snap.fingerprint(s),before,'generation leaves source state unchanged')
  g.P_CARDS.extra={id=2,suit='Clubs',value='2',nominal=2};check(C.capture(g).status=='unsupported','duplicate/unqualified front rejects')
  g=registry();g.P_CENTERS.c_base.config.bonus=1;check(C.capture(g).status=='unsupported','modified base center rejects')
  s.jokers[2]=joker('j_blueprint','Blueprint');check(not C.project(s,p,1),'copied generation not silently collapsed')
  s.jokers[2]=joker('j_certificate','Certificate');s.jokers[2].id='second';check(not C.project(s,p,1),'multiple generators reject')
  s.jokers[2]=joker('j_perkeo','Perkeo');s.consumeables={{key='c_mercury'}}
  check(not C.project(s,p,1),'nonempty Perkeo exit is outside this joint family')
end
do
  local s=drawn(state());s.hand[1].seal='Purple';s.hand_limit=5
  local ordinary=Discard.discard_candidates(s,{1},1)
  eq(ordinary[1].indices[1],1,'ordinary unmodified discard API preserves preferred action')
  local safe=Discard.discard_candidates(s,{1},3,{keep_purple=true})
  check(#safe>0,'retained-Purple family still considers supported discards')
  for _,c in ipairs(safe) do for _,i in ipairs(c.indices) do check(i~=1,'every admitted discard retains Purple')end end
  s.hand[1].ability.forced_selection=true
  eq(#Discard.discard_candidates(s,nil,3,{keep_purple=true}),0,'forced Purple makes this discard family empty, not illegally optional')
  s.hand[1].ability.forced_selection=nil
  local after,why=Score.after_discard(s,{1})
  check(not after and why:find('explicit full Tarot',1,true),'actual unknown Purple discard safeguard remains intact')
end
do
  local s=state();s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
  local cert=copy(s);cert.jokers={copy(s.pack_cards[1])}
  local sharp=copy(s);sharp.jokers={copy(s.pack_cards[2])}
  local before=Snap.fingerprint(s)
  local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
  local ce=ctx:compare(s,cert)
  check(ce,'Certificate comparison now has a full admitted composition forecast: '..tostring(ctx.unavailable_reason))
  check(ce.complete_finishing and ce.uncertain and ce.certificate_composition_family,'full policies complete while generation uncertainty remains explicit')
  check(ce.after_finishing.keep_purple and ce.before_finishing.keep_purple,'both sides use the same Purple-retention policy definition')
  eq(#ce.after_startup.samples,4,'every generator world is recorded')
  for i=1,4 do eq(ce.after_startup.samples[i].extra_held,1,'every world begins with the extra card')end
  local se=ctx:compare(s,sharp)
  check(se and se.complete_finishing and se.certificate_composition_family,'Card Sharp completes the exact same admitted family')
  check(ce.common_worlds and ce.common_worlds.kind=='shop_four_common_worlds_v1','typed common-world family receipt')
  eq(ce.common_worlds.family_key,se.common_worlds.family_key,'different legal offers bind the identical root and common worlds')
  eq(ce.common_worlds.discard_policy,'retain_all_purple','receipt names the shared constraint')
  check(ce.generation_only_uncertainty and not se.generation_only_uncertainty,'generation uncertainty is not assigned to unrelated endpoints')
  local again=Shop.new(copy(s),Score):compare(s,sharp)
  eq(again.common_worlds.family_key,se.common_worlds.family_key,'family identity is stable across identical detached contexts')
  local changed=copy(s);changed.dollars=changed.dollars+1
  local changed_e=Shop.new(changed,Score):compare(changed,changed)
  check(changed_e.common_worlds.family_key~=se.common_worlds.family_key,'different public resource roots cannot borrow the same family')
  check(se.after_finishing.selected.mean_score>4*se.after_mean,'repeat hand bonus comes from observed later plays')
  check(se.after_finishing.selected.clearing_samples==4,'all four synthetic Card Sharp trajectories clear')
  check(ce.after_finishing.selected.clearing_samples<4,'same synthetic Certificate trajectories do not all clear')
  for i,world in ipairs(se.after_finishing.selected.worlds) do
    eq(world.composition_world_id,i,'completed trajectory carries its common ordinal')
    check(world.finish_details and world.finish_details.kind=='held_finish_components_v1','raw finish components survive the scalar utility')
    check(not world.finish_details.cashout_joker_income_modeled,'Joker cashout is not invented from a successful trajectory')
  end
  check(ctx.evaluations<=50000 and not ctx.truncated,'entire comparison respects shared50k budget')
  eq(Snap.fingerprint(s),before,'common root snapshot remains unchanged')
  for _,policy in ipairs(ce.after_finishing.policies) do for _,world in ipairs(policy.worlds) do
    for _,action in ipairs(world.actions) do
      if action.kind=='play' then check(action.remaining_population==25,'generated population survives supported plays') end
    end
  end end
  local tiny=Shop.new(s,Score,nil,{max_evaluations=1})
  check(not tiny:compare(s,cert) and tiny.truncated,'incomplete budget declines whole comparison')
  cert.certificate_pool=nil
  check(not Shop.new(s,Score):compare(s,cert),'missing loaded pool fails explicitly')
  print('Certificate vs Card Sharp synthetic score calls: '..ctx.evaluations)
end
do
  -- Ordinary five-card selections exercise all381 initial subsets of each
  -- nine-card Certificate world, rather than mirroring a one-card shortcut.
  local s=state();s.hand_limit=5
  s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
  local cert=copy(s);cert.jokers={copy(s.pack_cards[1])}
  local sharp=copy(s);sharp.jokers={copy(s.pack_cards[2])}
  local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
  local ce=ctx:compare(s,cert);local se=ctx:compare(s,sharp)
  check(ce and ce.complete_finishing,'complete nine-card/five-selection Certificate family')
  check(se and se.complete_finishing,'complete five-card repeat-hand comparison')
  check(ctx.evaluations>=4*381 and ctx.evaluations<=50000 and not ctx.truncated,'complete subset charges within original allowance')
  for _,policy in ipairs(ce.after_finishing.policies) do
    eq(#policy.worlds,4,'every full-hand policy completes all common worlds')
  end
  print('Certificate full five-card paired score calls: '..ctx.evaluations)
end
do
  local s=drawn(state());s.blind.chips=20;s.next_blind.chips=20
  s.hand[1].seal='Blue';s.hand[1].enhancement='m_gold';s.hand[1].ability={name='Gold Card',h_dollars=3}
  s.consumeables={{key='c_death',id='held_death',ability={set='Tarot'}}}
  local worlds={};local opening=Score.score(s,{2});opening.indices={2}
  for i=1,4 do worlds[i]={state=copy(s),opening_play=copy(opening)} end
  local forecast=Finish.forecast(worlds,Score,function()return true end)
  check(forecast.complete and forecast.all_worlds_clear,'raw held-resource fixture clears every common world')
  for _,world in ipairs(forecast.selected.worlds) do
    local d=world.finish_details
    eq(d.held_dollars,3,'held Gold retained as dollars rather than exchanged with Planet utility')
    eq(d.blue_planets,1,'exact admitted Blue generation count')
    eq(d.planet_key,'c_pluto','Blue result retains actual hand Planet identity')
    eq(d.slots_before_blue,1,'existing Death occupies an inventory slot')
    eq(d.slots_after_blue,0,'Blue generation consumes its real ordinary slot')
    eq(d.inventory_after_play[1].key,'c_death','whole inventory retained without imaginary Planet use')
    check(d.held_supported and d.blue_supported and d.cashout_joker_income_modeled,'component support recorded explicitly')
  end
end
math.random,math.randomseed=old_random,old_seed
print('Certificate composition: '..checks..' checks passed; no source attempt or win-rate evidence')
