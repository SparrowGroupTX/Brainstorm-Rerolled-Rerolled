local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function joker(key,a,cost)
  a=a or {};a.set='Joker'
  a.name=a.name or ({j_credit_card='Credit Card',j_diet_cola='Diet Cola'})[key]
  return {key=key,ability=a,cost=cost or 99,sell_cost=2}
end
local function state()
  local s={phase='pack',ante=2,dollars=0,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={},consumeables={},hand={},deck={},playing_cards={},pack_cards={},
    hand_size=8,hand_limit=5,hands={Pair={level=1,played=6}},
    round_resets={hands=4,discards=3},current_round={},hands_left=0,discards_left=0,
    blind={key='bl_small'},modifiers={},probabilities={normal=1},interest_cap=25}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='pack:'..i,rank=r,suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={}}
  end
  return s
end
local modules={strategy=S,scoring=Scoring,shop_scoring=Shop}
do
  local s=state()
  s.pack_cards={joker('j_devious',{t_chips=100,type='Straight'}),joker('j_joker',{mult=4})}
  local original=Snapshot.fingerprint(s)
  local result=D.run(s,modules)
  check(result.action.kind=='choose' and result.action.index==2,'weak build takes usable flat Mult over an impossible Straight bonus')
  check(result.evaluations>0 and not result.pack_diagnostics.tactical_fallback,'revealed Buffoon choices receive complete real scoring')
  check(#result.pack_diagnostics.offers==2 and #result.pack_diagnostics.comparisons==2,'both offered cards and paired comparisons remain reviewable')
  check(result.pack_diagnostics.offers[1].card.key=='j_devious' and result.pack_diagnostics.offers[1].score,
    'rejected offer identity and rating are retained')
  check(result.strategy.scoring_evidence.after_mean>result.strategy.scoring_evidence.before_mean,'selected offer exposes its paired scoring result')
  check(Snapshot.fingerprint(s)==original,'pack comparison preserves the input snapshot')
  check(Snapshot.fingerprint(result)==Snapshot.fingerprint(D.run(s,modules)),'pack scoring is deterministic')
end
do
  local s=state();s.jokers={joker('j_joker',{mult=4})}
  s.pack_cards={joker('j_blackboard',{extra=3}),joker('j_popcorn',{mult=20})}
  for _,c in ipairs(s.playing_cards) do c.suit='Hearts' end
  local red=D.run(s,modules)
  check(red.action.index==2,'red held cards make Popcorn a stronger revealed choice than inactive Blackboard')
  for _,c in ipairs(s.playing_cards) do c.suit='Spades' end
  s.jokers[1].ability.mult=40
  local black=D.run(s,modules)
  check(black.action.index==1,'the same offers favor Blackboard in an established compatible black-suit build')
end
do
  local s=state();s.dollars=-5;s.bankrupt_at=-20;s.modifiers={chips_dollar_cap=true,minus_hand_size_per_X_dollar=5}
  s.pack_cards={joker('j_stuntman',{extra={chip_mod=250,h_size=2}},99)}
  local seen=0
  local result=S.advise(s,{shop_scoring={compare=function(_,before,after)
    seen=seen+1
    check(after.dollars==-5 and after.hand_size==6,'free selection preserves debt/cash while applying Stuntman hand-size cost')
    return {adjustment=10,ratio=2,reason='Paired fixture.'}
  end}})
  check(seen==1 and result.action.kind=='choose','pack selection ignores a shop sticker price even with no purchase cash')
  check(result.pack_diagnostics.offers[1].selection_cost==0,'trace states the actual free selection cost')
end
do
  local s=state();s.joker_limit=2
  s.jokers={joker('j_joker',{mult=4,eternal=true}),joker('j_credit_card',{extra=20})}
  s.bankrupt_at=-20;s.dollars=-5
  s.pack_cards={joker('j_blackboard',{extra=3}),joker('j_popcorn',{mult=20})}
  for _,c in ipairs(s.playing_cards) do c.suit='Hearts' end
  local original=Snapshot.fingerprint(s)
  local result=D.run(s,modules)
  check(result.action.kind=='sell' and result.action.index==2 and result.action.followup.index==2,
    'full row replaces actual Credit Card with the compatible revealed Popcorn')
  check(result.replacement==nil and result.strategy.replacement.cash_after_purchase==-3,'free replacement keeps sale proceeds without charging the sticker price')
  local compared,blocked=0,0
  for _,entry in ipairs(result.pack_diagnostics.comparisons) do
    if entry.legal then compared=compared+1;check(entry.status=='complete','every legal retained-row comparison completes')
    else blocked=blocked+1 end
  end
  check(compared==2 and blocked==2,'each actual offer is checked with the only sellable victim and the Eternal victim is recorded blocked')
  check(Snapshot.fingerprint(s)==original,'replacement preview preserves owned rows, borrowing and cash')
  s.jokers[2].pinned=true
  check(D.run(s,modules).action.kind=='skip_pack','pinned owned Joker is preserved')
  s.jokers[2].pinned=nil;s.jokers[2].edition={negative=true}
  check(D.run(s,modules).action.kind=='skip_pack','selling a Negative Joker does not invent an ordinary slot')
  s.pack_cards[1].edition={negative=true}
  check(D.run(s,modules).action.kind=='choose','direct Negative pack selection uses its own capacity without a sale')
end
do
  local s=state();s.joker_limit=2
  s.jokers={joker('j_credit_card',{extra=20}),joker('j_diet_cola')}
  s.pack_cards={joker('j_joker',{mult=4}),joker('j_popcorn',{mult=20})}
  local compared_pairs={}
  S.advise(s,{shop_scoring={compare=function(_,before,after)
    check(#before.jokers==2 and #after.jokers==2,'replacement evidence uses the complete original and retained rows')
    local key=after.jokers[1].key..':'..after.jokers[2].key;compared_pairs[key]=true
    return {adjustment=10,ratio=2,reason='Paired fixture.'}
  end}})
  local n=0;for _ in pairs(compared_pairs) do n=n+1 end
  check(n==4,'all four offer-victim pairs are compared rather than only the top incoming offer for each victim')
end
do
  local s=state();s.pack_cards={joker('j_blackboard',{extra=3}),joker('j_popcorn',{mult=20})}
  for _,c in ipairs(s.playing_cards) do c.suit='Hearts' end
  local baseline=S.advise(s)
  local capped=D.run(s,modules,nil,{shop_scoring={max_evaluations=900}})
  check(capped.shop_diagnostics.truncated and capped.pack_diagnostics.tactical_fallback,'incomplete paired coverage falls back as a whole pack decision')
  check(capped.action.index==baseline.action.index,'partially scored offers cannot gain an advantage from evaluation order')
  check(#capped.pack_diagnostics.attempted_comparisons==2 and #capped.pack_diagnostics.offers==2,'fallback retains all offers and incomplete scoring evidence')
  s.pack_cards[2]=joker('j_unknown_mod',{x_mult=99})
  baseline=S.advise(s)
  local unsupported=D.run(s,modules)
  check(unsupported.pack_diagnostics.tactical_fallback and not unsupported.shop_diagnostics.truncated,'unsupported offer causes an explicit complete strategic fallback')
  check(unsupported.action.index==baseline.action.index,'unknown mechanics receive no optimistic partial forecast')
end
do
  local s=state();s.joker_limit=0;s.modifiers={all_eternal=true}
  s.jokers={joker('j_joker',{mult=4,eternal=true})};s.pack_cards={joker('j_popcorn',{mult=20})}
  check(D.run(s,modules).action.kind=='skip_pack','locked over-capacity rows do not invent a replacement slot')
  s.modifiers={};s.joker_limit=1;s.jokers={joker('j_invisible',{invis_rounds=2,extra=2})}
  check(D.run(s,modules).action.kind=='skip_pack','charged Invisible Joker cannot promise a slot after a random copy')
end
print('advisor_pack_scoring: '..checks..' checks passed')
