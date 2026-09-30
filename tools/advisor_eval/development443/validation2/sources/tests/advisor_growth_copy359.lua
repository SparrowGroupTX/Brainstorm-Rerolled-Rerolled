-- Manufactured copy-aware growth only. No captured policy, source, game or RNG.
math.random=function()error('No RNG allowed in this fixture')end
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={growth=Growth,scoring=Scoring,strategy=Strategy,search=Search}
local checks=0
local function check(x,label) checks=checks+1;assert(x,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local function card(id,rank,suit,key)
  local names={c_base={'Default Base','Default','Base'},m_mult={'Mult','Enhanced','Mult Card'},
    m_bonus={'Bonus','Enhanced','Bonus Card'},m_steel={'Steel Card','Enhanced','Steel Card'}}
  key=key or 'c_base';local shape=names[key];local nominal=rank==14 and 11 or math.min(10,rank)
  return {id=id,key=key,name=shape[1],enhancement=key,rank=rank,suit=suit,nominal=nominal,debuff=false,face_down=false,
    base={id=rank,suit=suit,nominal=nominal},ability={name=shape[1],set=shape[2],effect=shape[3],
      mult=key=='m_mult' and 4 or 0,bonus=key=='m_bonus' and 30 or 0,perma_bonus=0,x_mult=1,
      h_x_mult=key=='m_steel' and 1.5 or 0,h_mult=0,h_dollars=0,p_dollars=0,t_mult=0,t_chips=0,h_size=0,d_size=0}}
end
local function joker(key,name)
  return {id=key,key=key,name=name,blueprint_compat=true,ability={name=name,set='Joker',x_mult=1,mult=0}}
end
local function state()
  local s={phase='hand',ante=3,win_ante=8,deck_key='b_zodiac',stake=8,
    blind={key='bl_big',name='Big Blind',boss=false,debuff={},chips=12000},chips=0,
    hands_left=4,hands_played=0,discards_used=1,discards_left=3,current_round={discards_left=3,discards_used=1},
    hand_size=8,hand_limit=5,dollars=14,interest_cap=25,interest_amount=1,consumeable_buffer=0,consumable_limit=2,
    hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},modifiers={scaling=3},probabilities={normal=1}}
  s.hands.Flush={chips=50,mult=6,level=2,l_chips=15,l_mult=2,s_chips=35,s_mult=4,played=3,played_this_round=0}
  local ranks={14,13,11,8,3}
  for i=1,5 do s.hand[i]=card('held:'..i,ranks[i],'Hearts',i<=2 and 'm_steel' or 'm_mult') end
  for i=6,8 do s.hand[i]=card('held:'..i,i-4,'Clubs','m_mult') end
  for i=1,6 do s.deck[i]=card('deck:'..i,2+i,'Diamonds',i%2==0 and 'm_mult' or 'c_base');s.deck[i].face_down=true end
  local y=joker('j_yorick','Yorick');y.ability.x_mult=4;y.ability.yorick_discards=23;y.ability.extra={discards=23,xmult=1}
  local nova=joker('j_supernova','Supernova');nova.ability.extra=1
  local copy=joker('j_brainstorm','Brainstorm');copy.ability.eternal=true
  local droll=joker('j_droll','Droll Joker');droll.ability.type='Flush';droll.ability.t_mult=10;droll.ability.eternal=true
  s.jokers={y,nova,copy,droll,joker('j_perkeo','Perkeo')}
  s.consumeables={{id='tarot:1',key='c_empress',ability={name='The Empress',set='Tarot'},edition={negative=true,type='negative'}}}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local selected={1,2,3,4,5}
local function clear(s) local p=Scoring.score(s,selected);p.indices=clone(selected);return p end
local function suggest(s,cap,known) return Growth.suggest(s,modules,known or clear(s),{max_evaluations=cap or 12}) end
local function fp(s) return Snapshot.fingerprint(s) end
local function entry(d) return d.yorick_copy_credit and d.yorick_copy_credit.entries[1] end
local function factor(s)
  local before=clear(s);local after=clone(s);after.jokers[1].ability.x_mult=after.jokers[1].ability.x_mult+1
  return math.max(1,math.min(2,(clear(after).score/before.score-1)*s.jokers[1].ability.x_mult))
end
local s=state();local original=fp(s);local known=clear(s)
local g,n,d=suggest(s)
check(g and g.action.kind=='discard','copied X4 partial growth can justify a safe three-card discard')
eq(#g.action.indices,3,'all three spare cards while retaining the five-card clear')
eq(g.growth.effects.yorick_growth,0,'copies do not create physical increments')
local after=assert(Scoring.after_discard(s,g.action.indices))
eq(after.jokers[1].ability.yorick_discards,20,'one physical counter decreases by actual discard count')
eq(after.jokers[1].ability.x_mult,4,'no fabricated immediate X increase')
eq(entry(d).scoring_applications,2,'Brainstorm current row resolves to actual Yorick')
check(math.abs(entry(d).factor-factor(s))<1e-10,'row-specific credit matches independent score endpoints')
check(math.abs(g.merit-(80*3/23/4*factor(s)-4))<1e-10,'only partial heuristic utility gets copy credit')
check(n<=12 and n==d.evaluations,'existing twelve-call allowance and exact accounting')
eq(fp(s),original,'input remains byte-structurally unchanged')
eq(fp(after.consumeables),fp(s.consumeables),'complete Negative Perkeo inventory preserved')
check(g.play.score>=s.blind.chips*1.05,'retained clear still independently proven')
-- Additive Mult between or after copies attenuates the marginal gain; counting
-- two applications must not blindly multiply the original utility by two.
s=state();s.hands.Flush.played=200
g,n,d=suggest(s)
check(entry(d).factor>1 and entry(d).factor<2,'large intervening additive effect receives less than double credit')
check(math.abs(entry(d).factor-factor(s))<1e-10,'actual arithmetic determines the partial bonus')
eq(g,nil,'attenuated credit need not overcome action cost')
-- Active copy chains increase scoring multiplicity, never physical progress.
s=state();local y=s.jokers[1];local nova=s.jokers[2];local brain=s.jokers[3]
s.jokers={joker('j_blueprint','Blueprint'),y,brain,nova,s.jokers[4],s.jokers[5]}
g,n,d=suggest(s)
check(g~=nil,'current Blueprint and Brainstorm chain supports growth')
eq(entry(d).physical_index,2,'credit binds the physical source position')
eq(entry(d).scoring_applications,3,'three current scoring applications')
check(entry(d).factor<=3,'nonlinear credit remains bounded by current multiplicity')
after=assert(Scoring.after_discard(s,g.action.indices))
eq(after.jokers[2].ability.yorick_discards,20,'chain leaves only physical growth')
-- Unqualified rows receive no added utility. Existing policy remains the
-- fallback; these checks make no broader claim that old advice is optimal.
local function no_bonus(label,change)
  local t=state();change(t);local p=clear(t);p.indices=clone(selected)
  local result,used,diag=suggest(t,12,p)
  check(not entry(diag),label..' grants no copied-growth bonus')
  check(used<=12,label..' keeps cap')
end
no_bonus('inactive copier',function(t)t.jokers[3].debuff=true end)
no_bonus('incompatible target',function(t)t.jokers[1].blueprint_compat=false end)
no_bonus('unknown compatibility',function(t)t.jokers[1].blueprint_compat=nil end)
no_bonus('concealed row',function(t)t.jokers[3].face_down=true end)
no_bonus('expired copier',function(t)t.jokers[3].ability.perishable=true;t.jokers[3].ability.perish_tally=0 end)
no_bonus('future-expiring copier',function(t)t.jokers[3].ability.perishable=true;t.jokers[3].ability.perish_tally=1 end)
no_bonus('moving row',function(t)t.jokers_shuffling=true end)
no_bonus('unknown modified Joker',function(t)t.jokers[2].key='j_modded';t.jokers[2].ability.name='Modded' end)
no_bonus('copy loop',function(t)
  t.jokers={joker('j_blueprint','Blueprint'),joker('j_brainstorm','Brainstorm'),t.jokers[1],t.jokers[2],t.jokers[4]}
end)
s=state();known=clear(s);known.bound_kind='supported_random_floor'
g,n,d=suggest(s,12,known);check(not entry(d),'a supported floor is not an exact ratio baseline')
s=state();s.modifiers.discard_cost=5
g=suggest(s);eq(g,nil,'cash and interest costs still defeat copied partial progress')
s=state();s.ante=8;s.blind.boss=true
g,n=suggest(s);eq(g,nil,'final boss retains finish-now horizon');eq(n,0,'no unnecessary final work')
s=state();s.jokers[1].ability.x_mult=20
g=suggest(s);eq(g,nil,'mature copied distant progress is not forced')
s=state();s.hand[6].seal='Blue';s.hand[7].seal='Blue';s.hand[8].seal='Blue'
g=suggest(s);eq(g,nil,'Blue generation opportunity is still charged')
s=state();s.blind.key='bl_final_bell'
g=suggest(s);eq(g,nil,'forced-card draw hazard remains excluded')
-- If only one score is available, preserve it for an actual retained finish.
s=state();known=clear(s)
for cap=0,12 do
  local real=Scoring.score;local calls=0
  Scoring.score=function(...)calls=calls+1;return real(...)end
  local result,work,diag=suggest(s,cap,known);Scoring.score=real
  eq(work,calls,'every actual call is charged for cap '..cap)
  check(work<=cap,'caller cap '..cap..' is preserved')
  if result then check(result.play.score>=s.blind.chips*1.05,'low-cap result still has exact retained clear') end
  if cap<=1 then check(not entry(diag),'at least one finish call reserved before copy credit') end
end
-- Unsupported upgraded score cannot become a ratio-based utility bonus.
s=state();known=clear(s);local real=Scoring.score
Scoring.score=function(t,indices)
  local p=real(t,indices)
  if t.jokers[1].ability.x_mult==5 then p.uncertain=true;p.warnings={'Unmodeled synthetic upgraded endpoint'} end
  return p
end
g,n,d=suggest(s,12,known);Scoring.score=real
check(not entry(d),'unsupported future-unit endpoint leaves old utility unchanged')
eq(g,nil,'unsupported credit cannot introduce a growth action')
--366: early win-first partial growth preference retains the same proof/cost gates.
do
 local t=state();t.jokers={t.jokers[1],t.jokers[5]};t.jokers[1].ability.x_mult=3
 t.blind.chips=100;t.teacher_profile=nil
 local old=suggest(t);check(not old,'ordinary three-spare X3 progress does not pay fixed action cost')
 t.teacher_profile='perkeo_yorick_win_v1';local g,c=suggest(t)
 check(g and g.action.kind=='discard' and #g.action.indices==3,'early teacher invests safe spare cards')
 check(g.play.score>=t.blind.chips*1.05 and c<=12,'teacher retains exact finish and cap')
 t.ante=4;check(not suggest(t),'early premium ends after Ante3')
 t.ante=3;t.jokers[1].ability.x_mult=5;check(not suggest(t),'mature Yorick does not get early premium')
 t.jokers[1].ability.x_mult=3;t.blind.chips=clear(t).score
 check(not suggest(t),'early preference never relaxes105 percent safety margin')
end
print('advisor growth copied Yorick359: '..checks..' checks passed')
