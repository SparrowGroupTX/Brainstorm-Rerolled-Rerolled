-- Manufactured post-first Burnt proof. No captured state, source run, seed or RNG.
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
    blind={key='bl_big',name='Big Blind',boss=false,debuff={},chips=14000},chips=0,
    hands_left=4,hands_played=0,discards_used=1,discards_left=3,current_round={discards_left=3,discards_used=1},
    hand_size=8,hand_limit=5,dollars=14,interest_cap=25,interest_amount=1,consumeable_buffer=0,consumable_limit=2,
    hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},modifiers={scaling=3},probabilities={normal=1}}
  s.hands.Flush={chips=50,mult=6,level=2,l_chips=15,l_mult=2,s_chips=35,s_mult=4,played=3,played_this_round=0}
  local ranks={14,13,11,8,3}
  for i=1,5 do s.hand[i]=card('held:'..i,ranks[i],'Hearts',i<=2 and 'm_steel' or 'm_mult') end
  for i=6,8 do s.hand[i]=card('held:'..i,i-4,'Clubs','m_mult') end
  for i=1,6 do s.deck[i]=card('deck:'..i,2+i,'Diamonds',i%2==0 and 'm_mult' or 'c_base');s.deck[i].face_down=true end
  local y=joker('j_yorick','Yorick');y.ability.x_mult=3;y.ability.yorick_discards=6;y.ability.extra={discards=23,xmult=1}
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
local function burnt(id)
  local b=joker('j_burnt','Burnt Joker');b.id=id or 'burnt:1';b.ability.effect='';b.ability.extra=4;return b
end
local function scenario(layout)
  local s=state();s.jokers[5]=burnt()
  if layout=='brainstorm_burnt' then s.jokers[1],s.jokers[5]=s.jokers[5],s.jokers[1]
  elseif layout=='blueprint_burnt' then
    s.jokers[3]=joker('j_blueprint','Blueprint');s.jokers[4],s.jokers[5]=s.jokers[5],s.jokers[4]
    s.jokers[6]=burnt('burnt:2')
  end
  -- Exercise the353 margin without retuning it: first establish an exact
  -- current score, then set an integer target just inside its106% entry band.
  local p=clear(s);s.blind.chips=math.floor(p.score/1.06)
  return s
end
local s=scenario('brainstorm_yorick');local original=fp(s);local known=clear(s)
check(known.legal and not known.uncertain,'manufactured reserved hand is exactly supported')
check(known.score>=s.blind.chips*1.05 and known.score<s.blind.chips*1.10,'preserve353 admission band')
local g,n,d=suggest(s)
check(g and g.growth and g.growth.two_discard_threshold,'known Burnt after first discard admits complete Yorick pair')
eq(g.action.kind,'discard','only first discard dispatched');eq(table.concat(g.action.indices,','),'6,7,8','keep actual reserved physical cards')
eq(g.growth.first_burnt_discard,false,'no first-discard credit');eq(g.growth.effects.burnt_levels,0,'no new Burnt levels')
eq(g.growth.effects.burnt_hand,nil,'no invented upgraded category');eq(fp(s),original,'full input unchanged')
check(n<=6 and n==d.evaluations,'existing local shortlist accounting')

local function drawn(t,ids)
  local wanted,found={},{};for _,id in ipairs(ids)do wanted[id]=true end
  local left={};for _,c in ipairs(t.deck)do if wanted[c.id]then found[c.id]=c else left[#left+1]=c end end
  for _,id in ipairs(ids)do local c=assert(found[id]);c.face_down=false;t.hand[#t.hand+1]=c end;t.deck=left
  for i,c in ipairs(t.playing_cards)do for _,h in ipairs(t.hand)do if h.id==c.id then t.playing_cards[i]=h end end end
end
local trajectories,layouts=0,0
for _,layout in ipairs({'brainstorm_yorick','brainstorm_burnt','blueprint_burnt'})do
  local base=scenario(layout);local untouched=fp(base);local hand_levels=fp(base.hands);local current=clear(base)
  local advice,work,diag=suggest(base);check(advice and advice.growth.two_discard_threshold,layout..' admits the complete pair')
  local proof=advice.growth.two_discard_threshold
  eq(proof.second_threshold_growth,1,layout..' grows exactly one physical Yorick')
  eq(#proof.future_yoricks,1,layout..' does not invent copy growth')
  eq(proof.future_yoricks[1].id,'j_yorick',layout..' binds physical Yorick ID')
  eq(proof.future_yoricks[1].x_mult,4,layout..' exact multiplier endpoint')
  eq(proof.future_yoricks[1].discard_count,23,layout..' exact countdown endpoint')
  check(work<=6 and work==diag.evaluations,layout..' fixed local cap')
  local seen={};local count=0
  local function visit(order,used)
    if #order==6 then
      local key=table.concat(order,',');check(not seen[key],'distinct full draw ordering');seen[key]=true
      local first,e1=assert(Scoring.after_discard(base,advice.action.indices))
      local batch={};for i=1,3 do batch[i]='deck:'..order[i]end;drawn(first,batch)
      eq(e1.burnt_levels,0,'first planned action does not retrigger Burnt');eq(e1.burnt_hand,nil,'first has no Burnt hand')
      eq(fp(first.hands),hand_levels,'first preserves complete hand levels/history')
      eq(e1.yorick_growth,0,'first does not cross physical Yorick threshold')
      eq(Scoring.score(first,selected).score,current.score,'every first draw retains exact clearing score')
      local second,e2=assert(Scoring.after_discard(first,{6,7,8}))
      batch={};for i=4,6 do batch[#batch+1]='deck:'..order[i]end;drawn(second,batch)
      eq(e2.burnt_levels,0,'second planned action does not retrigger Burnt');eq(e2.burnt_hand,nil,'second has no Burnt hand')
      eq(fp(second.hands),hand_levels,'second preserves complete hand levels/history')
      eq(e2.yorick_growth,1,'second crosses exactly one physical Yorick threshold')
      local y;for _,j in ipairs(second.jokers)do if j.id=='j_yorick'then y=j end end
      eq(y.ability.x_mult,proof.future_yoricks[1].x_mult,'physical multiplier matches bound receipt')
      eq(y.ability.yorick_discards,proof.future_yoricks[1].discard_count,'physical countdown matches bound receipt')
      local scored=Scoring.score(second,selected)
      check(scored.legal and not scored.uncertain and scored.score>=advice.play.score,'every second draw retains physical clear floor')
      eq(second.discards_used,3,'both later discards charged');eq(second.current_round.discards_used,3,'round counter agrees')
      eq(second.discards_left,proof.remaining_discards,'remaining discards bound');eq(second.current_round.discards_left,second.discards_left,'round remaining count agrees')
      eq(second.dollars,proof.future_dollars,'cash endpoint');eq(#second.deck,proof.remaining_deck,'finite deck exhausted exactly')
      eq(#second.playing_cards,#base.playing_cards,'population conserved');eq(fp(second.consumeables),fp(base.consumeables),'whole Negative inventory unchanged')
      for i,j in ipairs(base.jokers)do if j.key=='j_burnt'then eq(fp(second.jokers[i]),fp(j),'same physical Burnt has no changed fields')end end
      count=count+1;trajectories=trajectories+1;return
    end
    for i=1,6 do if not used[i]then used[i]=true;order[#order+1]=i;visit(order,used);order[#order]=nil;used[i]=nil end end
  end
  visit({},{});eq(count,720,layout..' complete finite draw family');eq(fp(base),untouched,layout..' input unchanged')
  layouts=layouts+1
end
eq(trajectories,2160,'all three complete finite-population families');eq(layouts,3,'both copy identities and multiple Burnt covered')

local function rejects(label,change)
  local t=scenario('brainstorm_yorick');local p=clear(t);change(t)
  local ok,result,count=pcall(suggest,t,12,p);check(ok,label..' never throws')
  check(not result or not result.growth.two_discard_threshold,label..' declines pair proof')
  check(count<=12,label..' unchanged cap')
end
for _,case in ipairs({
 {'first discard',function(t)t.discards_used=0;t.current_round.discards_used=0 end},
 {'missing top count',function(t)t.discards_used=nil end},
 {'missing round count',function(t)t.current_round.discards_used=nil end},
 {'missing round table',function(t)t.current_round=nil end},
 {'top zero disagrees',function(t)t.discards_used=0 end},
 {'round zero disagrees',function(t)t.current_round.discards_used=0 end},
 {'positive disagreement',function(t)t.current_round.discards_used=2 end},
 {'fractional top count',function(t)t.discards_used=1.5;t.current_round.discards_used=1.5 end},
 {'negative counts',function(t)t.discards_used=-1;t.current_round.discards_used=-1 end},
 {'string round count',function(t)t.current_round.discards_used='1'end},
 {'unknown Burnt name',function(t)t.jokers[5].ability.name='Unknown Burnt'end},
 {'unknown Burnt key',function(t)t.jokers[5].key='j_mod_burnt'end},
 {'unsupported Burnt effect',function(t)t.jokers[5].ability.effect='Unknown' end},
 {'unsupported Burnt extra',function(t)t.jokers[5].ability.extra=99 end},
 {'unsupported Burnt callback field',function(t)t.jokers[5].ability.mod_callback=true end},
 {'modified Burnt score',function(t)t.jokers[5].ability.t_mult=1 end},
 {'Burnt edition',function(t)t.jokers[5].edition={holo=true}end},
 {'debuffed Burnt',function(t)t.jokers[5].debuff=true end},
 {'expired Burnt',function(t)t.jokers[5].ability.perishable=true;t.jokers[5].ability.perish_tally=0 end},
 {'hidden Burnt',function(t)t.jokers[5].face_down=true end},
 {'incomplete finite population',function(t)table.remove(t.deck)end},
 {'only one discard',function(t)t.discards_left=1;t.current_round.discards_left=1 end},
 {'future Purple generation',function(t)t.deck[1].seal='Purple'end},
 {'boss exclusion',function(t)t.blind.key='bl_psychic';t.blind.name='The Psychic';t.blind.boss=true end},
})do rejects(case[1],case[2])end

s=scenario('brainstorm_yorick');known=clear(s)
local real=Scoring.score;local calls=0;Scoring.score=function(...)calls=calls+1;return real(...)end
g,n=suggest(s,1,known);Scoring.score=real
check(g and g.growth.two_discard_threshold,'one score still certifies complete count-only pair');eq(calls,1,'one actual score call');eq(n,calls,'reported cost equals actual')
g,n=suggest(s,0,known);eq(g,nil,'zero cap has no action');eq(n,0,'zero cap has no score')
local next_state=assert(Scoring.after_discard(s,{6,7,8}));drawn(next_state,{'deck:1','deck:2','deck:3'})
g=suggest(next_state);check(g and g.action.kind=='discard','fresh observation independently selects second action')
eq(g.growth.effects.yorick_growth,1,'fresh second action grows physical Yorick');eq(g.growth.effects.burnt_levels,0,'fresh second action still cannot repeat Burnt')
eq(g.growth.two_discard_threshold,nil,'no queued future action credit on fresh state')
calls=0;Scoring.score=function(...)calls=calls+1;return real(...)end
local result=Decision.run(s,modules);Scoring.score=real
check(result.fast_clear and result.growth and result.growth.growth.two_discard_threshold,'full decision uses post-first Burnt pair')
check(calls<=70 and result.evaluations<=70,'aggregate fast-clear budget unchanged');eq(calls,result.evaluations,'full actual work is charged')
print('advisor post-first Burnt inert pair: '..checks..' checks passed; '..trajectories..' complete draw orders; '..layouts..' physical Joker layouts')
