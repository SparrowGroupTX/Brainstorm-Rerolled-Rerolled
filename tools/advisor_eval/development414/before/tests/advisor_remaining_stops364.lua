-- Manufactured public populations; no captured policy or game evaluation.
local p='Brainstorm/Advisor/'
local O=dofile(p..'acorn_ordering.lua')
local B=dofile(p..'acorn_belief.lua')
local C=dofile(p..'concealed_belief.lua')
local S=dofile(p..'scoring.lua')
local F=dofile(p..'snapshot.lua').fingerprint
local checks=0
local function check(v,m) checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function forbidden()error('Unqualified fallback or RNG')end
local function card(i) return {id='card:'..i,rank=2+(i-1)%13,nominal=math.min(10,2+(i-1)%13),
 suit=({'Clubs','Hearts','Spades','Diamonds'})[math.floor((i-1)/13)+1],enhancement='c_base',ability={}}end
local function state(n,hidden)
 local s={phase='hand',hands_left=1,discards_left=0,hand={},deck={},playing_cards={},hands={},
 jokers={},consumeables={},chips=0,dollars=10,blind={key=hidden and 'bl_fish' or 'bl_final_acorn',chips=1e9},
 probabilities={normal=1},hand_size=n,hand_limit=5,modifiers={}}
 for i=1,52 do local c=card(i);c.face_down=hidden and i%2==0 or false
  s.playing_cards[i]=c;if i<=n then s.hand[i]=c else s.deck[#s.deck+1]=c end
 end
 return s
end
local b=assert(B.start({{key='j_joker',ability={name='Joker',mult=4}},
 {key='j_cavendish',ability={name='Cavendish',extra={Xmult=3}}}},'remaining364',{public_before_shuffle=true}))
local function oracle(n)
 local out={};for mask=1,2^n-1 do local indices={}
  for i=1,n do if math.floor(mask/2^(i-1))%2==1 then indices[#indices+1]=i end end
  if #indices<=5 then out[table.concat(indices,',')]=true end
 end;return out
end
local old=math.random;math.random=forbidden
for n=10,12 do
 local s=state(n);local seen,calls={},0;local original=F(s)
 local scorer={score=function(t,indices)
  calls=calls+1;local world=t.jokers[1].key
  seen[world]=seen[world] or {};local key=table.concat(indices,',')
  check(not seen[world][key],'Acorn cell unique');seen[world][key]=true
  return {score=1,legal=true}
 end}
 local size=({[10]=637,[11]=1023,[12]=1585})[n]
 local a,used,d=O.suggest(s,b,scorer,B,{max_evaluations=size*2,max_order_evaluations=0})
 check(a and d.complete,'Large Acorn comparison complete');eq(used,size*2,'Acorn complete call count')
 eq(calls,used,'Actual calls charged');eq(F(s),original,'Input unchanged')
 for _,key in ipairs({'j_joker','j_cavendish'})do for subset in pairs(oracle(n))do
  check(seen[key][subset],'Independent oracle includes every world/subset')
 end end
 eq(O.suggest(s,b,{score=forbidden},B,{max_evaluations=size*2-1}),nil,'Incomplete cap never starts')
end
for _,n in ipairs({11,12})do
 local s=state(n,true);local original=F(s);local calls,worlds=0,{}
 local samples=n==11 and 7 or 5;local size=n==11 and 1023 or 1585
 local r=C.run(s,{lower_bound=function(t,indices)
  calls=calls+1;worlds[t]=worlds[t] or {};local key=table.concat(indices,',')
  check(not worlds[t][key],'Concealed cell unique');worlds[t][key]=true
  eq(#t.playing_cards,52,'Population conserved');eq(#t.hand,n,'Hand conserved')
  return {score=1,legal=true,reliable_bound=true}
 end})
 check(r.action~=nil,'Large concealed immediate action available');eq(calls,samples*size,'Complete default call count')
 eq(r.evaluations,calls,'All calls charged');check(calls<=8000,'Existing cap respected')
 local count=0;for _,family in pairs(worlds)do count=count+1;for subset in pairs(oracle(n))do
  check(family[subset],'Same complete candidate family in every world')
 end end;eq(count,samples,'Common world count exact');eq(F(s),original,'No hidden population mutations')
 eq(C.run(s,{lower_bound=forbidden},{samples=16}).kind,'unsupported','Oversized explicit sample request rejected intact')
end
-- Immediate score equality does not claim held/reward utility or future inventory.
local s=state(1);s.hand[1]=card(13);s.playing_cards={s.hand[1]};s.deck={}
local plain=assert(O.suggest(s,b,S,B,{max_order_evaluations=0}))
for _,mode in ipairs({'m_gold','Blue','Purple','Gold'})do
 s.hand[1].enhancement=mode=='m_gold' and mode or 'c_base';s.hand[1].seal=mode~='m_gold' and mode or nil
 local before=F(s);local a,_,d=O.suggest(s,b,S,B,{max_order_evaluations=0})
 check(a~=nil,'Standard reward card admits immediate comparison: '..mode)
 eq(a.minimum_score,plain.minimum_score,'Reward does not invent score: '..mode)
 eq(F(s),before,'No cash or inventory reward invented: '..mode)
 if mode~='Gold' then check(d.unplanned_rewards,'Future reward limitation explicit') end
end
s.hand[1].seal='Unknown';eq(O.suggest(s,b,{score=forbidden},B),nil,'Unknown seal still rejected')
local big=state(13,true);eq(C.run(big,{lower_bound=forbidden}).kind,'unsupported','Unsupported larger family remains explicit')
math.random=old
print('advisor_remaining_stops364: '..checks..' checks passed')
