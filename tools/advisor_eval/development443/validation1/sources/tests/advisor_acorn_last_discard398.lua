-- Independently manufactured final-hand Acorn survival and boundary fixtures.
local p='Brainstorm/Advisor/'
local B=dofile(p..'acorn_belief.lua')
local O=dofile(p..'acorn_ordering.lua')
local R=dofile(p..'acorn_discard.lua')
local D=dofile(p..'decision.lua')
local S=dofile(p..'scoring.lua')
local Draws=dofile(p..'draws.lua')
local Snapshot=dofile(p..'snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) checks=checks+1;assert(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank)
  return {id=id,rank=rank,nominal=math.min(rank,10),suit='Clubs',enhancement='c_base',
    ability={},face_down=false}
end
local function joker(key,name,ability)
  ability.name=name;return {key=key,ability=ability,blueprint_compat=true}
end
local function hidden_joker()
  return setmetatable({face_down=true}, {__index=function()error('A concealed Joker payload was read')end})
end
local function fixture(target)
  local b=assert(B.start({joker('j_yorick','Yorick',{x_mult=1,yorick_discards=5,
      extra={discards=5,xmult=1}}),joker('j_joker','Joker',{mult=4})},
    'manufactured-acorn',{public_before_shuffle=true}))
  local s={phase='hand',hand={},deck={},playing_cards={},jokers={hidden_joker(),hidden_joker()},
    public_joker_belief=b,hands_left=1,discards_left=3,discards_used=0,hand_limit=5,
    hand_size=5,chips=0,dollars=20,blind={key='bl_final_acorn',name='Amber Acorn',chips=target},
    hands={},consumeables={},consumable_limit=2,modifiers={},probabilities={normal=1}}
  for i=1,5 do
    s.hand[i]=card('public-held:'..i,i*2)
    s.hand[i].suit=({'Hearts','Spades','Diamonds','Clubs','Hearts'})[i]
    s.deck[i]=card('public-deck:'..i,10)
    s.playing_cards[#s.playing_cards+1]=Snapshot.copy(s.hand[i])
    s.playing_cards[#s.playing_cards+1]=Snapshot.copy(s.deck[i])
  end
  return s
end
local function modules(raw)
  return {acorn_belief=B,acorn_ordering=O,acorn_discard=R,scoring=raw or S,
    draws=Draws,concealed_belief={public_candidates=dofile(p..'concealed_belief.lua').public_candidates}}
end
local s=fixture(1000);local frozen=Snapshot.fingerprint(s)
local scored=0;local observed_growth=0
local watched=setmetatable({
  lower_bound=function(state,indices)
    scored=scored+1;return S.lower_bound(state,indices)
  end,
  score=function(state,indices)
    scored=scored+1;return S.score(state,indices)
  end,
  after_discard=function(state,indices)
    local after,effects=S.after_discard(state,indices)
    if after and #indices==5 then
      observed_growth=observed_growth+1
      for _,j in ipairs(after.jokers) do if j.key=='j_yorick' then
        eq(j.ability.x_mult,2,'Five discarded cards trigger physical Yorick growth')
      end end
    end
    return after,effects
  end,
},{__index=S})
local rescued=D.run(s,modules(watched))
eq(rescued.action.kind,'discard','A complete final-hand redraw beats certain failure')
check(rescued.acorn_discard_diagnostics.complete,'Complete declared redraw family')
eq(rescued.acorn_discard_diagnostics.worlds,2,'Every public Joker world included')
eq(rescued.acorn_discard_diagnostics.samples,24,'All common draws included')
eq(rescued.acorn_discard_diagnostics.play_family,'all_legal_subsets','Small complete play family')
check(rescued.sampled_clear_fraction>rescued.baseline_clear_fraction,'Supported redraw improvement')
eq(rescued.evaluations,scored,'Every score call charged once')
check(rescued.evaluations<=140000,'Ordinary score cap retained')
check(observed_growth>0,'Discard forecast uses exact Yorick transition')
eq(Snapshot.fingerprint(s),frozen,'Input and concealed row unchanged')
local repeat_result=D.run(s,modules())
eq(Snapshot.fingerprint(repeat_result.action),Snapshot.fingerprint(rescued.action),'Deterministic advice')

-- Physical deck order and private ID spelling do not affect a mixed deck's
-- sampled action. This does not grant access to the actual next card.
local mixed=fixture(1000)
for i,rank in ipairs({2,3,10,11,13}) do
  mixed.deck[i].rank=rank;mixed.deck[i].nominal=math.min(rank,10)
  mixed.playing_cards[2*i].rank=rank;mixed.playing_cards[2*i].nominal=math.min(rank,10)
end
local mixed_result=D.run(mixed,modules())
local permuted=fixture(1000)
for i,rank in ipairs({2,3,10,11,13}) do
  permuted.deck[i].rank=rank;permuted.deck[i].nominal=math.min(rank,10)
  permuted.playing_cards[2*i].rank=rank;permuted.playing_cards[2*i].nominal=math.min(rank,10)
end
for i=1,math.floor(#permuted.deck/2) do
  local j=#permuted.deck+1-i;permuted.deck[i],permuted.deck[j]=permuted.deck[j],permuted.deck[i]
end
for _,area in ipairs({permuted.hand,permuted.deck,permuted.playing_cards}) do
  for _,c in ipairs(area) do c.id='renamed:'..c.id end
end
local changed=D.run(permuted,modules())
eq(Snapshot.fingerprint(changed.action),Snapshot.fingerprint(mixed_result.action),'No physical order or ID oracle')
eq(changed.sampled_clear_fraction,mixed_result.sampled_clear_fraction,'Mixed common draws independent of IDs')

-- A guaranteed current clear remains preferable to spending a discard.
local already=D.run(fixture(10),modules())
eq(already.action.kind,'play','Do not redraw an all-world clear')
eq(already.acorn_discard_diagnostics,nil,'No speculative redraw after all-world clear')

-- Incomplete allowance and unsupported Purple generation preserve the fixed play.
local low=D.run(s,modules(),nil,{acorn_discard={max_evaluations=2}})
eq(low.action.kind,'play','Insufficient complete redraw budget falls back')
check(not low.acorn_diagnostics.discard.complete,'Budget does not publish a partial comparison')
local purple=fixture(1000)
for _,c in ipairs(purple.hand) do c.seal='Purple' end
local unsupported=D.run(purple,modules())
eq(unsupported.action.kind,'play','Unsupported Tarot generation does not force a discard')
check(not unsupported.acorn_diagnostics.discard.complete,'Unsupported branch remains incomplete')
local one_purple=fixture(1000);one_purple.hand[1].seal='Purple'
local safe_purple=D.run(one_purple,modules())
check(safe_purple.acorn_diagnostics.discard.complete,'Supported non-Purple family is still compared')
if safe_purple.action.kind=='discard' then
  for _,index in ipairs(safe_purple.action.indices) do check(index~=1,'No unsupported Purple generation') end
end
local concealed=fixture(1000);concealed.hand[1].face_down=true
local rejected=D.run(concealed,modules())
check(rejected.action==nil or rejected.action.kind~='discard','No private card identity enters Acorn redraw')
local outside=fixture(1000)
local unseen=card('concealed-outside',14);unseen.face_down=true
outside.playing_cards[#outside.playing_cards+1]=unseen
local refused=D.run(outside,modules())
eq(refused.action.kind,'play','Unobserved discarded composition cannot seed the redraw')
check(not refused.acorn_diagnostics.discard.complete,'Hidden outside population remains unsupported')
local calls=0
local late=setmetatable({lower_bound=function(state,indices)
  calls=calls+1
  if calls>12 then return {score=0,uncertain=true,reliable_bound=false,warnings={'Manufactured unsupported floor'}} end
  return S.lower_bound(state,indices)
end},{__index=S})
local incomplete=D.run(fixture(1000),modules(late))
eq(incomplete.action.kind,'play','Later unsupported score does not publish a partial discard')
check(not incomplete.acorn_diagnostics.discard.complete,'Incomplete family remains marked')
check(incomplete.evaluations<=140000,'Even failed comparisons are charged')

-- The exact discard transition must agree with the certified public ability
-- transition in every order; malformed resource shapes cannot enter a redraw.
local divergent=setmetatable({after_discard=function(state,indices)
  local after,effects=S.after_discard(state,indices)
  if after then for _,j in ipairs(after.jokers) do if j.key=='j_yorick' then
    j.ability.x_mult=j.ability.x_mult+1
  end end end
  return after,effects
end},{__index=S})
local rejected_transition=D.run(fixture(1000),modules(divergent))
eq(rejected_transition.action.kind,'play','Public ability mismatch keeps the complete immediate play')
check(not rejected_transition.acorn_diagnostics.discard.complete,'Divergent transition is not published')
local malformed=fixture(1000);malformed.hand_size='five'
local rejected_size=D.run(malformed,modules())
eq(rejected_size.action.kind,'play','Non-numeric future hand size keeps the immediate play')
check(not rejected_size.acorn_diagnostics.discard.complete,'Malformed prospective resource is rejected')

-- When no last-hand play clears all worlds, choose the action with greater
-- complete public-world clearing opportunity before maximizing the minimum.
local rank_state=fixture(100)
rank_state.hand={rank_state.hand[1],rank_state.hand[2]};rank_state.deck={}
local alt_b=assert(B.start({joker('j_joker','Joker',{mult=4}),
  joker('j_cavendish','Cavendish',{extra={Xmult=3}})},'rank',{public_before_shuffle=true}))
rank_state.public_joker_belief=alt_b;rank_state.jokers={hidden_joker(),hidden_joker()}
local fake={score=function(world,indices)
  local key=table.concat(indices,',');local score
  if key=='1' then score=world.jokers[1].key=='j_joker' and 120 or 0
  elseif key=='2' then score=50 else score=30 end
  return {score=score,legal=true,uncertain=false,warnings={}}
end}
local chance,_,diag=O.suggest(rank_state,alt_b,fake,B,{max_evaluations=6,max_order_evaluations=0})
eq(table.concat(chance.action.indices,','),'1','Last-hand ranking favors a possible clear')
eq(diag.final_hand_clear_fraction,0.5,'All public orders counted')
rank_state.hands_left=2
local conservative=O.suggest(rank_state,alt_b,fake,B,{max_evaluations=6,max_order_evaluations=0})
eq(table.concat(conservative.action.indices,','),'2','Earlier-hand conservative ranking remains')
-- Five distinct public Jokers produce all 120 orders. The ordinary budget
-- must hold the complete bounded draw/play family, not a winning prefix.
local many=fixture(1000000000)
for i=6,8 do
  local c=card('public-held:'..i,i+3);c.suit=({'Spades','Hearts','Diamonds'})[i-5]
  many.hand[#many.hand+1]=c;many.playing_cards[#many.playing_cards+1]=Snapshot.copy(c)
end
for i=6,17 do
  local c=card('public-deck:'..i,10)
  many.deck[#many.deck+1]=c;many.playing_cards[#many.playing_cards+1]=Snapshot.copy(c)
end
many.hand_size=8
many.public_joker_belief=assert(B.start({
  joker('j_yorick','Yorick',{x_mult=1,yorick_discards=5,extra={discards=5,xmult=1}}),
  joker('j_joker','Joker',{mult=4}),joker('j_cavendish','Cavendish',{extra={Xmult=3}}),
  joker('j_perkeo','Perkeo',{}),joker('j_blueprint','Blueprint',{}),
},'manufactured-120',{public_before_shuffle=true}))
many.jokers={hidden_joker(),hidden_joker(),hidden_joker(),hidden_joker(),hidden_joker()}
local start=os.clock();local bounded=D.run(many,modules());local elapsed=os.clock()-start
eq(#many.public_joker_belief.worlds,120,'Complete five-Joker permutation family')
check(bounded.acorn_diagnostics.discard.complete,'All 120 orders complete each sampled branch')
eq(bounded.acorn_diagnostics.discard.play_family,'bounded_public_rank_suit_subsets','Large family declared before comparison')
check(bounded.evaluations<=140000,'No ordinary budget enlargement at 120 orders')
print('manufactured 120-order Acorn comparison CPU seconds: '..string.format('%.2f',elapsed))
print('advisor_acorn_last_discard398: '..checks..' checks passed')
