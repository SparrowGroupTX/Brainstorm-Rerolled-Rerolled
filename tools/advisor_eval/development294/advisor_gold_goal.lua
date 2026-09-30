-- Synthetic detached goal comparisons only. No profile/game/source access.
local Goal=dofile('tools/advisor_eval/development294/gold_goal.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
local modules={strategy=Strategy,shop_sequences=Sequences,shop_scoring=Shop,liquidity=Liquidity,consumables=Consumables}
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
local function eq(a,b,message) check(a==b,(message or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) return Snapshot.copy(v) end
local labels={j_joker='Joker',j_wily='Wily Joker',j_golden='Golden Joker',j_credit_card='Credit Card',
  j_mime='Mime',j_bull='Bull',j_egg='Egg',j_popcorn='Popcorn',j_chaos='Chaos the Clown',j_juggler='Juggler',j_hiker='Hiker'}
local function joker(key,id,cost,a)
  a=a or {};a.set='Joker';a.name=labels[key] or key
  return {key=key,id=id,name=a.name,cost=cost or 0,sell_cost=2,base_cost=cost or 0,ability=a,
    rarity=1,debuff=false,pinned=false}
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=20,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    consumeable_buffer=0,consumeables={{id='held',key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}},
    jokers={joker('j_joker','engine',2,{mult=4,eternal=true})},shop_jokers={joker('j_wily','offer',5,{t_chips=100,type='Three of a Kind'})},
    shop_booster={},shop_vouchers={},hand_size=4,hand_limit=5,hands_left=4,discards_left=3,
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',hands={},playing_cards={},hand={},deck={},
    next_blind={key='bl_final_vessel',name='Violet Vessel',boss=true,ante=8,chips=100},
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={status='eligible',eligible=true},by_key={j_joker={status='complete'},j_wily={status='missing'},
        j_golden={status='missing'},j_credit_card={status='complete'},j_mime={status='missing'},j_bull={status='complete'},
        j_egg={status='missing'},j_popcorn={status='missing'},j_chaos={status='missing'}}}}
  for i=1,16 do s.playing_cards[i]={id='p'..i,rank=2+i%8,nominal=2+i%8,suit=({'Spades','Hearts','Clubs','Diamonds'})[1+i%4],ability={}} end
  return s
end
local hold={action={kind='leave_shop'}}
local function context(value)
  local c={evaluations=0,max_evaluations=50000,truncated=false,seen={}}
  value=value or function() return 1000 end
  function c:compare(before,after)
    self.evaluations=self.evaluations+1
    self.seen[#self.seen+1]={before=copy(before),after=copy(after)}
    local a,b,low,total_a,total_b={},{},math.huge,0,0
    for i=1,4 do a[i]=value(before,i);b[i]=value(after,i);low=math.min(low,b[i]-a[i]);total_a=total_a+a[i];total_b=total_b+b[i] end
    local target=before.next_blind.chips
    return {samples=4,uncertain=false,low_sample_delta=low,before_target=target,after_target=target,
      before_mean=total_a/4,after_mean=total_b/4,ratio=total_b/total_a,
      before_readiness={supported=true,samples=4,target=target,opening_scores=a,discards=3},
      after_readiness={supported=true,samples=4,target=target,opening_scores=b,discards=3}}
  end
  return c
end
local function contains(s,key) for _,j in ipairs(s.jokers) do if j.key==key then return true end end end
do
  local s=state();local before=Snapshot.fingerprint(s);local base=copy(hold);local base_before=Snapshot.fingerprint(base)
  local c=context();local advice,d=Goal.suggest(s,modules,base,c)
  check(advice and d.complete,'neutral missing cargo is selected after the whole declared comparison')
  eq(advice.action.kind,'buy','direct free-slot cargo purchase is executable')
  eq(advice.action.index,1,'the actual visible missing Joker is selected')
  eq(d.before_missing,0,'incumbent carries no missing target');eq(d.after_missing,1,'one unique target is projected')
  eq(#d.endpoints,2,'hold and the only legal affordable buy are compared')
  eq(d.comparisons,2,'all admitted endpoints use the same hold reference')
  eq(d.selected.cash_after,15,'purchase cost is included before comparing scoring')
  eq(d.selected.inventory[1].id,'held','owned consumable identity remains retained')
  eq(Snapshot.fingerprint(s),before,'the entire public input is immutable')
  eq(Snapshot.fingerprint(base),base_before,'the exact ordinary recommendation is immutable')
  s.shop_jokers[2]=joker('j_golden','offer2',3,{extra=4})
  advice,d=Goal.suggest(s,modules,hold,context())
  check(advice and d.complete,'all stable visible offers are included without a strategic rating gate')
  eq(#d.endpoints,3,'both visible buys and hold complete')
  eq(advice.action.index,2,'equal missing gain and sampled chips prefer actual cash')
  advice,d=Goal.suggest(s,modules,hold,context(function(x) return contains(x,'j_wily') and 1100 or 1000 end))
  eq(advice.action.index,1,'supported sampled chips precede cash when target gain is equal')
end
do
  local s=state();s.jokers[1].ability.eternal=nil;s.jokers[1].key='j_wily';s.jokers[1].ability.name='Wily Joker'
  s.shop_jokers={joker('j_joker','new-complete',5,{mult=4})}
  local base={action={kind='sell',area='jokers',index=1,followup={kind='buy',area='shop_jokers',index=1}}}
  local advice,d=Goal.suggest(s,modules,base,context())
  check(advice and d.complete,'a fully compared hold can retain missing cargo over a neutral replacement')
  eq(advice.action.kind,'leave_shop','retention is a supported goal comparison, not an unconditional sale veto')
  eq(d.before_missing,0,'exact sale-then-buy endpoint is the incumbent reference')
  eq(d.after_missing,1,'hold preserves the actual missing identity')
  eq(#d.endpoints,4,'hold, buy, sale-buy and buy-sale all complete')
  eq(d.comparisons,8,'every endpoint is checked against hold and the exact incumbent')
  s.joker_limit=1
  local no,negative=Goal.suggest(s,modules,base,context(function(x) return contains(x,'j_joker') and 1100 or 1000 end))
  check(not no and negative.complete,'holding missing cargo cannot displace a stronger supported incumbent')
  s=state();s.jokers[1]=joker('j_wily','already-carried',0,{eternal=true})
  local ctx=context();no,negative=Goal.suggest(s,modules,hold,ctx)
  check(not no and negative.complete,'a duplicate missing key does not count as another sticker opportunity')
  eq(ctx.evaluations,0,'complete duplicate-only coverage declines before opening comparisons')
  check(negative.projection_complete and not negative.evidence_complete,'projection-only completion does not imply sampled score evidence')
  s=state();s.completionist_goal.by_key.j_wily.status='complete';ctx=context()
  no,negative=Goal.suggest(s,modules,hold,ctx)
  check(not no and negative.complete and negative.projection_complete,'all-complete offers have an explicitly complete projected family')
  eq(ctx.evaluations,0,'all-complete coverage requires no score calls')
end
do
  local s=state();s.shop_jokers[1].ability.rental=true;s.shop_jokers[1].cost=1;s.dollars=3
  local advice,d=Goal.suggest(s,modules,hold,context())
  check(not advice and d.complete,'a rental cargo purchase cannot spend its near-term rental reserve')
  s.dollars=4;advice,d=Goal.suggest(s,modules,hold,context())
  check(advice and d.complete,'an actually funded rental can enter the supported final-opening comparison')
  eq(d.selected.liquidity.rental_cost,3,'the true rental charge is reserved')
  s.shop_jokers[1].ability.perishable=true;s.shop_jokers[1].ability.perish_tally=1
  advice,d=Goal.suggest(s,modules,hold,context())
  check(advice and d.complete,'a perishable is retained physically while the final opening remains independently supported')
  s.shop_jokers[1].ability.perish_tally=nil
  advice,d=Goal.suggest(s,modules,hold,context())
  check(not advice,'unknown perishable timing earns no cargo credit')
  s=state();s.jokers[1]=joker('j_credit_card','credit',0,{extra=20});s.joker_limit=1;s.bankrupt_at=-20;s.dollars=0
  advice,d=Goal.suggest(s,modules,hold,context())
  check(not advice and d.complete,'a full row cannot finance the buy using borrowing removed by its required sale')
  eq(#d.endpoints,1,'all unaffordable or full-slot credit endpoints are recorded exclusions')
end
do
  local s=state();s.joker_limit=2;s.jokers[1].ability.eternal=nil
  s.jokers[2]=joker('j_golden','negative-victim',0,{})
  s.jokers[2].edition={negative=true,type='negative'}
  s.completionist_goal.by_key.j_golden.status='complete'
  local _,d=Goal.suggest(s,modules,hold,context())
  check(d.complete,'source-shaped Negative editions are admitted')
  for _,endpoint in ipairs(d.endpoints) do
    check(not (endpoint.actions[1] and endpoint.actions[1].kind=='sell' and endpoint.actions[1].index==2),
      'selling the Negative slot provider cannot invent an ordinary free slot')
  end
  s=state();s.shop_jokers[1].edition={foil=true,type='foil',chips=50}
  check(Goal.stable_card(s.shop_jokers[1]),'source-shaped edition numeric fields are retained')
  s.shop_jokers[1].edition={foil=true,type='negative',chips=50}
  check(not Goal.stable_card(s.shop_jokers[1]),'mismatched edition identity is outside support')
end
do
  local s=state();local c=context(function(x,i) return contains(x,'j_wily') and (i==4 and 999 or 1500) or 1000 end)
  local advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and d.complete,'an aggregate chip gain cannot compensate for one worse common world')
  local actual_compare=c.compare
  function c:compare(a,b) local e=actual_compare(self,a,b);e.low_sample_delta=0;return e end
  advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and d.complete,'actual per-world score arrays cannot be overridden by a claimed nonnegative summary')
  advice,d=Goal.suggest(s,modules,hold,context(function() return 124 end))
  check(not advice and d.complete,'all four candidate openings need the stated margin')
  advice,d=Goal.suggest(s,modules,hold,context(function(x) return contains(x,'j_wily') and 130 or 90 end))
  check(advice and d.complete,'a positive supported upgrade can establish margin even when hold does not clear')
  c=context();local original=c.compare
  function c:compare(a,b) local e=original(self,a,b);if self.evaluations==2 then e.uncertain=true end;return e end
  advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and not d.complete,'late unsupported scoring invalidates the entire declared goal comparison')
  c=context();original=c.compare
  function c:compare(a,b) local e=original(self,a,b);if self.evaluations==2 then self.truncated=true end;return e end
  advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and not d.complete,'shared-budget exhaustion cannot publish a partial goal winner')
  c=context();original=c.compare
  function c:compare(a,b) local e=original(self,a,b);e.temporal={weight=.25};return e end
  advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and not d.complete,'conditional later-hand scoring cannot certify an immediate clear')
end
do
  local s=state();local before=Snapshot.fingerprint(s)
  local bad={};for k,v in pairs(modules) do bad[k]=v end
  bad.shop_sequences={transition=function() return nil,'unsupported admitted transition' end}
  local advice,d=Goal.suggest(s,bad,hold,context())
  check(not advice and not d.complete and d.comparisons==0,'unknown admitted transitions cannot be dropped from the family')
  bad.shop_sequences={transition=function(a,b,m)
    local after,why=Sequences.transition(a,b,m)
    if after then after.consumeables={} end
    return after,why
  end}
  advice,d=Goal.suggest(s,bad,hold,context())
  check(not advice and not d.complete,'goal endpoints cannot erase whole consumable inventory')
  eq(Snapshot.fingerprint(s),before,'failed endpoint proposals leave all input state untouched')
  for _,change in ipairs({function(x) x.ante=7 end,function(x) x.next_blind.key='bl_final_bell' end,
    function(x) x.completionist_goal.eligibility.eligible=false end,function(x) x.completionist_goal.metadata_status='unavailable' end,
    function(x) x.jokers[1]=joker('j_popcorn','food',0,{mult=4,extra=4}) end,
    function(x) x.jokers[1]=joker('j_chaos','unmodeled-free-rerolls',0,{}) end,
    function(x) x.jokers[1]=joker('j_midas_mask','enhancement-replacement',0,{}) end,
    function(x) x.jokers[1]=joker('j_vampire','enhancement-removal',0,{x_mult=1,extra=.1}) end}) do
    local changed=copy(s);change(changed);local ctx=context()
    advice,d=Goal.suggest(changed,modules,hold,ctx)
    check(not advice and not d.complete and ctx.evaluations==0,'out-of-scope state declines before scoring')
  end
  advice,d=Goal.suggest(s,modules,{action={kind='use',area='consumeables',index=1}},context())
  check(not advice and not d.complete,'a consumable incumbent is not silently replaced by a partial endpoint')
  local sequence={action={kind='buy',area='shop_jokers',index=1},shop_sequence={complete=true,
    actions={{kind='buy',area='shop_jokers',index=1},{kind='use',area='consumeables',index=1}}}}
  advice,d=Goal.suggest(s,modules,sequence,context())
  check(not advice and not d.complete,'a proven compound incumbent retains its omitted use continuation')
  sequence={action={kind='buy',area='shop_jokers',index=1,followup={kind='use',area='consumeables',index=1}}}
  advice,d=Goal.suggest(s,modules,sequence,context())
  check(not advice and not d.complete,'a direct-buy followup cannot be dropped from the incumbent')
  sequence={action={kind='sell',area='jokers',index=1,followup={kind='buy',area='shop_jokers',index=1,
    followup={kind='use',area='consumeables',index=1}}}}
  advice,d=Goal.suggest(s,modules,sequence,context())
  check(not advice and not d.complete,'a nested replacement followup cannot be dropped')
  sequence={action={kind='buy',area='shop_jokers',index=1},shop_sequence={complete=true,
    actions={{kind='buy',area='shop_jokers',index=1,followup={kind='use',area='consumeables',index=1}}}}}
  advice,d=Goal.suggest(s,modules,sequence,context())
  check(not advice and not d.complete,'a declared sequence step cannot hide an omitted nested action')
  advice,d=Goal.suggest(nil,modules,hold,context())
  check(not advice and not d.complete,'missing public snapshot declines explicitly')
  s.completionist_goal.eligibility=true
  advice,d=Goal.suggest(s,modules,hold,context())
  check(not advice and not d.complete,'malformed eligibility cannot enable cargo advice')
end
do
  -- Real detached score comparison: a passive missing Golden Joker has no
  -- first-hand score contribution, yet the already developed deck clears.
  local s=state();s.shop_jokers={joker('j_golden','real-offer',5,{extra=4})}
  for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
    'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}) do
    s.hands[hand]={chips=100,mult=10,level=10,played=1}
  end
  local c=Shop.new(s,Score,nil,{max_evaluations=50000})
  local advice,d=Goal.suggest(s,modules,hold,c)
  check(advice and d.complete,'actual scoring admits a neutral affordable Gold cargo option')
  eq(advice.action.kind,'buy','actual comparison selects the visible neutral income Joker')
  eq(d.selected.hold_evidence.low_sample_delta,0,'actual four-world chip equality is explicit')
  for i=1,4 do check(d.selected.hold_evidence.after_readiness.opening_scores[i]>=125,'actual candidate world clears with margin') end
  s.jokers[1]=joker('j_bull','cash-sensitive',0,{extra=100,eternal=true})
  c=Shop.new(s,Score,nil,{max_evaluations=50000});advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and d.complete,'actual Bull scoring prevents spending that lowers first-hand chips')
  print('gold goal real fixture: '..c.evaluations..' scores, complete='..tostring(d.complete))
end
do
  -- Different hand sizes must split the same underlying four permutations;
  -- neither endpoint gets independently resampled or privileged hidden draws.
  local s=state();s.shop_jokers={joker('j_juggler','hand-size-offer',5,{h_size=1})}
  s.completionist_goal.by_key.j_juggler={status='missing'}
  for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
    'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}) do
    s.hands[hand]={chips=100,mult=10,level=10,played=1}
  end
  local observed={[4]={},[5]={}};local seen={[4]={},[5]={}}
  local scorer={score=function(trial,selected)
    local ids={};for _,card in ipairs(trial.hand) do ids[#ids+1]=card.id end
    for _,card in ipairs(trial.deck) do ids[#ids+1]=card.id end
    local key=table.concat(ids,',');local size=#trial.hand
    assert(observed[size],'unexpected paired hand size')
    if not seen[size][key] then seen[size][key]=true;observed[size][#observed[size]+1]=key end
    return Score.score(trial,selected)
  end}
  local before=Snapshot.fingerprint(s);local ctx=Shop.new(s,scorer,nil,{max_evaluations=50000})
  local advice,d=Goal.suggest(s,modules,hold,ctx)
  check(advice and d.complete,'actual scoring admits a supported hand-size cargo purchase')
  eq(#observed[4],4,'four original opening permutations were scored')
  eq(#observed[5],4,'four changed-hand-size opening permutations were scored')
  for i=1,4 do eq(observed[4][i],observed[5][i],'each paired world shares the full ordered population') end
  eq(Snapshot.fingerprint(s),before,'paired hand-size scoring leaves the public input unchanged')
  check(Goal.stable_card(joker('j_hiker','positive-permanent-chips',0,{extra=5})),
    'Hiker remains admitted with separately supported positive per-repetition card growth')
end
print('gold goal: '..checks..' checks passed; synthetic objective coverage, no recorded stickers or win odds')
