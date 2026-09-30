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

-- Blue Joker: real scorer proof must charge all replacement draws.
local s=state();s.teacher_profile='perkeo_yorick_win_v1';s.blind.chips=100
for i,c in ipairs(s.hand) do s.hand[i]=card(c.id,c.rank,c.suit) end
s.jokers[1].ability.x_mult=2
s.jokers[2]=joker('j_blue_joker','Blue Joker');s.jokers[2].ability.extra=2
local original=fp(s);local g,n,d=suggest(s)
check(g and g.action.kind=='discard','Blue Joker now admits a safe single discard')
local after=assert(Scoring.after_discard(s,g.action.indices))
local draws=math.min(#after.deck,s.hand_size-#after.hand)
local deck={};for i=1,#after.deck-draws do deck[i]=after.deck[i] end;after.deck=deck
local indices={1,2,3,4,5};local expected=Scoring.score(after,indices)
eq(g.play.score,expected.score,'Blue proof equals independently counted post-draw bonus')
eq(g.growth.blue_joker_draw_cost.remaining_deck,#deck,'draw count recorded')
check(not g.growth.two_discard_threshold,'Blue remains outside two-discard scope')
check(n<=12 and fp(s)==original,'growth cap and immutable input')
s.jokers[2]=joker('j_raised_fist','Raised Fist');check(not suggest(s),'held-order hazard remains blocked')
s=state();s.teacher_profile='perkeo_yorick_win_v1';s.jokers[2]=joker('j_blue_joker','Blue Joker');s.jokers[2].ability.extra=10000
for i,c in ipairs(s.hand) do s.hand[i]=card(c.id,c.rank,c.suit) end
s.blind.chips=clear(s).score/1.05
check(not suggest(s),'narrow margin cannot ignore lost Blue chips')

local function owned(key,negative,field)
 return {key=key,ability={set='Tarot',consumeable=field and {[field]=2} or {}},sell_cost=negative and 4 or 1,
 edition=negative and {negative=true} or nil}
end
local function stock()
 local q=state();q.phase='shop';q.teacher_profile='perkeo_yorick_win_v1';q.ante=6;q.blind={chips=0}
 q.jokers={joker('j_perkeo','Perkeo')};q.consumeables={owned('c_emperor',false,'tarots')};q.consumable_limit=2
 return q
end
s=stock();original=fp(s);g=Strategy.manage_teacher_stock(s)
check(g and g.action.kind=='use' and g.stock_review.generated_capacity==2,'sole ordinary generator reveals two options')
check(fp(s)==original,'shop input preserved')
s.consumable_limit=1;g=Strategy.manage_teacher_stock(s)
check(g and g.action.kind=='use' and g.stock_review.generated_capacity==1,'full ordinary frees exactly one slot')
s.consumeables[1]=owned('c_emperor',true,'tarots');s.consumable_limit=1
check(not Strategy.manage_teacher_stock(s),'full Negative frees no slot and sole useful type is retained')
s.consumable_limit=3;g=Strategy.manage_teacher_stock(s)
check(g and g.action.kind=='use' and g.stock_review.generated_capacity==2,'Negative with two free slots may reveal')
s.consumeables[1].ability.consumeable.tarots=3
check(not Strategy.manage_teacher_stock(s),'unsupported generation count cannot dispatch use')
s=stock();s.consumeable_buffer=1;check(not Strategy.manage_teacher_stock(s),'pending generated inventory blocks exploration')
s=stock();s.teacher_profile=nil;check(not Strategy.manage_teacher_stock(s),'normal collection untouched')
s=stock();s.jokers[1].debuff=true;check(not Strategy.manage_teacher_stock(s),'debuffed Perkeo does not enter teacher stock path')
s=stock();s.consumeables={owned('c_wheel_of_fortune',true),owned('c_wheel_of_fortune',true),
 {key='c_jupiter',ability={set='Planet',consumeable={hand_type='Flush'}},sell_cost=1}}
s.consumable_limit=4;g=Strategy.manage_teacher_stock(s)
check(g and g.action.kind=='sell' and g.action.index<=2,'surplus Wheel no longer receives unlimited copy value')
s.used_vouchers={v_observatory=true};g=Strategy.manage_teacher_stock(s)
check(not g or g.action.index~=3,'matching Observatory planet never sold')

-- A higher Lucky mean cannot outrank a deterministic rescue. The scoring
-- interface is manufactured; full legal subset enumeration still runs.
local C=dofile('Brainstorm/Advisor/consumables.lua')
s=state();s.jokers={};s.hand={card('a',2,'Hearts')};s.playing_cards=s.hand;s.deck={};s.blind={chips=100};s.chips=0;s.hands_left=1
s.consumeables={owned('c_magician'),owned('c_empress')};s.consumable_limit=2
local function score(q,ii)
 local lucky=q.hand[1].enhancement=='m_lucky';local enhanced=q.hand[1].enhancement=='m_mult'
 return {legal=true,uncertain=lucky,score=lucky and 1000 or enhanced and 110 or 20,hand='High Card',indices=ii,warnings={}}
end
local result={kind='play',play=score(s,{1})}
g,n,d=C.suggest(s,{score=score},result,nil,{max_evaluations=30,sequences=false})
check(g and g.action.index==2 and not g.play.uncertain,'guaranteed Empress rescue beats much larger Lucky mean')
s.consumeables={owned('c_magician')};g,n,d=C.suggest(s,{score=score},result,nil,{max_evaluations=30,sequences=false})
check(g and g.play.uncertain,'when no guaranteed rescue exists an uncertain improvement remains usable')
check(table.concat(g.lines,' '):find('not a guaranteed clear',1,true),'uncertain action clearly labelled')
check(n<=30,'risk comparison respects caller allowance')
-- Same complete deterministic draw family; only the current hand is uncertain.
s=state();s.hand={card('held',2,'Clubs')};s.hand_size=1;s.playing_cards={s.hand[1]};s.deck={card('draw1',3,'Hearts'),card('draw2',4,'Spades')}
for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
s.jokers={};s.consumeables={};s.blind={chips=100};s.hands_left=2;s.discards_left=2
local mocked={after_discard=Scoring.after_discard,score=function(q,ii)
 local current=q.hand[1].id=='held'
 return {legal=true,uncertain=current,score=current and 150 or 105,hand='High Card',scoring_indices=ii}
end}
local r=Search.run(s,mocked,{draws=dofile('Brainstorm/Advisor/draws.lua'),samples=4,resource_samples=0,score_bounds=false,max_evaluations=1000})
check(r.kind=='discard' and r.discard.probability==1,'supported sampled clears beat an unsupported current mean-clear bonus')
check(r.evaluations<=1000,'ordinary risk repair stays inside caller cap')
print('teacher repairs367: '..checks..' checks passed')
