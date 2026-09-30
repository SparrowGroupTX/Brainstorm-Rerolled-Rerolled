local F={}
local p=ADVISOR416_ROOT or 'Brainstorm/Advisor/'
function F.copy(v)if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=F.copy(x) end;return r end
function F.card(id,rank,suit,key)
 key=key or 'c_base'
 local names={c_base='Default Base',m_mult='Mult',m_steel='Steel Card',m_glass='Glass Card'}
 local effects={c_base='Base',m_mult='Mult Card',m_steel='Steel Card',m_glass='Glass Card'}
 local nominal=rank==14 and 11 or math.min(rank,10)
 return {id=id,rank=rank,suit=suit or 'Clubs',nominal=nominal,base={id=rank,nominal=nominal},
  key=key,name=names[key],enhancement=key,debuff=false,face_down=false,
  ability={name=names[key],set=key=='c_base' and 'Default' or 'Enhanced',effect=effects[key],
   bonus=0,mult=key=='m_mult' and 4 or 0,x_mult=key=='m_glass' and 2 or 1,
   extra=key=='m_glass' and 4 or nil,h_mult=0,h_x_mult=key=='m_steel' and 1.5 or 0,
   h_dollars=0,p_dollars=0,t_mult=0,t_chips=0}}
end
function F.joker(key,name,a)
 local ability={name=name,set='Joker',effect='',mult=0,x_mult=1,bonus=0,t_chips=0,t_mult=0,
  h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,h_size=0,d_size=0}
 for k,v in pairs(a or {}) do ability[k]=v end
 if key=='j_green_joker' then ability.effect=nil end
 return {key=key,id=key,ability=ability,blueprint_compat=true,debuff=false,sell_cost=2}
end
function F.state()
 local s={phase='hand',teacher_profile='perkeo_yorick_win_v1',ante=3,win_ante=8,
  hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},hand_size=7,hand_limit=5,
  hands_left=3,hands_played=0,discards_left=3,discards_used=0,chips=0,dollars=30,
  current_round={},modifiers={},probabilities={normal=1},consumable_limit=2,joker_limit=5,
  blind={key='bl_big',name='Big Blind',chips=500}}
 for i,r in ipairs({14,12,2,4,6,8,9}) do s.hand[i]=F.card('h'..i,r,({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1]) end
 for i,r in ipairs({3,5,7,9,10,11,12,13,14,2,4,6}) do s.deck[i]=F.card('d'..i,r,'Hearts') end
 F.population(s);return s
end
function F.population(s)
 s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=F.copy(c) end end
end
function F.modules()
 local names={'scoring','search','growth','strategy','snapshot','concealed_belief','draws',
  'consumables','acorn_belief','acorn_ordering','acorn_discard','decision'}
 local m={};for _,name in ipairs(names) do m[name]=dofile(p..name..'.lua') end
 return m
end
return F
