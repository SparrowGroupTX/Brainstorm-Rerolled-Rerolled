-- Manufactured public states only: no saved/captured game, source or RNG use.
local prefix='Brainstorm/Advisor/'
local A=dofile('Brainstorm/Advisor/gold_acquisition.lua')
local Snapshot=dofile(prefix..'snapshot.lua')
local Goal=dofile(prefix..'gold_goal.lua')
local Shop=dofile(prefix..'shop_scoring.lua')
local Score=dofile(prefix..'scoring.lua')
local Strategy=dofile(prefix..'strategy.lua')
local Sequences=dofile(prefix..'shop_sequences.lua')
local Liquidity=dofile(prefix..'liquidity.lua')
local Perkeo=dofile(prefix..'gold_perkeo.lua')
Strategy.liquidity=Liquidity;Liquidity.snapshot=Snapshot
local mods={gold_goal=Goal,shop_scoring=Shop,scoring=Score,strategy=Strategy,shop_sequences=Sequences,liquidity=Liquidity,gold_perkeo=Perkeo}
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local function module_copy(source) local out={};for key,value in pairs(source) do out[key]=value end;return out end
local function joker(key,id,name,ability)
  ability=ability or {};ability.set='Joker';ability.name=name
  return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,face_down=false,pinned=false,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=1,consumable_limit=2,
    consumeable_buffer=0,consumeables={},jokers={joker('j_joker','owned','Joker',{mult=4})},
    shop_jokers={joker('j_crazy','offer','Crazy Joker',{t_mult=12,type='Straight'})},shop_booster={},shop_vouchers={},
    next_blind={key='bl_big',name='Big Blind',boss=false,chips=100,ante=8},hand_size=4,hand_limit=5,
    hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    hands={},playing_cards={},hand={},deck={},ordering_safe=true,jokers_shuffling=false,
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',shop_forecast={inflation=0,discount_percent=0},
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},by_key={j_joker={status='complete'},j_crazy={status='missing'}}}}
  for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind',
      'Straight Flush','Five of a Kind','Flush House','Flush Five'}) do s.hands[name]={chips=100,mult=10,level=10,played=1} end
  for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}} end
  return s
end
local calls=0;local actual=Score.lower_bound
local counted={lower_bound=function(...)
  calls=calls+1;return actual(...)
end,score=function() error('Acquisition may not use a random-score mean') end}
mods.scoring=counted
local function advise(s,options,modules)
  local prior=calls;local advice,work,d=A.suggest(s,modules or mods,nil,options)
  eq(work,calls-prior,'every underlying floor call is charged exactly once')
  check(work<=math.min(50000,options and options.max_evaluations or 50000),'the declared common shop allowance is respected')
  return advice,work,d
end
math.random=function() error('No RNG belongs in the manufactured family') end;pseudorandom=math.random

do
  local s=state();local original=Snapshot.fingerprint(s)
  local a,work,d=advise(s)
  check(a and d.complete and d.projection_complete,'a full completed row acquires an affordable visible missing target before Big')
  eq(a.action.kind,'sell','the full row sells first')
  eq(a.action.followup.kind,'buy','the exact visible followup is retained')
  eq(a.action.followup.index,1,'followup names the physical offer index')
  eq(d.before_missing,0,'no original missing keys are fabricated');eq(d.after_missing,1,'the paid endpoint adds one distinct missing key')
  check(d.selected.minimum_score_delta<0,'excess score may be traded for the objective')
  eq(d.selected.hold_certificate.scope,'unchanged_owned_inventory_hold','ordinary held inventory has no speculative exit mutation')
  eq(#d.endpoints,2,'hold and the sole legal paid endpoint both complete')
  for _,r in ipairs(d.endpoints) do
    eq(r.evidence.after_readiness.ordering.action_count,0,'no unexecuted Joker rearrangement is assumed')
    eq(r.evidence.after_readiness.ordering.layouts,1,'the declared family has exactly the current physical row')
    eq(r.evidence.common_worlds.family_key,d.endpoints[1].evidence.common_worlds.family_key,'all endpoints share the exact public family')
  end
  local sold=assert(Sequences.transition(s,a.action,mods))
  a,work,d=advise(sold)
  check(a and d.complete and a.action.kind=='buy','fresh replan after the sale still buys the missing target')
  local bought=assert(Sequences.transition(sold,a.action,mods))
  eq(bought.jokers[1].key,'j_crazy','actual paid transitions retain the visible target')
  eq(bought.dollars,167,'sale and buy prices are charged once')
  eq(Snapshot.fingerprint(s),original,'the complete comparison and manufactured delivery leave input immutable')
  s=state();s.dollars=3;s.jokers[1].sell_cost=5;s.shop_jokers[1].cost=7
  a,work,d=advise(s);check(a and a.action.kind=='sell','an exact original sale may fund the intended purchase')
  sold=assert(Sequences.transition(s,a.action,mods));a,work,d=advise(sold)
  check(a and a.action.kind=='buy','a newly funded fresh state delivers the actual purchase')
end

do
  for _,change in ipairs({function(s) s.ante=7 end,function(s) s.next_blind.key='bl_final_heart';s.next_blind.boss=true end,
      function(s) s.completionist_goal.eligibility.eligible=false end,function(s) s.completionist_goal.metadata_status='unknown' end,
      function(s) s.completionist_goal.by_key.j_joker.status='unknown' end,function(s) s.jokers[1].face_down=true end,
      function(s) s.consumeable_buffer=1 end,function(s) s.ordering_safe=false end}) do
    local s=state();change(s);local a,work,d=advise(s)
    check(not a and not d.complete and work==0,'out-of-scope or uncertain input declines before scoring')
  end
  local s=state();s.completionist_goal.by_key.j_crazy.status='complete'
  local a,work,d=advise(s);check(not a and d.complete and work==0,'all-complete visible offers have a complete zero-work decline')
  s=state();s.jokers[1]=joker('j_crazy','owned','Crazy Joker',{t_mult=12,type='Straight'})
  a,work,d=advise(s);check(not a and d.complete and work==0,'duplicate missing keys are not additional sticker opportunities')
  s=state();s.completionist_goal.by_key.j_joker.status='missing'
  a,work,d=advise(s);check(not a and d.complete and work==0,'a missing held Joker is not sold merely to exchange one missing key for another')
  s=state();s.jokers[1].ability.eternal=true
  a,work,d=advise(s);check(not a and d.complete and work==0,'Eternal completed Jokers are not sold')
  s=state();s.jokers[1].pinned=true
  a,work,d=advise(s);check(not a and d.complete and work==0,'pinned completed Jokers are not sold')
  s=state();s.dollars=0
  a,work,d=advise(s);check(not a and d.complete and work==0,'unfunded endpoints cannot spend future income')
  s=state();s.joker_limit=2;s.jokers[1].ability.eternal=true;s.dollars=7;s.shop_jokers[1].ability.rental=true
  a,work,d=advise(s);check(not a and d.complete,'a purchase cannot spend the retained rental reserve')
  s.dollars=8;a,work,d=advise(s);check(a and d.complete,'an exactly funded retained rental remains admissible')
  s=state();s.joker_limit=2;s.jokers[1].ability.eternal=true
  s.jokers[2]=joker('j_golden','negative','Golden Joker',{extra=4});s.jokers[2].edition={negative=true,type='negative'}
  s.completionist_goal.by_key.j_golden={status='complete'}
  a,work,d=advise(s);check(not a and d.complete and work==0,'selling a Negative slot provider cannot invent an ordinary free slot')
end

do
  local s=state();local before=Snapshot.fingerprint(s)
  local a,work,d=advise(s,{max_evaluations=1})
  check(not a and not d.complete and d.truncated,'an insufficient common allowance never publishes a partial plan')
  a,work,d=advise(s,{max_evaluations=0});check(not a and not d.complete and work==0,'zero remaining allowance does no scoring')
  local changed=module_copy(mods);changed.shop_sequences={transition=function(state,action,modules)
    local next_state,why=Sequences.transition(state,action,modules)
    if next_state then next_state.consumeables={};next_state.playing_cards[1].rank=14 end
    return next_state,why
  end}
  a,work,d=advise(s,nil,changed);check(not a and not d.complete and work==0,'an admitted population mutation rejects the whole projected family')
  changed=module_copy(mods);local count=0
  changed.scoring={lower_bound=function(...)
    count=count+1;calls=calls+1;local r=actual(...)
    if count==70 then r.uncertain=true;r.reliable_bound=false end
    return r
  end}
  a,work,d=advise(s,nil,changed);check(not a and not d.complete and work==70,'late unsupported scoring cannot publish an earlier complete endpoint: '..tostring(work)..' / '..tostring(d.reason))
  eq(Snapshot.fingerprint(s),before,'failed full comparisons leave public input unchanged')
  s=state();s.playing_cards[1].enhancement='m_lucky';s.playing_cards[1].ability={name='Lucky Card',set='Enhanced',effect='Lucky Card',mult=20,p_dollars=20}
  a,work,d=advise(s);check(a and d.complete,'Lucky cards are admitted through explicit reliable floors without any mean-score call')
end

do
  local Support=dofile('tests/fixtures/gold_tarot_hold_support.lua')
  local s=state();s.joker_limit=5;s.next_blind.chips=1000
  s.jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
    joker('j_perkeo','p','Perkeo',{eternal=true}),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
    joker('j_scary_face','s','Scary Face',{extra=30}),joker('j_golden','g','Golden Joker',{extra=4})}
  for _,j in ipairs(s.jokers) do s.completionist_goal.by_key[j.key]={status='complete'} end
  s.consumeables=Support.state().consumeables;s.consumable_limit=16;s.consumeable_usage_total={tarot=8}
  local configured=module_copy(mods);configured.gold_tarot_hold=Support.Hold
  local fingerprint=Snapshot.fingerprint(s);local inventory=Snapshot.fingerprint(s.consumeables)
  local prior_context=Shop.new(s,counted,nil,{max_evaluations=50000})
  local prior,prior_diag=Goal.suggest(s,configured,{action={kind='leave_shop'}},prior_context)
  check(not prior and not prior_diag.complete and prior_context.evaluations==0,'the retained final-boss-only objective declines this pre-Big manufactured state')
  local a,work,d=advise(s,nil,configured)
  check(a and d.complete,'five completed Jokers and fourteen mixed Negative Tarots can acquire a missing visible Joker before Big')
  eq(s.dollars,170,'the manufactured excess-cash setup is explicit')
  eq(d.after_missing,1,'only the actually purchased distinct missing target gets objective credit')
  eq(a.action.kind,'sell','full five-Joker inventory needs a real completed-Joker sale')
  check(d.selected.hold_certificate.supported,'the original whole inventory has an actual qualified hold proof')
  eq(d.selected.hold_certificate.inventory_count_before,14,'all fourteen original physical Tarot cards participate')
  eq(d.selected.hold_certificate.generated_identity,'unresolved','no generated future copy identity is invented')
  eq(d.selected.hold_certificate.generated_future_utility_credit,0,'no future Tarot value is credited')
  eq(d.selected.hold_certificate.first_hand_consumable_actions,0,'the declared policy holds all original and generated cards')
  for _,endpoint in ipairs(d.endpoints) do
    for i=1,4 do check(endpoint.evidence.after_readiness.opening_scores[i]>=1250,'every admitted manufactured endpoint has an actual sufficient score floor') end
  end
  local sold=assert(Sequences.transition(s,a.action,configured));a,work,d=advise(sold,nil,configured)
  check(a and d.complete and a.action.kind=='buy','fresh advice with all fourteen Tarots completes the missing purchase')
  local bought=assert(Sequences.transition(sold,a.action,configured))
  eq(Snapshot.fingerprint(bought.consumeables),inventory,'the paid acquisition preserves every original Tarot identity and field')
  eq(#bought.jokers,5,'the visible missing target fills the freed physical slot')
  eq(bought.jokers[5].key,'j_crazy','the exact visible missing Joker is actually retained')
  eq(Snapshot.fingerprint(s),fingerprint,'the original fourteen-card state is immutable')
  local unqualified=copy(s);unqualified.consumeables[1].tarot_hold_source=nil
  a,work,d=advise(unqualified,nil,configured)
  check(not a and not d.complete and work==0,'one unqualified held Tarot rejects the whole family before scoring')
  a,work,d=advise(s)
  check(not a and not d.complete and work==0,'a missing whole-inventory helper cannot silently ignore Perkeo')
end

do
  -- Complete real scoring is deliberately made inconsistent or weak in one
  -- returned world. A claimed aggregate delta cannot authorize the purchase.
  local s=state();local configured=module_copy(mods);local original_new=Shop.new
  configured.shop_scoring={new=function(...)
    local c=original_new(...);local compare=c.compare
    function c:compare(before,after)
      local e=compare(self,before,after)
      if e and after.jokers[1].key=='j_crazy' then
        e.after_readiness.opening_scores[4]=124;e.low_sample_delta=1000
      end
      return e
    end
    return c
  end,known_joker=Shop.known_joker}
  local a,work,d=advise(s,nil,configured)
  check(not a and d.complete,'one weak world defeats a positive claimed summary and all other large scores')
  configured.shop_scoring.new=function(...)
    local c=original_new(...);local compare=c.compare
    function c:compare(before,after)
      local e=compare(self,before,after)
      if e and after.jokers[1].key=='j_crazy' then e.common_worlds.family_key='different declared draws' end
      return e
    end
    return c
  end
  a,work,d=advise(s,nil,configured)
  check(not a and not d.complete,'independently changed draw worlds invalidate the whole acquisition comparison')
  configured.shop_scoring.new=function(...)
    local c=original_new(...);local compare=c.compare
    function c:compare(before,after)
      local e=compare(self,before,after);self.evaluations=self.evaluations-1;return e
    end
    return c
  end
  a,work,d=advise(s,nil,configured)
  check(not a and not d.complete and work>0,'mismatched context accounting declines but still charges all actual floor calls')
  check(work>d.context_evaluations,'the reported work does not inherit an undercounted context')
  configured.shop_scoring.new=function(...)
    local c=original_new(...);local compare=c.compare
    function c:compare(before,after)
      compare(self,before,after);error('manufactured late comparison error')
    end
    return c
  end
  local prior=calls;local ok=pcall(A.suggest,s,configured,nil,nil)
  check(not ok and calls>prior,'unexpected comparison errors propagate to worker handling instead of swallowing a yielding boundary')
  configured.shop_scoring.new=function(...)
    local c=original_new(...);local compare=c.compare
    function c:compare(before,after)
      local e=compare(self,before,after)
      if e then e.after_readiness.ordering.action_count=1 end
      return e
    end
    return c
  end
  a,work,d=advise(s,nil,configured)
  check(not a and not d.complete,'unexecuted rearrangement evidence cannot enter the declared current-row policy')
end

print('advisor_gold_acquisition: '..checks..' manufactured checks passed; '..calls..' exact charged score-floor calls')
