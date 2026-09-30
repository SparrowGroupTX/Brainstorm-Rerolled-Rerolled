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
 local levels={['High Card']={5,1,10,1},Pair={10,2,15,1},['Two Pair']={20,2,20,1},['Three of a Kind']={30,3,20,2},Straight={30,4,30,3},Flush={35,4,15,2},
  ['Full House']={40,4,25,2},['Four of a Kind']={60,7,30,3},['Straight Flush']={100,8,40,4},['Five of a Kind']={120,12,35,3},['Flush House']={140,14,40,4},['Flush Five']={160,16,50,3}}
 for name,values in pairs(levels)do local h=s.hands[name]
  h.chips=values[1];h.mult=values[2];h.s_chips=values[1];h.s_mult=values[2];h.l_chips=values[3];h.l_mult=values[4]
 end
 for i,c in ipairs(s.playing_cards)do if i%3==1 then c.ability.discarded=true elseif i%3==2 then c.ability.discarded=false end end
 s.next_blind={key='bl_small',chips=600};s.next_blind_chips=600
 s.jokers={joker('j_yorick','Yorick',{x_mult=1,yorick_discards=5,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')}
 s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
 return s
end

-- A constructed scoring boundary: each original front appears once, Pair has
-- received two level-ups, and Yorick needs five cards for X1 -> X2. The target
-- is chosen to exercise a full four-world policy comparison, not a run forecast.
local function compare(s,cap)
 local cert,sharp=copy(s),copy(s)
 cert.jokers[#cert.jokers+1]=copy(s.pack_cards[1]);sharp.jokers[#sharp.jokers+1]=copy(s.pack_cards[2])
 local ctx=Shop.new(s,Score,nil,{max_evaluations=cap or 50000});s._shop_scoring=ctx
 local ce=ctx:compare(s,cert);local se=ctx:compare(s,sharp)
 return ctx,ce,se,{{index=1,card=s.pack_cards[1],score=100,scoring_evidence=ce},
  {index=2,card=s.pack_cards[2],score=50,scoring_evidence=se}}
end
local function policy(f,name)
 for _,p in ipairs(f.policies)do if p.name==name then return p end end
end
local s=ordinary52();s.hands.Pair.chips=40;s.hands.Pair.mult=4;s.hands.Pair.level=3
s.next_blind.chips=1809;s.next_blind_chips=1809
local original=Snap.fingerprint(s)
local ctx,ce,se,cc=compare(s)
check(ce and se and ce.complete_finishing and se.complete_finishing,'manufactured52-card joint families complete')
local after_public={};for k,v in pairs(s)do if k~='_shop_scoring'then after_public[k]=v end end
check(Snap.fingerprint(after_public)==original,'all original public fields remain unchanged apart from explicitly attached context')
local third='one_five_card_targeted_discard'
local declaration='fixed_play_only_or_one_targeted_or_one_five_card_observed_discard_v1'
for _,e in ipairs({ce,se})do
 eq(e.common_worlds.continuation_family,declaration,'root binds the same expanded family')
 for _,field in ipairs({'before_finishing','after_finishing'})do local f=e[field]
  eq(f.policy_family,declaration,'every endpoint explicitly declares three policies');eq(#f.policies,3,'exact three-policy family')
  for _,p in ipairs(f.policies)do eq(#p.worlds,4,'every admitted policy completes every common world')
   for i,w in ipairs(p.worlds)do
    eq(w.composition_world_id,i,'stable common ordinal')
    check(w.discards_used<=1,'at most one discard in each entire trajectory')
    for _,action in ipairs(w.actions)do if action.kind=='discard'and p.name==third then eq(#action.indices,5,'third policy executes exactly five')end end
   end
  end
 end
end
check(policy(se.after_finishing,third).clearing_samples==4,'five-card threshold policy clears all four constructed worlds')
check(policy(se.after_finishing,'play_only').clearing_samples<4 and policy(se.after_finishing,'one_targeted_discard').clearing_samples<4,
 'both earlier Card Sharp policies leave at least one constructed world uncleared')
check(ce.after_finishing.selected.clearing_samples==0,'Certificate does not clear this constructed threshold')
for _,w in ipairs(policy(se.after_finishing,third).worlds)do
 eq(w.endpoint_resources.jokers[1].ability.x_mult,2,'one exact Yorick threshold increment')
 eq(w.endpoint_resources.jokers[1].ability.yorick_discards,23,'five discarded cards finish and reset the countdown')
 eq(w.dollars_after,s.dollars,'no unpriced discard cash loss');eq(w.population_loss,0,'no original card destroyed')
 eq(#w.endpoint_resources.jokers,3,'original row plus one actually received offer')
end
-- Conservation is separate from the scorer's own per-card history marker.
local changed_false,changed_nil,preserved_true=0,0,0
for _,w in ipairs(policy(se.after_finishing,third).worlds)do
 local discarded={};for _,a in ipairs(w.actions)do if a.kind=='discard'then
  eq(#a.card_ids,#a.indices,'every physical discard identity is recorded')
  for _,id in ipairs(a.card_ids)do discarded['string:'..id]=true end
 end end
 for _,card in ipairs(s.playing_cards)do local id='string:'..card.id;local expected=card.ability.discarded
  if discarded[id]then
   changed_false=changed_false+(expected==false and 1 or 0);changed_nil=changed_nil+(expected==nil and 1 or 0);expected=true
  elseif expected==true then preserved_true=preserved_true+1 end
  eq(w.endpoint_resources.play_history[id].discarded,expected,'history matches precisely the actual recorded discard')
  check(w.endpoint_resources.population[id].ability.discarded==nil,'volatile marker is retained in explicit history, not asset identity')
 end
end
check(changed_false>0 and changed_nil>0 and preserved_true>0,'fixture covers false/nil to true and unchanged true histories')
local selected,diagnostic=Pack.choose(s,cc,cc[1],{})
check(selected==cc[2] and diagnostic.selected_policy==third,'complete exact-five family qualifies all unchanged asset/reward guards')
print('Five-card complete52-family: '..ctx.evaluations..' scores; selected='..tostring(selected and selected.index)..'; '..diagnostic.reason)
check(ctx.evaluations<=50000 and not ctx.truncated,'all three policies and both offers fit shared original50k')
local calls=ctx.evaluations
local function fresh()
 local ss={};for k,v in pairs(s)do if k~='_shop_scoring'then ss[k]=copy(v)end end
 ss._shop_scoring={truncated=false}
 local candidates=copy(cc)
 for i,c in ipairs(candidates)do
  c.card=ss.pack_cards[i]
  for _,field in ipairs({'before_finishing','after_finishing'})do local f=c.scoring_evidence[field]
   f.selected=policy(f,f.selected.name)
  end
 end
 return ss,candidates
end
local function reject(label,mutate)
 local ss,candidates=fresh();mutate(ss,candidates)
 local chosen,reason=Pack.choose(ss,candidates,candidates[1],{})
 check(not chosen and type(reason.reason)=='string',label..' fails explicitly without forging a choice')
end
reject('missing third policy',function(ss,c) c[2].scoring_evidence.after_finishing.policies[3]=nil end)
reject('extra fourth policy',function(ss,c) c[2].scoring_evidence.after_finishing.policies[4]=copy(c[2].scoring_evidence.after_finishing.policies[3])end)
reject('undeclared third policy',function(ss,c) c[2].scoring_evidence.after_finishing.policy_family=nil end)
reject('unknown declaration',function(ss,c) c[2].scoring_evidence.after_finishing.policy_family='unknown' end)
reject('false declaration',function(ss,c) c[2].scoring_evidence.after_finishing.policy_family=false end)
reject('wrong common family',function(ss,c) c[2].scoring_evidence.common_worlds.continuation_family='fixed_play_only_or_one_targeted_observed_discard_v1' end)
reject('duplicate policy name',function(ss,c) c[2].scoring_evidence.after_finishing.policies[3].name='one_targeted_discard' end)
reject('four-card action falsely declared five',function(ss,c) local p=c[2].scoring_evidence.after_finishing.policies[3];table.remove(p.worlds[1].actions[1].indices)end)
reject('duplicate physical discard index',function(ss,c) local p=c[2].scoring_evidence.after_finishing.policies[3];p.worlds[1].actions[1].indices[5]=p.worlds[1].actions[1].indices[1]end)
reject('hybrid discard metadata',function(ss,c) local p=c[2].scoring_evidence.after_finishing.policies[3];p.worlds[1].actions[1].indices.extra=true end)
reject('second discard in fixed-one policy',function(ss,c)
 local w=c[2].scoring_evidence.after_finishing.policies[3].worlds[1]
 w.actions[#w.actions+1]=copy(w.actions[1]);w.action_count=#w.actions;w.discards_used=2
end)
reject('missing discard identity list',function(ss,c)c[2].scoring_evidence.after_finishing.policies[3].worlds[1].actions[1].card_ids=nil end)
reject('duplicate discard physical identity',function(ss,c)local ids=c[2].scoring_evidence.after_finishing.policies[3].worlds[1].actions[1].card_ids;ids[5]=ids[1]end)
reject('unknown discard physical identity',function(ss,c)c[2].scoring_evidence.after_finishing.policies[3].worlds[1].actions[1].card_ids[1]='invented'end)
reject('missing expected monotonic discard mark',function(ss,c)
 local w=c[2].scoring_evidence.after_finishing.policies[3].worlds[1]
 w.endpoint_resources.play_history['string:'..w.actions[1].card_ids[1]].discarded=false
end)
reject('arbitrary mutation is still a physical asset change',function(ss,c)
 local w=c[2].scoring_evidence.after_finishing.policies[3].worlds[1]
 w.endpoint_resources.population['string:ordinary1_2'].ability.arbitrary=true
end)
reject('unrecorded new discard mark',function(ss,c)
 local w=c[2].scoring_evidence.after_finishing.policies[3].worlds[1];local discarded={}
 for _,id in ipairs(w.actions[1].card_ids)do discarded['string:'..id]=true end
 for _,card in ipairs(ss.playing_cards)do local id='string:'..card.id
  if not discarded[id]and card.ability.discarded~=true then w.endpoint_resources.play_history[id].discarded=true;return end
 end
 error('Manufactured fixture needs one undiscared nontrue marker')
end)
reject('true history cannot be restored to false',function(ss,c)
 local w=c[2].scoring_evidence.after_finishing.policies[3].worlds[1]
 for _,card in ipairs(ss.playing_cards)do if card.ability.discarded==true then w.endpoint_resources.play_history['string:'..card.id].discarded=false;return end end
end)
reject('missing history card entry',function(ss,c)c[2].scoring_evidence.after_finishing.policies[3].worlds[1].endpoint_resources.play_history['string:ordinary1_2']=nil end)
reject('unowned extra history identity',function(ss,c)c[2].scoring_evidence.after_finishing.policies[3].worlds[1].endpoint_resources.play_history.unknown={}end)
reject('nonboolean root history rejects',function(ss,c)ss.playing_cards[1].ability.discarded='true'end)
reject('more discard actions cannot buy survival',function(ss,c)
 local f=c[1].scoring_evidence.after_finishing;f.selected=f.policies[1]
end)
reject('extra unsupported callback scope remains guarded',function(ss,c)ss.jokers[2].key='j_cloud_9'end)
reject('no protected population removal',function(ss,c)c[2].scoring_evidence.after_finishing.policies[3].worlds[1].endpoint_resources.population['string:ordinary1_2']=nil end)
eq(ctx.evaluations,calls,'selection and all evidence checks perform zero scoring')

-- Pure candidate legality is chosen from the observed hand alone, retaining
-- forced selections and every Purple card under the Certificate family.
do
 local observed=drawn(ordinary52());observed.hand[1].seal='Purple';observed.hand[2].ability.forced_selection=true
 local kept=Discard.discard_candidates(observed,nil,3,{exact_count=5,keep_purple=true})
 check(#kept>0,'a legal exact-five observed candidate exists')
 for _,candidate in ipairs(kept)do
  eq(#candidate.indices,5,'exact requested count');local forced=false
  for _,index in ipairs(candidate.indices)do check(index~=1,'Purple is retained');forced=forced or index==2 end
  check(forced,'every candidate includes the forced card')
 end
 observed.hand[1].ability.forced_selection=true
 eq(#Discard.discard_candidates(observed,nil,3,{exact_count=5,keep_purple=true}),0,'forced Purple gives no admitted discard')
 observed.hand[1].ability.forced_selection=nil;observed.hand[2].ability.forced_selection=nil
 for i=1,4 do observed.hand[i].seal='Purple'end
 eq(#Discard.discard_candidates(observed,nil,3,{exact_count=5,keep_purple=true}),0,'fewer than five non-Purple cards gives no discard')
 for _,bad in ipairs({0,6,4.5,'5',true,math.huge})do eq(#Discard.discard_candidates(observed,nil,3,{exact_count=bad}),0,'invalid exact-count declaration declines')end
 eq(#Discard.discard_candidates(observed,nil,3,{exact_count=0/0}),0,'NaN count declines')
 observed.hand_limit=4
 eq(#Discard.discard_candidates(observed,nil,3,{exact_count=5}),0,'cannot exceed current selection limit')
end

-- Flag parsing must not spend even one score, draw, or transition.
for _,bad in ipairs({0,1,'true',{},math.huge})do
 local f=Finish.forecast({},Score,function()error('Invalid flag spent a score')end,{five_card_discard=bad})
 check(not f.complete and f.reason:find('explicitly declared',1,true),'nonboolean option rejects before evaluation')
end

-- Activation is one explicit root contract, never an offer-dependent switch.
for _,case in ipairs({
 {'ordinary shop',function(r)r.phase='shop'end},
 {'more than one pack choice',function(r)r.pack_choices=2 end},
 {'string pack count',function(r)r.pack_choices='1'end},
 {'other pack',function(r)r.pack_type='SPECTRAL_PACK'end},
 {'no owned Yorick',function(r)r.jokers={r.jokers[2]}end},
 {'debuffed Yorick',function(r)r.jokers[1].debuff=true end},
 {'expired Yorick',function(r)r.jokers[1].ability.perishable=true;r.jokers[1].ability.perish_tally=0 end},
})do
 local root=ordinary52();root.hand_limit=1;case[2](root)
 local context=Shop.new(root,Score,nil,{max_evaluations=50000});local evidence=context:compare(root,root)
 check(evidence and evidence.complete_finishing,case[1]..' retains ordinary complete evidence')
 eq(evidence.common_worlds.continuation_family,'fixed_play_only_or_one_targeted_observed_discard_v1',case[1]..' does not activate expanded family')
 eq(#evidence.before_finishing.policies,2,case[1]..' retains two-policy scope')
end

-- False/absent declarations remain identical; explicit true still falls back
-- to play when a five-card discard is unavailable or the current play clears.
do
 local observed=drawn(ordinary52());observed.hand_limit=1;observed.blind.chips=1
 local opening=Score.score(observed,{1});opening.indices={1}
 local worlds={};for i=1,4 do worlds[i]={state=copy(observed),opening_play=copy(opening)}end
 local counts=0;local function charge()counts=counts+1;return true end
 local absent=Finish.forecast(worlds,Score,charge)
 local disabled=Finish.forecast(worlds,Score,charge,{five_card_discard=false})
 check(absent.complete and disabled.complete and Snap.fingerprint(absent)==Snap.fingerprint(disabled),'false preserves complete ordinary forecast bytes')
 local enabled=Finish.forecast(worlds,Score,charge,{five_card_discard=true})
 check(enabled.complete and #enabled.policies==3,'explicit option admits a third whole fixed policy')
 for _,world in ipairs(enabled.policies[3].worlds)do eq(world.discards_used,0,'no forced discard before an available clear')end
 local spent=0
 local incomplete=Finish.forecast(worlds,Score,function()if spent>=8 then return false end;spent=spent+1;return true end,{five_card_discard=true})
 check(not incomplete.complete and not incomplete.selected and #incomplete.policies[1].worlds==4 and #incomplete.policies[2].worlds==4,
  'failure entering the third policy invalidates the whole family despite completed earlier policies')
 eq(spent,8,'incomplete third policy preserves the existing charged allowance')
end

-- A tiny allowance cannot publish a partial preferred family.
do
 local tiny=ordinary52();local context,e1,e2,candidates=compare(tiny,1)
 check(context.truncated and context.evaluations<=1,'complete family honors insufficient shared allowance')
 eq(Shop.new(tiny,Score,nil,{max_evaluations=50001}).max_evaluations,50000,'requesting more cannot raise the shared shop cap')
 local chosen=Pack.choose(tiny,candidates,candidates[1],{})
 check(not chosen,'partial work cannot override the existing choice')
end
math.random,math.randomseed=old_random,old_seed
print('Five-card pack: '..checks..' checks; manufactured states only')
