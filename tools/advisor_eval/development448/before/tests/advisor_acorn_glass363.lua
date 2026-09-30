-- Manufactured inputs only; no captured game, hidden reads or random sampling.
local p='Brainstorm/Advisor/'
local B=dofile(p..'acorn_belief.lua')
local O=dofile(ADVISOR_ACORN_PATH or p..'acorn_ordering.lua')
local S=dofile(p..'scoring.lua')
local D=dofile(p..'decision.lua')
local fingerprint=dofile(p..'snapshot.lua').fingerprint
local checks=0
local function check(x,m) checks=checks+1;assert(x,m) end
local function eq(a,b,m) check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function forbidden() error('Hidden fallback or RNG called') end
local function j(key,name,a) a=a or {};a.name=name;return {key=key,ability=a,blueprint_compat=true} end
local function card(rank,enh,seal)
  return {id='manufactured:'..rank,rank=rank,nominal=math.min(rank,10),suit='Clubs',
    enhancement=enh or 'c_base',seal=seal,ability=enh=='m_glass' and {x_mult=2,extra=4} or {}}
end
local function state(n)
  local b=assert(B.start({j('j_joker','Joker',{mult=4}),j('j_cavendish','Cavendish',{extra={Xmult=3}})},
    'glass363',{public_before_shuffle=true}))
  local hidden=setmetatable({face_down=true},{__index=forbidden})
  local s={phase='hand',hand={},deck={},playing_cards={},hands={},jokers={hidden,hidden},
    public_joker_belief=b,hands_left=4,discards_left=3,hand_limit=5,chips=0,dollars=10,
    blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000000},probabilities={normal=1},
    consumeables={},modifiers={}}
  for i=1,n do s.hand[i]=card(i+2,i==1 and 'm_glass' or nil);s.playing_cards[i]=B.copy(s.hand[i]) end
  return s
end
local function limits(n) return {max_evaluations=n,max_order_evaluations=0} end
local function project(s,w)
  local t={};for k,v in pairs(s) do if k~='jokers' and k~='public_joker_belief' then t[k]=B.copy(v) end end
  t.jokers={};for i,index in ipairs(w) do t.jokers[i]=B.copy(s.public_joker_belief.inventory[index]) end
  return t
end
local oldrandom,oldseed=math.random,math.randomseed
math.random,math.randomseed=forbidden,forbidden
local ok,err=pcall(function()
  -- One Glass three: (5+3) chips; 1*2 mult, then +4 and *3 in either order.
  local s=state(1);local before=fingerprint(s)
  local a,n,d=O.suggest(s,s.public_joker_belief,S,B,limits(2))
  check(a and a.kind=='play','Glass immediate public action admitted')
  eq(n,2,'Both public worlds scored');eq(a.minimum_score,80,'Independent Glass minimum')
  eq(a.mean_score,112,'Independent Glass world mean:80 and144')
  check(d.glass_after_scoring and d.complete,'Glass scope explicit')
  check(a.lines[2]:find('may break after scoring',1,true),'Advice discloses survival limitation')
  eq(fingerprint(s),before,'Immediate plan never mutates population or hand')
  for _,seal in ipairs({'none','Red'}) do
    s.hand[1].seal=seal=='Red' and 'Red' or nil
    local lo,hi=math.huge,0
    for _,w in ipairs(s.public_joker_belief.worlds) do
      local t=project(s,w);local r=S.score(t,{1})
      eq(#r.glass_exposure,1,'One break exposure regardless of retriggers')
      eq(r.glass_exposure[1].probability,0.25,'Break chance not sampled')
      lo=math.min(lo,r.score);hi=math.max(hi,r.score)
      t.probabilities.normal=4
      local certain=S.score(t,{1});eq(certain.score,r.score,'Certain break does not reduce immediate score')
      eq(certain.glass_exposure[1].probability,1,'Certain break remains exposed')
    end
    eq(lo,seal=='Red' and 176 or 80,'Exact minimum with Red chip/mult repeat')
    eq(hi,seal=='Red' and 264 or 144,'Exact maximum with Red chip/mult repeat')
  end
  -- Full nine-card family, including Lucky floors and every held/scoring Glass case.
  s=state(9);s.hand[2].enhancement='m_lucky';s.hand[2].ability={mult=20,p_dollars=20}
  s.playing_cards[2]=B.copy(s.hand[2]);before=fingerprint(s)
  local calls,seen=0,{}
  local scorer={score=forbidden,lower_bound=function(t,indices)
    calls=calls+1;local row=table.concat({t.jokers[1].key,t.jokers[2].key},',')
    local key=row..'|'..table.concat(indices,',');check(not seen[key],'Each world/subset exactly once');seen[key]=true
    local original=fingerprint(t);local r=S.lower_bound(t,indices)
    eq(fingerprint(t),original,'Lower bound leaves Glass/population unchanged')
    return r
  end}
  local modules={acorn_belief=B,acorn_ordering=O,scoring=scorer,search={run=forbidden},
    concealed_belief={run=forbidden},consumables={suggest=forbidden}}
  local result=D.run(s,modules,nil,{acorn_belief=limits(762)})
  check(result.action and result.action.kind=='play','Decision routes Glass plus Lucky without latent fallback')
  eq(calls,762,'All381 subsets in both worlds');eq(result.evaluations,calls,'Actual score accounting')
  check(result.conservative and not result.deterministic_exact,'Floor is not a realized-score promise')
  eq(fingerprint(s),before,'Input and inventory preserved')
  for mask=1,511 do
    local indices={};for i=1,9 do if math.floor(mask/2^(i-1))%2==1 then indices[#indices+1]=i end end
    if #indices<=5 then
      for _,row in ipairs({'j_joker,j_cavendish','j_cavendish,j_joker'}) do
        check(seen[row..'|'..table.concat(indices,',')],'Independent bitmask oracle covers full family')
      end
    end
  end
  eq(O.suggest(s,s.public_joker_belief,{score=forbidden,lower_bound=forbidden},B,limits(761)),nil,'No partial family at caller cap')
  for _,mode in ipairs({'unknown','unknown_seal','hidden'}) do
    local t=B.copy(s)
    if mode=='unknown' then t.hand[1].enhancement='m_unqualified'
    elseif mode=='unknown_seal' then t.hand[1].seal='Unqualified' else t.hand[1].face_down=true end
    eq(O.suggest(t,t.public_joker_belief,{score=forbidden,lower_bound=forbidden},B),nil,'Unrelated '..mode..' guard retained')
  end
  -- A new settled observation supplies the remaining population; no guessed draw.
  s=state(2);local b=s.public_joker_belief
  local fresh=state(2);table.remove(fresh.hand,1);table.remove(fresh.playing_cards,1)
  fresh.hands_left=3;fresh.public_joker_belief=assert(B.advance_public(b,{epoch=b.epoch,kind='play',observed_complete=true}))
  check(fresh.public_joker_belief.state_valid,'Stable qualified Joker abilities survive observed play')
  local population=fingerprint(fresh.playing_cards)
  check(O.suggest(fresh,fresh.public_joker_belief,S,B,limits(2))~=nil,'Fresh post-break population supports next advice')
  eq(fingerprint(fresh.playing_cards),population,'No Glass card resurrected')
  for _,name in ipairs({'Glass Joker','Caino'}) do
    local changing=assert(B.start({j(name=='Caino' and 'j_caino' or 'j_glass',name,{x_mult=2})},'changing',{public_before_shuffle=true}))
    local advanced=B.advance_public(changing,{epoch='changing',kind='play',observed_complete=true})
    check(not advanced.state_valid,'Unqualified post-destruction '..name..' abilities invalidate')
    eq(O.suggest(fresh,advanced,{score=forbidden},B),nil,'Stale hidden ability never scored')
  end
  -- The existing transition API still requires an explicit outcome for random breakage.
  s=state(1);local t=project(s,s.public_joker_belief.worlds[1]);before=fingerprint(t)
  local future,reason=S.after_play(t,{1})
  eq(future,nil,'Unobserved Glass destruction has no invented future')
  check(reason:find('Glass destruction',1,true),'Specific missing outcome diagnosis')
  eq(fingerprint(t),before,'Rejected future preserves population')
end)
math.random,math.randomseed=oldrandom,oldseed
if not ok then error(err,0) end
print('advisor_acorn_glass363: '..checks..' checks passed')
