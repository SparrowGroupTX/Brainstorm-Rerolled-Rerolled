-- Invented cards/rows only; canonical source-shaped fields are not run snapshots.
local F=dofile('tests/fixtures/repair416.lua');local R={copy=F.copy,joker=F.joker,modules=F.modules,population=F.population}
function R.card(id,r,suit,key)
 local c=F.card(id,r,suit,key)
 if key=='m_bonus' then c.name='Bonus';c.ability.name='Bonus';c.ability.effect='Bonus Card';c.ability.bonus=30 end
 if key=='m_gold' then c.name='Gold Card';c.ability.name='Gold Card';c.ability.effect='Gold Card';c.ability.h_dollars=3 end
 if key=='m_wild' then c.name='Wild Card';c.ability.name='Wild Card';c.ability.effect='Wild Card' end
 return c
end
function R.j(key)
 local shapes={j_flower_pot={'Flower Pot',{extra=3}},j_even_steven={'Even Steven',{extra=4,effect='Even Card Buff'}},
  j_greedy_joker={'Greedy Joker',{extra={s_mult=3,suit='Diamonds'},effect='Suit Mult'}},
  j_hanging_chad={'Hanging Chad',{extra=2}},j_ice_cream={'Ice Cream',{extra={chips=85,chip_mod=5}}},
  j_fortune_teller={'Fortune Teller',{extra=1}},j_devious={'Devious Joker',{type='Straight',t_chips=100}},
  j_card_sharp={'Card Sharp',{extra={Xmult=3}}},j_yorick={'Yorick',{x_mult=4,yorick_discards=23,extra={discards=23,xmult=1}}},
  j_blueprint={'Blueprint',{effect='Copycat'}},j_brainstorm={'Brainstorm',{effect='Copycat'}},j_perkeo={'Perkeo',{}}}
 local spec=assert(shapes[key],key);local j=F.joker(key,spec[1],F.copy(spec[2]))
 if key=='j_ice_cream' or key=='j_devious' or key=='j_card_sharp' then j.ability.effect=nil end
 if key=='j_fortune_teller' then j.edition={negative=true,type='negative'} end
 return j
end
function R.state(chad)
 local s=F.state();s.hand_size=8;s.hand={};s.blind={key='bl_psychic',name='The Psychic',chips=3000}
 local ranks=chad and {13,13,3,3,7,2,6,9} or {13,12,11,10,9,2,4,6}
 for i,r in ipairs(ranks) do s.hand[i]=R.card('made:'..i,r,({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],i==1 and 'm_mult' or 'c_base') end
 s.jokers=chad and {R.j('j_yorick'),R.j('j_hanging_chad'),R.j('j_ice_cream')} or
  {R.j('j_yorick'),R.j('j_flower_pot'),R.j('j_even_steven'),R.j('j_greedy_joker')}
 s.consumeable_usage_total={tarot=4};R.population(s);return s
end
function R.clear(m,s,indices)local c=m.scoring.score(s,indices or {1,2,3,4,5});c.indices=indices or {1,2,3,4,5};return c end
function R.permutations(indices,callback)
 local a={};local used={}
 local function visit()
  if #a==#indices then callback(a);return end
  for _,i in ipairs(indices) do if not used[i] then used[i]=true;a[#a+1]=i;visit();a[#a]=nil;used[i]=nil end end
 end
 visit()
end
return R
