local Paired=dofile('Brainstorm/Advisor/paired_deck.lua')
local checks=0
local function check(x,s) checks=checks+1;assert(x,s) end
local root={};for i=1,12 do root[i]={id='card:'..i,rank=i+1} end
local ctx=Paired.new(root)
local old_random=math.random;math.random=function() error('Game RNG used') end
local changed={}
for i=#root,1,-1 do if i~=3 then changed[#changed+1]={id=root[i].id,rank=14} end end
changed[#changed+1]={id='created:1',rank=9}
changed[#changed+1]={id='created:2',rank=9}
for sample=1,4 do
  local expected={}
  for _,i in ipairs(ctx:sample(root,sample,true)) do if i~=3 then expected[#expected+1]=root[i].id end end
  local actual,seen={},{}
  local draw=ctx:sample(changed,sample)
  for _,i in ipairs(draw) do
    local id=changed[i].id;check(not seen[id],'Every surviving/new card is sampled once');seen[id]=true
    if id:sub(1,5)=='card:' then actual[#actual+1]=id end
  end
  check(table.concat(actual,',')==table.concat(expected,','),'Rank changes and removal preserve common surviving order')
  check(#draw==13 and seen['created:1'] and seen['created:2'] and not seen['card:3'],'Population is conserved after exact removal/addition')
  check(table.concat(draw,',')==table.concat(Paired.new(root):sample(changed,sample),','),'Independent samples are deterministic')
  local reversed={};for i=#changed,1,-1 do reversed[#reversed+1]=changed[i] end
  local physical,other={},{}
  for _,i in ipairs(draw) do physical[#physical+1]=changed[i].id end
  for _,i in ipairs(ctx:sample(reversed,sample)) do other[#other+1]=reversed[i].id end
  check(table.concat(physical,',')==table.concat(other,','),'Current population input order cannot change the physical sample')
end
local absent,why=ctx:sample({{rank=2}},1)
check(not absent and why:find('identities'),'Missing identities fail closed')
check(not ctx:sample({{id='same'},{id='same'}},1),'Duplicate identities fail closed')
check(not ctx:sample({},1),'Empty population is unsupported')
do
  local original={};for i=1,52 do original[i]={id='playing:'..i} end
  local context=Paired.new(original)
  local adjacent,total=0,0
  local first_positions,second_positions={},{}
  for salt=1,256 do
    local cards={};for i,c in ipairs(original) do cards[i]=c end
    cards[#cards+1]={id='advisor-copy:playing:'..salt..':1'}
    cards[#cards+1]={id='advisor-copy:playing:'..salt..':2'}
    for sample=1,4 do
      local a,b
      for position,index in ipairs(context:sample(cards,sample)) do
        if index==53 then a=position elseif index==54 then b=position end
      end
      total=total+1
      if math.abs(a-b)==1 then adjacent=adjacent+1 end
      first_positions[a]=true;second_positions[b]=true
    end
  end
  local a,b=0,0;for _ in pairs(first_positions) do a=a+1 end;for _ in pairs(second_positions) do b=b+1 end
  check(a==54 and b==54,'Adjacent generated IDs can each reach every physical position')
  -- Expected adjacency is 2/54. Broad fixed deterministic audit bounds detect
  -- the previous effectively 100% correlation without pretending calibration.
  check(adjacent/total>.015 and adjacent/total<.075,'Generated copies do not collapse into one shared insertion gap')
  print('paired addition diversity: '..adjacent..' adjacent pairs / '..total..' deterministic audit worlds')
end
do
  -- With one existing card and two labelled additions there are exactly six
  -- possible orders. Sequential uniform insertion gives all six equal mass;
  -- independent fixed-gap priorities overweight both additions sharing a gap.
  local context=Paired.new({{id='root'}})
  local counts={}
  for salt=1,1536 do
    local cards={{id='root'},{id='copy:'..salt..':1'},{id='copy:'..salt..':2'}}
    for sample=1,4 do
      local order=context:sample(cards,sample)
      local key=table.concat(order,',');counts[key]=(counts[key] or 0)+1
    end
  end
  local covered=0
  for key,count in pairs(counts) do
    covered=covered+1
    check(count>=850 and count<=1200,'Joint three-card order mass is balanced: '..key..'='..count)
  end
  check(covered==6,'All six joint insertions occur across deterministic audit keys')
end
do
  local context=Paired.new({{id=1},{id='1'},{id='root'}})
  local cards={{id='new:2'},{id='root'},{id=1},{id='1'},{id='new:1'}}
  for sample=1,4 do
    local physical={};local observed={}
    for _,index in ipairs(context:sample(cards,sample)) do
      local id=type(cards[index].id)..':'..tostring(cards[index].id)
      check(not observed[id],'Typed numeric/string identities remain distinct');observed[id]=true
      physical[#physical+1]=id
    end
    local permuted={cards[4],cards[1],cards[5],cards[3],cards[2]};local other={}
    for _,index in ipairs(context:sample(permuted,sample)) do other[#other+1]=type(permuted[index].id)..':'..tostring(permuted[index].id) end
    check(table.concat(physical,',')==table.concat(other,','),'Typed-ID sample is invariant under population enumeration')
  end
end
math.random=old_random
print('advisor_paired_deck: '..checks..' checks passed')
