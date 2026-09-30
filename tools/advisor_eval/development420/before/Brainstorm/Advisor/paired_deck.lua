-- Common composition samples for exact changes to the owned population.
-- Existing identities retain relative draw positions. New identities are
-- inserted with independent mixed draws at each growing population size, giving
-- the correct joint placement of multiple additions. No game RNG is consulted.
local Paired={}
local seeds={977,1999,3253,4751}
local floor=math.floor
local UINT32=4294967296
-- Same exact 32-bit FNV/Murmur mixing used by sampled_outcomes. In particular,
-- adjacent generated IDs must not retain an affine last-byte relationship.
local function mul32(a,b)
  local al,bl=a%65536,b%65536
  return (al*bl+((floor(a/65536)*bl+al*floor(b/65536))%65536)*65536)%UINT32
end
local xor_nibble={}
for a=0,15 do for b=0,15 do
  local x,y,v,p=a,b,0,1
  for _=1,4 do
    if x%2~=y%2 then v=v+p end
    x=floor(x/2);y=floor(y/2);p=p*2
  end
  xor_nibble[a*16+b]=v
end end
local function bxor(a,b)
  local value,place=0,1
  for _=1,8 do
    value=value+xor_nibble[(a%16)*16+b%16]*place
    a=floor(a/16);b=floor(b/16);place=place*16
  end
  return value
end
local function xor_byte(a,b)
  local low=a%256
  return a-low+xor_nibble[(low%16)*16+b%16]+16*xor_nibble[floor(low/16)*16+floor(b/16)]
end
local function mixed(seed,key,attempt)
  local h=mul32(bxor(2166136261,seed),16777619)
  local text='paired-insert:'..key..':'..attempt
  for i=1,#text do h=mul32(xor_byte(h,text:byte(i)),16777619) end
  h=mul32(bxor(h,floor(h/65536)),2246822507)
  h=mul32(bxor(h,floor(h/8192)),3266489909)
  return bxor(h,floor(h/65536))
end
local function insertion(seed,key,count)
  local ceiling=UINT32-UINT32%count
  for attempt=0,3 do
    local value=mixed(seed,key,attempt)
    if value<ceiling then return value%count+1 end
  end
  return nil,'The bounded uniform insertion draw did not complete.'
end
local function permutations(n)
  local result={}
  for sample,initial in ipairs(seeds) do
    local seed,order=initial,{}
    for i=1,n do order[i]=i end
    for i=n,2,-1 do
      seed=(seed*1664525+1013904223)%4294967296
      local j=seed%i+1;order[i],order[j]=order[j],order[i]
    end
    result[sample]=order
  end
  return result
end
local function identities(cards)
  local out={}
  for index,card in ipairs(cards) do
    if card.id==nil then return nil,'Changed populations require stable playing-card identities.' end
    local key=type(card.id)..':'..tostring(card.id)
    if out[key] then return nil,'Duplicate playing-card identities prevent paired population samples.' end
    out[key]=index
  end
  return out
end
function Paired.new(root)
  local draws=permutations(#root)
  local roots,root_error=identities(root)
  local context={draws=draws}
  function context:sample(cards,sample,unchanged)
    sample=sample or 1
    if not draws[sample] then return nil,'Unknown composition sample.' end
    if unchanged then return draws[sample] end
    if #cards==0 or #cards>120 then return nil,'Changed populations outside 1-120 cards are not sampled.' end
    if not roots then return nil,root_error end
    local current,why=identities(cards);if not current then return nil,why end
    local order={}
    for _,index in ipairs(draws[sample]) do
      local id=root[index].id;local present=current[type(id)..':'..tostring(id)]
      if present then order[#order+1]=present end
    end
    local additions={}
    for key,index in pairs(current) do
      if not roots[key] then additions[#additions+1]={index=index,key=key} end
    end
    table.sort(additions,function(a,b) return a.key<b.key end)
    for _,entry in ipairs(additions) do
      -- Insert in n+1, then n+2, ... uniformly selected positions. This gives
      -- every interleaving/new-card permutation equal probability conditional
      -- on the common surviving root order; fixed-gap independent priorities
      -- would give the wrong probability of two additions sharing a gap.
      local position,reason=insertion(seeds[sample],entry.key,#order+1)
      if not position then return nil,reason end
      table.insert(order,position,entry.index)
    end
    return order
  end
  return context
end
return Paired
