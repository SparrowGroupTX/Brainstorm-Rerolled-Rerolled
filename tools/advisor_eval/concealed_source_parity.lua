local B=dofile(PROBE_MODULE)
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(math.abs(a-b)<1e-10,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local names={bl_small='Small Blind',bl_house='The House',bl_fish='The Fish',bl_wheel='The Wheel',bl_mark='The Mark'}
local wheel_roll,flip_roll=0,0
function pseudoseed(key) return key end
function pseudorandom(key) return key=='wheel' and wheel_roll or flip_roll end
-- 14 independent Wheel cells and six challenge cells integrate the exact
-- rational thresholds here. Mark's Stone get_id returns random negatives,
-- whose magnitude is immaterial; this RNG is confined to the source worker.
for _,key in ipairs({'bl_small','bl_house','bl_fish','bl_wheel','bl_mark'}) do
  for _,flip in ipairs({0,2,3}) do for _,rank in ipairs({2,11,13,14}) do
    for _,stone in ipairs({false,true}) do for _,pareidolia in ipairs({false,true}) do
      cases=cases+1
      local s={blind={key=key,name=names[key],prepped=true},hands_played=0,discards_used=0,
        jokers=pareidolia and {{key='j_pareidolia',ability={name='Pareidolia'}}} or {},
        consumeables={},modifiers=flip>0 and {flipped_cards=flip} or {},probabilities={normal=2}}
      local card=setmetatable({base={id=rank},ability={effect=stone and 'Stone Card' or 'Base'},
        rank=rank,suit='Spades',enhancement=stone and 'm_stone' or 'c_base'}, {__index=Card})
      G={hand={cards={},config={card_limit=8}},deck={},jokers={cards=s.jokers},consumeables={cards={}},
        GAME={modifiers=s.modifiers,probabilities=s.probabilities,current_round={hands_played=0,discards_used=0}}}
      G.GAME.blind=setmetatable(s.blind,{__index=Blind})
      local hidden=0
      function G.hand:emplace(_,_,stay_flipped) if stay_flipped then hidden=hidden+1 end end
      local from={is=function()return true end,remove_card=function()return card end}
      for wheel=1,14 do for challenge=1,6 do
        wheel_roll=(wheel-.5)/14;flip_roll=(challenge-.5)/6
        assert(CardArea.draw_card_from(G.hand,from))
      end end
      local weight=B.hidden_weight(s,card)
      if key=='bl_small' and flip==0 then assert(weight==nil);checks=checks+1
      else eq(weight,hidden/84,key..' conditioning likelihood') end
    end end
  end end
end
print('concealed source parity: '..cases..' cases, '..checks..' comparisons')
