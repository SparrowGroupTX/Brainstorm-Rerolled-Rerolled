local O=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local cases=4096
local pairs_,patterns={},{}
for seed=1,cases do
  local priorities={};local pattern=0
  for id=1,4 do
    priorities[id]={id=id,roll=O.roll(seed,1,'hook',id)}
    if O.roll(seed,1,'glass',id)<.5 then pattern=pattern+2^(id-1) end
  end
  table.sort(priorities,function(a,b) return a.roll<b.roll end)
  local a,b=priorities[1].id,priorities[2].id;if a>b then a,b=b,a end
  local key=a..','..b;pairs_[key]=(pairs_[key] or 0)+1
  patterns[pattern]=(patterns[pattern] or 0)+1
end
for a=1,3 do for b=a+1,4 do
  local count=pairs_[a..','..b] or 0
  check(count>540 and count<830,'Hook pair coverage/frequency '..a..','..b..' = '..count)
end end
for pattern=0,15 do
  local count=patterns[pattern] or 0
  check(count>150 and count<370,'Glass joint pattern coverage '..pattern..' = '..count)
end
for _,id in ipairs({1,9,100,'advisor-dna:13:1','advisor-copy:12:2'}) do
  local a=O.roll(12345,4,'glass',id)
  check(a==O.roll(12345,4,'glass',id),'determinism')
  check(a>=0 and a<1,'unit interval')
  check(a~=O.roll(12345,4,'hook',id),'channel separation')
  check(a~=O.roll(12345,5,'glass',id),'turn separation')
end
-- Portable known answers also guard 32-bit signedness and multiplication on
-- runtimes with native bit helpers. Constants independently generated in Python.
local vectors={
  {1,1,'hook',1,0.073714538244530559},
  {2147483646,4,'glass','advisor-dna:13:1',0.063395127886906266},
  {19491001,0,'visibility',52,0.2474850753787905},
}
-- Pair/joint checks are deterministic regression screens, not proof of
-- statistical independence or qualified episode evidence.
for _,v in ipairs(vectors) do
  check(O.roll(v[1],v[2],v[3],v[4])==v[5],'portable known-answer vector')
end
local original_bit,original_bit32=rawget(_G,'bit'),rawget(_G,'bit32')
_G.bit=nil;_G.bit32=nil
local portable=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
_G.bit=original_bit;_G.bit32=original_bit32
for _,v in ipairs(vectors) do
  check(portable.roll(v[1],v[2],v[3],v[4])==v[5],'fallback known-answer vector')
end
for seed=1,128 do for id=1,6 do
  check(portable.roll(seed,2,'glass',id)==O.roll(seed,2,'glass',id),'native/fallback parity')
end end
local count=0;local actual_roll=O.roll
O.roll=function(...) count=count+1;return actual_roll(...) end
local cards={}
for i=1,52 do cards[i]={id=i,rank=2,enhancement='c_base',ability={},face_down=true} end
local s={hand={cards[1],cards[2]},hand_size=3,blind={},probabilities={normal=1}}
O.context(s,{1},10,1);check(count==0,'ordinary context requires no Glass hashes')
local D=dofile('Brainstorm/Advisor/draws.lua')
assert(O.fill(s,cards,{},D,10,1));check(count==0,'ordinary draw requires no visibility hashes')
s.blind={key='bl_wheel'}
assert(O.fill(s,cards,{},D,10,1));check(count==1,'Wheel hashes only one drawn card')
s.hand_size=2;assert(O.fill(s,cards,{},D,10,1));check(count==1,'zero draw requires no hashes')
cards[1].enhancement='m_glass';O.context(s,{1},10,1);check(count==2,'Glass only hashes actual source Glass')
cards[1].debuff=true;O.context(s,{1},10,1);check(count==2,'debuffed Glass cannot shatter')
cards[1].debuff=false;cards[1].enhancement=nil;cards[1].ability.effect='Glass Card'
O.context(s,{1},10,1);check(count==3,'live Glass effect alias requests outcome')
O.roll=actual_roll
print('outcome primitive distribution: '..cases..' seeds / '..checks..' checks passed')
