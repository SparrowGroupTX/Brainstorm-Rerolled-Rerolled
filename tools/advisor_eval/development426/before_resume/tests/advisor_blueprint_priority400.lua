-- Manufactured public shops, independent of recorded run parameters.
local P='Brainstorm/Advisor/'
local S=dofile(P..'strategy.lua')
local D=dofile(P..'decision.lua')
local Shop=dofile(P..'shop_scoring.lua')
local Score=dofile(P..'scoring.lua')
local Finish=dofile(P..'blind_finishing.lua')
local Snapshot=dofile(P..'snapshot.lua')
local Sequence=dofile(P..'shop_sequences.lua')
local L=dofile(P..'liquidity.lua');L.snapshot=Snapshot;S.liquidity=L
for _,k in ipairs({'search','draws','sampled_outcomes','finish_rewards','multi_discard'}) do Finish[k]=dofile(P..k..'.lua') end
Finish.strategy=S;Shop.blind_finishing=Finish;Shop.strategy=S;Shop.liquidity=L
Shop.paired_deck=dofile(P..'paired_deck.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function copy(v)return Snapshot.copy(v)end
local function j(key,name,a,cost)
  a=a or {};a.name=name;a.set='Joker'
  return {id='fixture:'..key,key=key,name=name,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=3}
end
local function state()
  local s={phase='shop',ante=4,win_ante=8,teacher_profile='perkeo_yorick_win_v1',dollars=12,
    bankroll_at=0,joker_limit=3,consumable_limit=2,consumeables={},hand={},deck={},playing_cards={},
    jokers={j('j_yorick','Yorick',{x_mult=4,yorick_discards=17,extra={discards=23,xmult=1}}),
      j('j_perkeo','Perkeo'),j('j_trading','Trading Card')},
    shop_jokers={j('j_blueprint','Blueprint',{eternal=true},11)},shop_vouchers={},
    shop_booster={{key='p_buffoon_mega_1',cost=8,ability={set='Booster'}}},
    hands={Pair={level=4,played=8,chips=55,mult=5}},hand_size=5,hand_limit=5,
    round_resets={hands=3,discards=3},current_round={},modifiers={},probabilities={normal=1},
    blind={key='bl_small',name='Small Blind'},next_blind={key='bl_big',name='Big Blind',chips=1200},
    bankrupt_at=0,interest_cap=25,interest_amount=1,reroll_cost=5}
  for i=1,12 do s.playing_cards[i]={id='card:'..i,rank=7,suit='Clubs',nominal=7,enhancement='c_base',ability={}} end
  return s
end
local function worlds(progress,clear)
  local t={};for i=1,4 do t[i]={clear=clear,score=progress*1000,progress=progress} end
  return {complete=true,supported=true,known_mechanics=true,samples=4,selected={worlds=t,clearing_samples=clear and 4 or 0}}
end
local function evidence()
  return {samples=4,ratio=2,adjustment=-80,uncertain=false,before_target=1000,after_target=1000,
    complete_finishing=true,before_finishing=worlds(1,true),after_finishing=worlds(1,true),
    common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='synthetic400'},
    reason='Complete manufactured paired endpoint.',after_readiness={supported=true,status='sampled_safe'}}
end
local function endpoint(s)
  local after=assert(Sequence.transition(s,{kind='sell',area='jokers',index=3},{strategy=S}))
  return assert(Sequence.transition(after,{kind='buy',area='shop_jokers',index=1},{strategy=S}))
end
local s=state();local after=endpoint(s)
check(S.supported_copy_priority(s,s.jokers[3],s.shop_jokers[1],after,evidence()),'low actual cash Eternal Blueprint qualifies with complete supported finishes')
local function reject(label,change)
  local x=state();local a=endpoint(x);local e=evidence();change(x,a,e)
  check(not S.supported_copy_priority(x,x.jokers[3],x.shop_jokers[1],a,e),label)
end
reject('unknown mechanics rejected',function(x,a,e)e.after_finishing.known_mechanics=false end)
reject('one losing world rejected',function(x,a,e)e.after_finishing.selected.worlds[2].clear=false end)
reject('partial worlds rejected',function(x,a,e)e.common_worlds.world_ids[4]=nil end)
reject('uncertain score rejected',function(x,a,e)e.uncertain=true end)
reject('uncertain family rejected',function(x,a,e)e.complete_finishing=false end)
reject('unfunded real reserve rejected',function(x,a,e)a.modifiers.discard_cost=2 end)
reject('last engine sale rejected',function(x,a)
  x.jokers[3].key='j_perkeo';x.jokers[2].key='j_joker';a.jokers[2].key='j_joker'
end)
reject('Eternal victim rejected',function(x)x.jokers[3].ability.eternal=true end)
reject('no useful copy target rejected',function(x)x.jokers[1].ability.x_mult=1 end)
reject('expired offer rejected',function(x)x.shop_jokers[1].ability.perishable=true;x.shop_jokers[1].ability.perish_tally=0 end)
local rental=state();rental.shop_jokers[1].ability.rental=true;rental.shop_jokers[1].cost=1
check(S.supported_copy_priority(rental,rental.jokers[3],rental.shop_jokers[1],endpoint(rental),evidence()),'affordable Rental/Eternal copy is admitted with real upkeep')
local mock={evaluations=0,truncated=false,max_evaluations=50000}
function mock:compare()self.evaluations=self.evaluations+4;return evidence()end
local choice,receipt=S.copy_acquisition(s,mock)
check(choice and choice.action.kind=='sell' and choice.action.index==3,'negative additive rating does not veto supported acquisition')
check(receipt.complete and choice.copy_acquisition_review and choice.action.followup.index==1,'bounded family publishes sale then fresh buy')
local sold=assert(Sequence.transition(s,choice.action,{strategy=S}))
choice=S.copy_acquisition(sold,mock)
check(choice and choice.action.kind=='buy' and choice.action.index==1,'fresh observation buys visible copy after sale')
local funded=state();funded.joker_limit=4;funded.dollars=9
choice=S.copy_acquisition(funded,mock)
check(choice and choice.action.kind=='sell' and choice.action.index==3,'vacant slot still permits one funded sale')
local caps={evaluations=0,truncated=false,max_evaluations=0}
function caps:compare()self.truncated=true;return nil end
check(not S.copy_acquisition(s,caps),'incomplete focused family cannot publish a prefix')
local frozen=Snapshot.fingerprint(s)
local modules={strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Sequence}
local result=D.run(s,modules,nil,{prepared_scoring=false})
check(result.action.kind=='sell' and result.action.index==3,'real scorer and finisher select copy before wider shop arbitration')
check(result.copy_acquisition_diagnostics and result.copy_acquisition_diagnostics.complete and
  result.copy_acquisition_diagnostics.reason=='supported_copy_priority' and result.evaluations<=50000,
  'focused production comparison itself acquires copy within existing shared cap')
for _,key in ipairs({'j_blueprint','j_brainstorm'}) do for _,label in ipairs({'a','z'}) do
  local permuted=state();permuted.shop_jokers[1].id=label..':copy';permuted.shop_jokers[1].key=key
  permuted.shop_jokers[1].ability.name=key=='j_blueprint' and 'Blueprint' or 'Brainstorm'
  permuted.jokers[2].id=label=='a' and 'z:perkeo' or 'a:perkeo'
  permuted.jokers[1],permuted.jokers[2]=permuted.jokers[2],permuted.jokers[1]
  local r=D.run(permuted,modules,nil,{prepared_scoring=false})
  check(r.copy_acquisition_diagnostics.reason=='supported_copy_priority' and r.action.kind=='sell',
    'copy-target shortlist survives '..key..' physical ID/order permutation '..label)
end end
check(Snapshot.fingerprint(s)==frozen,'production comparison does not change the observed state')
local small=D.run(s,modules,nil,{prepared_scoring=false,shop_scoring={max_evaluations=1}})
check(small.evaluations<=1 and small.action.kind~='sell','lower caller cap and failed complete-family proof preserve fallback')
local pack=state();pack.dollars=40;pack.shop_jokers={}
choice=S.advise(pack)
check(choice.action.kind=='open','funded full-row Joker-pack exploration permits later sale after reveal')
check(pack.dollars-pack.shop_booster[1].cost>=15,'exploration preserves practical future Blueprint cash')
local poor=copy(pack);poor.dollars=17
check(S.advise(poor).action.kind~='open','expensive unknown pack cannot consume protected acquisition cash')
poor.joker_limit=5;poor.shop_booster[1].cost=4
check(S.advise(poor).action.kind~='open','an empty slot does not waive the Blueprint cash reserve')
local blocked=copy(pack);blocked.jokers[3].ability.eternal=true
check(S.advise(blocked).action.kind~='open','permanent full row cannot justify ordinary Joker-pack exploration')
local custom=copy(pack);custom.shop_booster[1].key='p_buffoon_custom'
check(S.advise(custom).action.kind~='open','unknown pack is not treated as a supported Joker search')
local absent=copy(pack);absent.jokers[1].ability.x_mult=1
check(S.advise(absent).action.kind~='open','no useful copy target control')
local revealed=state();revealed.phase='pack';revealed.pack_type='BUFFOON_PACK';revealed.pack_choices=1
revealed.pack_cards={copy(revealed.shop_jokers[1])};revealed.pack_cards[1].cost=0;revealed.shop_jokers={}
choice=S.advise(revealed,{shop_scoring=mock})
check(choice.action.kind=='sell' and choice.action.index==3,'revealed pack Blueprint uses same supported replacement priority')
local open=copy(revealed);table.remove(open.jokers,3)
choice=S.advise(open,{shop_scoring=mock})
check(choice.action.kind=='choose' and choice.action.index==1,'fresh pack observation takes revealed Blueprint')
print('advisor_blueprint_priority400: '..checks..' manufactured checks passed; production work '..result.evaluations)
