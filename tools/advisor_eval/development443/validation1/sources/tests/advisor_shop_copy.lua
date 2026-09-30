local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(ok,message) checks=checks+1; assert(ok,message) end
local function copy(v) return Snapshot.copy(v) end
local function close(a,b) return math.abs(a-b)<0.000001 end
local function joker(key,label,ability,more)
  local j={id='joker:'..key,key=key,name=label,ability=ability or {},sell_cost=2,blueprint_compat=true}
  j.ability.name=label
  for k,v in pairs(more or {}) do j[k]=v end
  return j
end
local function state(row)
  local s={phase='shop',jokers=row or {},playing_cards={},dollars=25,hand_size=8,hand_limit=1,joker_limit=5,
    hands={},current_round={},round_resets={hands=4,discards=3},modifiers={},probabilities={normal=1}}
  for i,rank in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='playing:'..i,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
      suit=({'Spades','Hearts','Clubs','Diamonds'})[(i-1)%4+1],enhancement='c_base',ability={}}
  end
  return s
end
local function add(s,j)
  local out=copy(s); out.jokers[#out.jokers+1]=j; return out
end
local function bp(more) return joker('j_blueprint','Blueprint',{},more) end
local function bs(more) return joker('j_brainstorm','Brainstorm',{},more) end
local function flat(n,more) return joker('j_joker','Joker',{mult=n or 4},more) end
local function xmult(n,more) return joker('j_ramen','Ramen',{x_mult=n or 3},more) end
local random,seed=math.random,math.randomseed
math.random=function() error('copy-shop scoring advanced game RNG') end
math.randomseed=function() error('copy-shop scoring reseeded game RNG') end

local s=state({flat()})
local after=add(s,bp())
local before_fingerprint,after_fingerprint=Snapshot.fingerprint(s),Snapshot.fingerprint(after)
local ctx=Shop.new(s,Scorer)
local e=ctx:compare(s,after)
check(e and close(e.ratio,1.8),'an appended Blueprint is moved before its usable target in the scoring comparison')
check(e.before_orders<=8 and e.after_orders<=8 and e.reason:find('copy-target',1,true),
  'evidence reports the bounded copy-target layout search')
check(Snapshot.fingerprint(s)==before_fingerprint and Snapshot.fingerprint(after)==after_fingerprint,
  'copy-target search leaves both input snapshots untouched')
local repeated=Shop.new(s,Scorer):compare(s,after)
check(Snapshot.fingerprint(e)==Snapshot.fingerprint(repeated),'copy-target search is deterministic across contexts')

local x=state({xmult()})
check(close(Shop.new(x,Scorer):compare(x,add(x,bp())).ratio,3),'Blueprint copies the actual active XMult amount')
local incompatible=state({xmult(100,{blueprint_compat=false})})
check(close(Shop.new(incompatible,Scorer):compare(incompatible,add(incompatible,bp())).ratio,1),
  'a copy-incompatible target never lends its enormous XMult to Blueprint')
local impossible=state({joker('j_trio','The Trio',{x_mult=3,type='Three of a Kind'})})
check(close(Shop.new(impossible,Scorer):compare(impossible,add(impossible,bp())).ratio,1),
  'copying a conditional Joker does not erase its impossible hand-type requirement')

local storm=state({flat(4),xmult(3)})
local storm_e=Shop.new(storm,Scorer):compare(storm,add(storm,bs()))
check(storm_e and storm_e.ratio>1,'Brainstorm can move a real target to the leftmost position')
-- The poorly positioned old Blueprint receives the same target freedom as a
-- post-purchase row; a passive filler cannot take credit for merely fixing it.
local poor=state({flat(),bp()})
local passive=add(poor,joker('j_egg','Egg',{}, {blueprint_compat=false}))
local passive_e=Shop.new(poor,Scorer):compare(poor,passive)
check(passive_e and close(passive_e.ratio,1),'an unchanged copy core receives no artificial gain from adding passive filler')
local chains=state({flat(),bp()})
local chain_e=Shop.new(chains,Scorer):compare(chains,add(chains,bp({id='joker:blueprint:2'})))
check(chain_e and close(chain_e.ratio,13/9),'Blueprint chains resolve to the shared real target')
local cross=state({xmult(),flat(),bs()})
local cross_e=Shop.new(cross,Scorer):compare(cross,add(cross,bp()))
check(cross_e and cross_e.ratio>1,'Blueprint can copy Brainstorm while Brainstorm resolves to a real leftmost target')
local only_copies=state({bp(),bs()})
local loop_e=Shop.new(only_copies,Scorer):compare(only_copies,add(only_copies,bp({id='joker:blueprint:2'})))
check(loop_e and close(loop_e.ratio,1),'copy loops and missing targets produce no invented effect')
local chain_incompatible=state({flat(),bp({blueprint_compat=false})})
local outer=Shop.new(chain_incompatible,Scorer):compare(chain_incompatible,
  add(chain_incompatible,bp({id='joker:blueprint:2'})))
check(outer and close(outer.ratio,13/9),'an incompatible copy may be an outside link while every actual copy target remains compatible')

local pinned_after=add(s,bp({pinned=true}))
check(close(Shop.new(s,Scorer):compare(s,pinned_after).ratio,1),'a pinned last Blueprint cannot move before its target')
local self_storm=state({bs({ability={name='Brainstorm',pinned=true}}),flat()})
local pinned_seen,invalid_pin=false,false
local inspector={score=function(snapshot,indices)
  if #snapshot.jokers==3 then
    pinned_seen=true
    if snapshot.jokers[1].id~='joker:j_brainstorm' then invalid_pin=true end
  end
  return Scorer.score(snapshot,indices)
end}
local self_e=Shop.new(self_storm,inspector):compare(self_storm,add(self_storm,bp()))
check(pinned_seen and not invalid_pin,'ability.pinned retains its exact slot in every evaluated layout')
check(self_e and close(self_e.ratio,1.8),'a pinned self-loop Brainstorm stays inactive while a movable Blueprint can still copy')
local middle=state({flat(),bp({pinned=true}),xmult()})
local bad_layout=false
local check_middle={score=function(snapshot,indices)
  if snapshot.jokers[2].id~='joker:j_blueprint' then bad_layout=true end
  return Scorer.score(snapshot,indices)
end}
local middle_e=Shop.new(middle,check_middle):compare(middle,add(middle,joker('j_egg','Egg',{}, {blueprint_compat=false})))
check(middle_e and not bad_layout and close(middle_e.ratio,1),'a pinned interior Blueprint keeps its feasible target and slot')

local foil=Shop.new(s,Scorer):compare(s,add(s,bp({edition={foil=true}})))
check(foil and close(foil.after_mean,594),'Blueprint keeps its own foil Chips while copying the target effect')
local poly=state({flat(4,{edition={polychrome=true}})})
local poly_e=Shop.new(poly,Scorer):compare(poly,add(poly,bp()))
check(poly_e and close(poly_e.ratio,1.8),'Blueprint does not duplicate the target Joker edition')

local canonical=state({flat(),xmult(),bp()})
ctx=Shop.new(canonical,Scorer)
local permutations={{1,2,3},{1,3,2},{2,1,3},{2,3,1},{3,1,2},{3,2,1}}
local invariant=true
for _,a in ipairs(permutations) do for _,b in ipairs(permutations) do
  local left,right=copy(canonical),copy(canonical)
  for i=1,3 do left.jokers[i]=copy(canonical.jokers[a[i]]); right.jokers[i]=copy(canonical.jokers[b[i]]) end
  local evidence=ctx:compare(left,right)
  if not evidence or evidence.ratio~=1 or evidence.adjustment~=0 then invariant=false end
end end
check(invariant and not ctx.truncated,'every pair of permutations of an unchanged copy row has zero purchase gain')

local full=state({flat(),xmult(),joker('j_abstract','Abstract Joker',{extra=3}),
  joker('j_blue_joker','Blue Joker',{extra=2})})
full.hand_limit=5
local full_after=add(full,bp())
ctx=Shop.new(full,Scorer)
local full_e=ctx:compare(full,full_after)
check(full_e and not ctx.truncated and ctx.evaluations<=14000 and full_e.after_orders<=8,
  'an ordinary five-Joker copy purchase completes four paired eight-card draws within a modest shared budget')
local crowded=state({flat(),xmult(),joker('j_abstract','Abstract Joker',{extra=3}),
  joker('j_blue_joker','Blue Joker',{extra=2}),joker('j_half','Half Joker',{extra=20}),
  joker('j_cavendish','Cavendish',{extra={Xmult=3}}),bp(),bs()})
local capped=Shop.new(crowded,Scorer,nil,{max_orders=3})
local capped_e=capped:compare(crowded,add(crowded,joker('j_egg','Egg',{}, {blueprint_compat=false})))
check(capped_e and capped_e.before_orders<=3 and capped_e.after_orders<=3 and capped_e.order_shortlisted and
  capped_e.reason:find('not exhaustive',1,true) and capped.orders_shortlisted,
  'shortlisted order limits are disclosed without being mistaken for incomplete score comparisons')
local limited=Shop.new(full,Scorer,nil,{max_evaluations=1})
check(limited:compare(full,full_after)==nil and limited.truncated and limited.evaluations==0,
  'copy comparisons preflight the whole paired order cost and publish no partial evidence')

for _,v in ipairs({{'j_card_sharp','Card Sharp',{Xmult=3}},{'j_dusk','Dusk',1},{'j_acrobat','Acrobat',3}}) do
  local late=state({flat(),joker(v[1],v[2],{extra=v[3]})})
  local evidence=Shop.new(late,Scorer):compare(late,add(late,bp()))
  check(evidence and evidence.temporal and evidence.scenarios==2 and evidence.uncertain and evidence.ratio>1,
    'copying '..v[2]..' includes a shared, explicitly conditional later-hand scenario')
end
local acrobat=joker('j_acrobat','Acrobat',{extra=3})
local temporal_s=state({flat()})
local acro_e=Shop.new(temporal_s,Scorer):compare(temporal_s,add(temporal_s,acrobat))
check(acro_e and close(acro_e.ratio,1.5) and close(acro_e.temporal.weight,0.25),
  'Acrobat contributes one conditional last hand out of four rather than receiving constant X3 credit')
check(acro_e.reason:find('conditional',1,true) and acro_e.reason:find('no future growth or survival probability',1,true),
  'late-hand assumptions and their limits are explicit, not labeled activation probabilities')
local summit=joker('j_mystic_summit','Mystic Summit',{extra={mult=15,d_remaining=0}})
local summit_e=Shop.new(temporal_s,Scorer):compare(temporal_s,add(temporal_s,summit))
check(summit_e and close(summit_e.ratio,1.75) and summit_e.temporal.no_discards,
  'Mystic Summit receives discounted conditional zero-discard value while its opening effect stays inactive')
local zero_discards=copy(temporal_s); zero_discards.round_resets.discards=0
local active_summit=Shop.new(zero_discards,Scorer):compare(zero_discards,add(zero_discards,summit))
check(active_summit and close(active_summit.ratio,4),
  'a challenge with zero starting discards activates Mystic Summit in the actual opener too')
local sharp=joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})
local repeat_e=Shop.new(temporal_s,Scorer):compare(temporal_s,add(temporal_s,sharp))
check(repeat_e and close(repeat_e.ratio,1.5) and repeat_e.temporal.repeat_hand=='High Card',
  'Card Sharp uses the fixed pre-purchase target hand in the conditional repeat scenario')
local pair_focus=copy(temporal_s); pair_focus.hands.Pair={played=20,level=1}
local impossible_repeat=Shop.new(pair_focus,Scorer):compare(pair_focus,add(pair_focus,sharp))
check(impossible_repeat and impossible_repeat.temporal.repeat_hand=='Pair' and close(impossible_repeat.ratio,1),
  'an unplayable fixed repeat target cannot activate Card Sharp for every other hand type')
local fixed_target=add(pair_focus,sharp); fixed_target.hands['High Card']={played=999,level=1}
local fixed_e=Shop.new(pair_focus,Scorer):compare(pair_focus,fixed_target)
check(fixed_e and fixed_e.temporal.repeat_hand=='Pair' and close(fixed_e.ratio,1),
  'the candidate cannot choose a luckier repeat target by changing its usage metadata')
local one_hand=copy(temporal_s); one_hand.round_resets.hands=1
local one_sharp=Shop.new(one_hand,Scorer):compare(one_hand,add(one_hand,sharp))
local one_acro=Shop.new(one_hand,Scorer):compare(one_hand,add(one_hand,acrobat))
check(one_sharp and close(one_sharp.ratio,1) and one_acro and close(one_acro.ratio,3),
  'one-hand challenges cannot repeat a hand while their opener is already the final hand')

local visible=copy(temporal_s); visible.shop_jokers={sharp}
local ordinary_e=Shop.new(visible,Scorer):compare(visible,add(visible,flat(4,{id='joker:flat:2'})))
check(ordinary_e and ordinary_e.scenarios==2 and ordinary_e.temporal.repeat_hand=='High Card',
  'visible temporal shop choices use the same scenario framework for ordinary competitors')
local ramen_summit=state({xmult()})
local decline=Shop.new(ramen_summit,Scorer)
check(decline:compare(ramen_summit,add(ramen_summit,summit))==nil and not decline.truncated and decline.evaluations==0,
  'a zero-discard assumption cannot preserve Ramen while silently spending its discard cost')
local worn=state({joker('j_selzer','Seltzer',{extra=2})})
check(Shop.new(worn,Scorer):compare(worn,add(worn,acrobat))==nil,
  'a Seltzer that would disappear before the late scenario retains conservative fallback')
local ice=state({joker('j_ice_cream','Ice Cream',{extra={chips=100,chip_mod=5}})})
local seen_ice={}
local ice_scorer={score=function(snapshot,selected)
  for _,j in ipairs(snapshot.jokers) do if j.key=='j_ice_cream' then
    seen_ice[snapshot.hands_left]=j.ability.extra.chips
  end end
  return Scorer.score(snapshot,selected)
end}
local ice_e=Shop.new(ice,ice_scorer):compare(ice,add(ice,acrobat))
check(ice_e and seen_ice[4]==100 and seen_ice[1]==85,
  'known Ice Cream decay is charged before the conditional fourth hand')

local road=state({joker('j_hit_the_road','Hit the Road',{x_mult=2,extra=0.5,set='Joker',effect='Jack Discard Effect'})})
local road_e=Shop.new(road,Scorer):compare(road,add(road,flat()))
check(road_e and close(road_e.ratio,5),'an unchanged uncopied Road still permits the independent flat-Mult comparison')
local reset_road=copy(road);reset_road.jokers[1].ability.x_mult=1
local reset_e=Shop.new(reset_road,Scorer):compare(reset_road,add(reset_road,flat()))
check(reset_e.before_mean==road_e.before_mean and reset_e.after_mean==road_e.after_mean,'shop scoring resets old Road multiplier for the next round')
check(Shop.new(temporal_s,Scorer):compare(temporal_s,add(temporal_s,road.jokers[1]))==nil and
  Shop.new(road,Scorer):compare(road,add(road,bp()))==nil,
  'new or copied Hit the Road growth remains unavailable without a real discarded-Jack path')
local bounded_late=Shop.new(temporal_s,Scorer,nil,{max_evaluations=64})
check(bounded_late:compare(temporal_s,add(temporal_s,acrobat))==nil and bounded_late.truncated and bounded_late.evaluations==0,
  'late-hand comparisons preflight all scenarios without publishing an opening-only partial result')
local wide=state({flat(),joker('j_blue_joker','Blue Joker',{extra=2}),
  joker('j_abstract','Abstract Joker',{extra=3}),sharp})
wide.hand_limit=5
local wide_ctx=Shop.new(wide,Scorer)
local wide_e=wide_ctx:compare(wide,add(wide,bp()))
check(wide_e and not wide_ctx.truncated and wide_ctx.evaluations<=28000,
  'five-Joker copying plus both temporal scenarios still completes below the hard 50k budget')
local frozen=Snapshot.fingerprint(wide)
local again=Shop.new(wide,Scorer):compare(wide,add(wide,bp()))
check(Snapshot.fingerprint(again)==Snapshot.fingerprint(wide_e) and Snapshot.fingerprint(wide)==frozen,
  'temporal scoring is deterministic, does not advance RNG, and leaves the source state untouched')
math.random,math.randomseed=random,seed
print('advisor_shop_copy: '..checks..' checks passed')
