-- Independently manufactured cards and resources; no captured-state replay.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local G=dofile('Brainstorm/Advisor/growth.lua')
local Q=dofile('Brainstorm/Advisor/scoring.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function clone(t) if type(t)~='table' then return t end local r={};for k,v in pairs(t) do r[k]=clone(v) end return r end
local function card(id,rank,suit,enhancement)
  local c={id=id,rank=rank,suit=suit or 'Clubs',enhancement=enhancement or 'c_base',ability={}}
  if enhancement=='m_glass' then c.ability={name='Glass Card',x_mult=2,extra=4}
  elseif enhancement=='m_steel' then c.ability={name='Steel Card',h_x_mult=1.5} end
  return c
end
local function state()
  local s={teacher_profile='perkeo_yorick_win_v1',phase='hand',ante=3,win_ante=8,
    hand={},deck={},playing_cards={},jokers={},hands={Pair={level=1,played=1,chips=10,mult=2}},
    consumeables={{key='c_death',ability={name='Death',set='Tarot'}},{key='c_death',ability={name='Death',set='Tarot'}}},
    consumable_limit=2,hand_size=5,hand_limit=5,dollars=30,blind={chips=100},chips=0,
    hands_left=2,hands_played=0,discards_left=3,discards_used=0,current_round={},modifiers={},probabilities={normal=1}}
  for r=2,14 do for _,su in ipairs({'Clubs','Spades','Diamonds','Hearts'}) do
    s.playing_cards[#s.playing_cards+1]=card('population:'..r..su,r,su)
  end end
  return s
end
local s=state();local profile=S.build_profile(s)
local function value(c) return S.target_value(s,c,profile.stats) end
for i,r in ipairs({13,12,14,10}) do
  check(value(card('a',r))>value(card('b',({12,14,10,11})[i])),'rank preference '..r)
end
for i,su in ipairs({'Clubs','Spades','Diamonds'}) do
  check(value(card('a',13,su))>value(card('b',13,({'Spades','Diamonds','Hearts'})[i])),'suit preference '..su)
end
local properties={'m_glass','polychrome','m_steel','foil','holo','m_mult','m_bonus'}
local function property(p,r)
  local c=card(p,r or 13);if p:sub(1,2)=='m_' then c.enhancement=p else c.edition={[p]=true} end return c
end
for i=1,#properties-1 do check(value(property(properties[i]))>value(property(properties[i+1])),'property order '..properties[i]) end
check(value(property('m_glass',2))>value(card('plain',13)),'strong enhancement outweighs generic rank prior')
local red=property('m_glass');red.edition={polychrome=true};red.seal='Red'
local blue=clone(red);blue.seal='Blue';local purple=clone(blue);purple.seal='Purple'
check(value(red)>value(blue) and value(blue)>value(purple),'seals stack with enhancement and edition')
check(value(red)>value(property('m_glass'))+60,'stacked abilities are not mutually exclusive')
s.jokers={{key='j_wee',ability={name='Wee Joker'}}}
check(S.target_value(s,card('two',2),profile.stats)>S.target_value(s,card('king',13),profile.stats),'real rank synergy can reverse generic order')
s=state();s.hand={card('strong',13,'Clubs','m_glass'),card('weak',2,'Hearts'),card('middle',12,'Spades')}
local targets,_,order=S.development_targets(s,s.consumeables[1])
check(order and order[#order]==1,'strong left source beats a positive but weaker legal copy')
local reordered=clone(s);reordered.hand={s.hand[2],s.hand[3],s.hand[1]}
targets=S.development_targets(reordered,reordered.consumeables[1])
check(targets[1]==1 and targets[2]==3,'after reorder strongest source replaces weakest target')
local transformed=C.apply(reordered,1,targets)
check(transformed.hand[1].id=='weak' and transformed.hand[1].enhancement=='m_glass' and transformed.hand[1].rank==13,'Death preserves recipient identity and copies source properties')
local calls=0
local scorer={score=function() calls=calls+1;return {score=200,legal=true,uncertain=false,glass_exposure={}} end}
local baseline={score=200,legal=true,uncertain=false,indices={3},glass_exposure={}}
local advice,work=C.develop(s,scorer,baseline,{strategy=S})
check(advice and advice.action.kind=='reorder_hand' and advice.action.order[3]==1,'owned safe development publishes reorder before use')
check(work==calls and work<=6,'reorder and endpoint work charged within development cap')
local capped=C.develop(s,scorer,baseline,{strategy=S,max_development_evaluations=1})
check(not capped,'incomplete reorder and use proof produces no action')
local risk={score=function(_,indices)return {score=200,legal=true,uncertain=false,glass_exposure={{index=indices[1],probability=0.25}}}end}
check(not C.develop(s,risk,baseline,{strategy=S}),'optional development cannot increase Glass exposure')

local function fishing()
  local x=state();x.blind.chips=1200
  x.jokers={{key='j_joker',ability={name='Joker',mult=100}}}
  x.hand={card('anchor',14),card('b',2,'Hearts'),card('c',3),card('d',4),card('e',5)}
  x.deck={};for i=1,12 do x.deck[i]=card('draw:'..i,i<=6 and 13 or 7,'Clubs',i<=6 and 'm_glass' or nil) end
  x.playing_cards={};for _,a in ipairs({x.hand,x.deck}) do for _,c in ipairs(a) do x.playing_cards[#x.playing_cards+1]=c end end
  return x
end
local modules={scoring=Q,strategy=S,search=Search,consumables=C,growth=G}
s=fishing();baseline=Q.score(s,{1});baseline.indices={1}
local fingerprint=Snapshot.fingerprint(s)
local growth,n=G.suggest(s,modules,baseline)
check(growth and growth.action.kind=='discard' and growth.growth.death_source,'safe discard fishes for a better source before weak optional Death')
check(growth.growth.death_source.complete_public_distribution and not growth.growth.death_source.guaranteed_source,'complete distribution is not a guarantee')
for _,i in ipairs(growth.action.indices) do check(i~=1,'discard preserves clearing anchor') end
local after=Q.after_discard(s,growth.action.indices)
check(Q.score(after,growth.play.indices).score>=s.blind.chips*1.05,'clear survives even if source search misses')
check(n<=12 and Snapshot.fingerprint(s)==fingerprint,'bounded nonmutating fishing comparison')
-- Independently enumerate every unordered draw for the chosen discard.
-- Each endpoint can use the best revealed source or hold; no score rollout.
local removed={};for _,i in ipairs(growth.action.indices) do removed[i]=true end
local prof=S.build_profile(s)
local used=C.apply(s,1,{1,2});local loss=S.preservation_cost(s,used,1)
local function gain(i,c)local t={hand={}};t.hand[i]=c;return S.development_gain(s,t,{i},prof)-loss-4 end
local now=0;for i in ipairs(s.hand) do for j,c in ipairs(s.hand) do if i~=j then now=math.max(now,gain(i,c)) end end end
local expected=0
for recipient=2,#s.hand do if not removed[recipient] then
  local hold=0;for source,c in ipairs(s.hand) do if source~=recipient and not removed[source] then hold=math.max(hold,gain(recipient,c)) end end
  local sum,count=0,0;local chosen={}
  local function visit(start)
    if #chosen==growth.growth.death_source.draws then
      local best=hold;for _,i in ipairs(chosen) do best=math.max(best,gain(recipient,s.deck[i])) end
      sum=sum+best;count=count+1;return
    end
    for i=start,#s.deck do chosen[#chosen+1]=i;visit(i+1);chosen[#chosen]=nil end
  end
  visit(1);expected=math.max(expected,sum/count-now)
end end
check(math.abs(expected-growth.growth.death_source.expected_improvement)<1e-8,'analytic source expectation equals exhaustive unordered draw endpoints')
local integrated=D.run(s,modules,nil,{search={fast_clear=true}})
check(integrated.action.kind=='discard' and integrated.evaluations<=70,'fast-clear arbitration compares Death fishing before development within70')
local ordinary=D.run(s,modules,nil,{search={fast_clear=false}})
check(ordinary.action.kind=='discard' and ordinary.evaluations<=140000,'ordinary clear arbitration also compares fishing first')
local weak=fishing();weak.blind.chips=999999
local p=Q.score(weak,{1});p.indices={1}
check(not G.suggest(weak,modules,p),'unsafe final-hand-like deficit cannot be discarded for development')
weak.hands_left=1;check(not G.suggest(weak,modules,p),'one hand does not excuse unsafe fishing')
check(not G.suggest(s,modules,baseline,{max_evaluations=0}),'no score budget means no fishing action')
weak=fishing();weak.deck[1].unknown=true
check(not G.suggest(weak,modules,baseline),'unknown public composition cannot support source fishing')
weak=fishing();weak.playing_cards={}
check(not G.suggest(weak,modules,baseline),'missing population cannot support source fishing')
weak=fishing();weak.playing_cards[2].id=nil
check(not G.suggest(weak,modules,baseline),'missing physical ID declines without throwing')
weak=fishing();weak.deck=nil
check(not G.suggest(weak,modules,baseline),'omitted remaining deck declines without throwing')
weak=fishing();weak.modifiers.discard_cost=200;weak.hands_left=1
check(not G.suggest(weak,modules,baseline),'actual discard/interest cost can outweigh source option')
weak=fishing();weak.hand[2]=clone(weak.deck[1]);weak.hand[2].id='b'
weak.playing_cards={};for _,a in ipairs({weak.hand,weak.deck}) do for _,c in ipairs(a) do weak.playing_cards[#weak.playing_cards+1]=c end end
check(not G.suggest(weak,modules,baseline),'already held strongest source prevents unnecessary fishing')
weak=fishing();weak.jokers[#weak.jokers+1]={key='j_yorick',ability={name='Yorick',x_mult=1,yorick_discards=2,extra={discards=23,xmult=1}}}
local p=Q.score(weak,{1});p.indices={1};growth=G.suggest(weak,modules,p)
check(growth and growth.growth.effects.yorick_growth==1 and growth.growth.death_source,'source fishing includes exact Yorick discard growth')
print('advisor_death_selection400: '..checks..' manufactured checks passed')

--404 public disposition covers selected and rejected fishing plus final action.
--419 prioritizes full discard volume. Seven held cards leave a physical Death
-- recipient even after the largest batch, preserving this receipt contract.
local function receipt_fishing()
 local x=fishing();x.hand_size=7;x.hand[6]=card('f',6);x.hand[7]=card('g',8)
 x.playing_cards={};for _,a in ipairs({x.hand,x.deck})do for _,c in ipairs(a)do x.playing_cards[#x.playing_cards+1]=c end end
 return x
end
do
 local x=receipt_fishing();local anchor=Q.score(x,{1});anchor.indices={1}
 local chosen,work,diag=G.suggest(x,modules,anchor)
 check(diag.death_fishing.attempted and diag.death_fishing.selected and diag.death_fishing.distribution_comparisons>0,'selected fishing has explicit bounded distribution receipt')
 local receipt=dofile('Brainstorm/Advisor/player_journal.lua').compact_copy_death_review(D.run(x,modules,nil,{search={fast_clear=true}}))
 check(receipt.fishing.status=='selected' and receipt.final_kind=='discard','final fishing receipt survives real decision and public serialization')
 local volume=D.run(fishing(),modules,nil,{search={fast_clear=true}})
 local honest=dofile('Brainstorm/Advisor/player_journal.lua').compact_copy_death_review(volume)
 check(#volume.action.indices==4 and honest.final_kind=='discard' and not honest.fishing.selected and honest.fishing.positive_comparisons>0,
  'discard volume may supersede a smaller fishing batch without reporting unused fishing credit')
 x.playing_cards={};local _,_,missing=G.suggest(x,modules,anchor)
 check(missing.death_fishing.reason=='public_population_unavailable' and not missing.death_fishing.attempted,'missing population is explicit rather than missing telemetry')
 x=fishing();x.blind.chips=999999;local p=Q.score(x,{1});p.indices={1}
 local _,_,unsafe=G.suggest(x,modules,p)
 check(unsafe.death_fishing.status=='not_admitted' and not unsafe.death_fishing.attempted,'unsafe retained clear has explicit rejected disposition')
 x=fishing();local _,_,limited=G.suggest(x,modules,anchor,{max_evaluations=0})
 check(limited.death_fishing.status=='not_admitted' and not limited.death_fishing.complete,'zero allowance cannot report completed comparison')
end
print('advisor_death_receipts404: '..checks..' checks passed')

do
 local J=dofile('Brainstorm/Advisor/player_journal.lua')
 for _,replacement in ipairs({{kind='reorder_jokers',area='jokers',order={1}},
     {kind='discard',area='hand',indices={2}}}) do
  local altered={};for k,v in pairs(modules) do altered[k]=v end
  altered.phase_copy={apply=function(_,_,r)r.action=clone(replacement);r.growth=nil;return r end}
  local r=D.run(receipt_fishing(),altered,nil,{search={fast_clear=true}})
  local f=J.compact_copy_death_review(r).fishing
  check(f.proposal_selected and not f.selected and f.status=='superseded' and f.reason=='final_action_changed','overridden fishing proposal is not reported as selected')
  check(f.distribution_comparisons>0 and not f.final_action_matches_proposal,'proposal evidence survives different physical final action')
 end
 local r=D.run(receipt_fishing(),modules,nil,{search={fast_clear=true},retry={unavailable=true}})
 local f=J.compact_copy_death_review(r).fishing
 check(not r.action and f.proposal_selected and not f.selected and f.reason=='final_action_unavailable','retry suppression cannot publish selected fishing')
end
print('advisor_death_arbitration404: '..checks..' checks passed')
