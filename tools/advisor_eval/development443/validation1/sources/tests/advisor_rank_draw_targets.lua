local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function c(id,rank,suit) return {id=id,rank=rank,nominal=math.min(rank,10),suit=suit or 'Clubs',key='c_base',enhancement='c_base',ability={}} end
local function state()
  local s={phase='hand',hand={},deck={},jokers={},consumeables={},playing_cards={},hand_limit=5,hand_size=8,
    ante=3,hands_left=2,discards_left=1,dollars=10,chips=0,blind={key='bl_small',chips=15000},
    current_round={},modifiers={},probabilities={normal=1},hands={['Four of a Kind']={level=12,chips=390,mult=40,l_chips=30,l_mult=3,played=3}}}
  for i,r in ipairs({10,10,10,4,4,6,6,14}) do s.hand[i]=c('h'..i,r,({'Clubs','Diamonds','Hearts','Spades'})[(i-1)%4+1]) end
  for i,r in ipairs({4,4,4,4,4,4,4,4,2,3,5,7,8,9,11,12}) do s.deck[i]=c('d'..i,r,({'Clubs','Diamonds','Hearts','Spades'})[(i-1)%4+1]);s.deck[i].face_down=true end
  for _,area in ipairs({s.hand,s.deck}) do for _,v in ipairs(area) do s.playing_cards[#s.playing_cards+1]=v end end
  return s
end
local function target(s,family,rank)
  for _,v in ipairs(Search.draw_targets(s)) do if v.category==family and v.pattern.rank==rank then return v end end
end
local function exhaustive(s,t)
  local count,total,good=0,0,0
  local retained=0;local removed={};for _,i in ipairs(t.indices) do removed[i]=true end
  for i,c in ipairs(s.hand) do if not removed[i] and c.rank==t.pattern.rank and c.enhancement~='m_stone' then retained=retained+1 end end
  local draws=math.min(#s.deck,s.hand_size-(#s.hand-#t.indices))
  if s.blind.key=='bl_serpent' then draws=math.min(#s.deck,3) end
  local function walk(start,left)
    if left==0 then total=total+1;if count+retained>=t.pattern.required then good=good+1 end;return end
    for i=start,#s.deck-left+1 do
      local plus=s.deck[i].rank==t.pattern.rank and s.deck[i].enhancement~='m_stone' and 1 or 0
      count=count+plus;walk(i+1,left-1);count=count-plus
    end
  end
  walk(1,draws);return good/total
end
do
  local s=state();local before=Snapshot.fingerprint(s);local t=target(s,'Four of a Kind',4)
  check(t~=nil,'upgraded pair with developed remaining rank is represented')
  check(not target(s,'Four of a Kind',10),'exhausted held triplet is not a completion target')
  check(math.abs(t.completion_probability-exhaustive(s,t))<1e-12,'four-kind tail matches exhaustive distinct-card draws')
  s.hands['Five of a Kind']={level=4,chips=225,mult=21}
  local five=target(s,'Five of a Kind',4)
  check(five and math.abs(five.completion_probability-exhaustive(s,five))<1e-12,'five-kind needs three more matching ranks')
  check(five.completion_probability<t.completion_probability,'five-kind cannot borrow four-kind completion chance')
  s.hands['Five of a Kind']=nil;check(Snapshot.fingerprint(s)==before,'shortlist preserves whole population and input')
  local reversed=Snapshot.copy(s);for i=1,math.floor(#reversed.deck/2) do local j=#reversed.deck-i+1;reversed.deck[i],reversed.deck[j]=reversed.deck[j],reversed.deck[i] end
  check(Snapshot.fingerprint(Search.draw_targets(s))==Snapshot.fingerprint(Search.draw_targets(reversed)),'hidden deck order does not change target')
  s.blind.key='bl_serpent';t=target(s,'Four of a Kind',4)
  check(t and math.abs(t.completion_probability-exhaustive(s,t))<1e-12,'Serpent uses only three draws')
  s.hand[4].ability.forced_selection=true
  for _,v in ipairs(Search.draw_targets(s)) do local found=false;for _,i in ipairs(v.indices) do if i==4 then found=true end end;check(found,'Bell forced card must be discarded') end
end
do
  for _,change in ipairs({function(s)s.hands['Four of a Kind'].level=1 end,function(s)s.jokers={{key='j_perkeo'}}end,
    function(s)s.used_vouchers={v_observatory=true}end,function(s)s.vouchers={v_observatory=true}end,
    function(s)s.deck[1].unknown=true end,function(s)s.hand[1].face_down=true end}) do
    local s=state();change(s);check(#Search.draw_targets(s)==0,'unsupported engine or unupgraded family retains old shortlist')
  end
  local s=state();for i=1,8 do s.deck[i].enhancement='m_stone' end
  check(not target(s,'Four of a Kind',4),'Stone cards have no rank completion identity')
end
do
  local s=state();local before=Snapshot.fingerprint(s)
  local old=Search.run(s,Score,{samples=12,resource_samples=0,draw_targets=false,fast_clear=false,draws=Draws})
  local new=Search.run(s,Score,{samples=12,resource_samples=0,fast_clear=false,draws=Draws})
  check(new.discard and not new.truncated and new.evaluations<=140000,'complete comparison respects existing cap')
  check(old.discard and new.discard.mean>old.discard.mean,'developed rank improves the matched sampled redraw mean')
  check(new.search_diagnostics.discard_candidates==old.search_diagnostics.discard_candidates,'target replaces an existing slot')
  local found=false;for _,t in ipairs(new.search_diagnostics.upgraded_draw_targets or {}) do if t.category=='Four of a Kind' then found=true end end
  check(found,'rank candidate enters real shared scoring comparison')
  check(Snapshot.fingerprint(s)==before,'scoring preserves source state')
  local repeated=Search.run(s,Score,{samples=12,resource_samples=0,fast_clear=false,draws=Draws})
  check(Snapshot.fingerprint(new)==Snapshot.fingerprint(repeated),'complete comparison is deterministic')
  print('rank comparison old '..tostring(old.discard and old.discard.mean)..' new '..tostring(new.discard and new.discard.mean)..' evaluations '..new.evaluations)
end
print('advisor_rank_draw_targets: '..checks..' checks passed')
