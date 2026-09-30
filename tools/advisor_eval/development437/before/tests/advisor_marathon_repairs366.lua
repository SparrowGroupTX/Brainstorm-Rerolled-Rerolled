-- Independently manufactured public states; no saved/captured state replay.
local p='Brainstorm/Advisor/'
local S=dofile(p..'scoring.lua');local D=dofile(p..'decision.lua')
local T=dofile(p..'strategy.lua');local O=dofile(p..'acorn_ordering.lua');local B=dofile(p..'acorn_belief.lua')
local Snap=dofile(p..'snapshot.lua');local n=0
local function check(v,m)n=n+1;assert(v,m)end
local function card(i,rank,enh)return {id='manufactured:'..i,rank=rank,nominal=math.min(rank,10),suit='Clubs',enhancement=enh or 'c_base',ability={}}end
local function state()
 local s={phase='hand',ante=2,win_ante=8,hand={},deck={},playing_cards={},hands={Pair={level=2,chips=25,mult=3,l_chips=15,l_mult=1,played=8}},
  jokers={},consumeables={},consumable_limit=2,chips=0,dollars=25,hands_left=2,discards_left=0,modifiers={},current_round={},
  probabilities={normal=1},blind={name='The Mouth',key='bl_mouth',only_hand='Four of a Kind',chips=5000}}
 for i,r in ipairs({9,9,2,4,6,8,10,12}) do s.hand[i]=card(i,r);s.playing_cards[#s.playing_cards+1]=s.hand[i] end
 for i=1,16 do s.deck[i]=card(8+i,2+i%12);s.playing_cards[#s.playing_cards+1]=s.deck[i] end
 return s
end
local s=state();local original=Snap.fingerprint(s);local r={evaluations=100}
D.mouth_cycle(s,S,r,140000)
check(r.action and r.action.kind=='play','Mouth supplies a zero-score public cycle')
check(r.evaluations==102 and r.mouth_cycle.score==0,'exact calls and zero score receipt')
check(Snap.fingerprint(s)==original,'Mouth never mutates input')
for _,i in ipairs(r.action.indices)do check(i~=1 and i~=2,'retain the known pair while cycling singles')end
for _,mode in ipairs({'discard','hidden','budget','incumbent','zero_hands'})do
 local q=state();local result={evaluations=0};local cap=140000
 if mode=='discard' then q.discards_left=1
 elseif mode=='hidden' then q.hand[1].face_down=true
 elseif mode=='zero_hands' then q.hands_left=0
 elseif mode=='budget' then cap=1 else result.action={kind='discard'} end
 D.mouth_cycle(q,{score=function()error('guard must precede scoring')end},result,cap)
 check(mode=='incumbent' and result.action.kind=='discard' or mode~='incumbent' and not result.action,'Mouth guard '..mode)
end
for _,mode in ipairs({'one_hand','no_deck'})do
 local q=state();local result={evaluations=0}
 if mode=='one_hand' then q.hands_left=1 else q.deck={} end
 local fingerprint=Snap.fingerprint(q)
 D.mouth_cycle(q,S,result,140000)
 check(result.action and result.action.kind=='play' and result.evaluations==2,
   'Mouth progresses with a last hand or empty deck')
 check(result.mouth_cycle.draw_available==(mode=='one_hand') and
   result.mouth_cycle.future_draw_known==false,'Mouth draw receipt is honest')
 check(result.title and result.lines and #result.lines==2,'Mouth display describes actual progression')
 check(Snap.fingerprint(q)==fingerprint,'Mouth progression does not mutate input')
end
local row={}
for _,key in ipairs({'j_joker','j_cavendish','j_greedy_joker','j_lusty_joker','j_wrathful_joker','j_gluttenous_joker'})do row[#row+1]={key=key,ability={}}end
local belief=assert(B.start(row,'manufactured366',{public_before_shuffle=true}))
check(#belief.worlds==720,'six distinct public Jokers give full720 worlds')
s=state();s.hand[9]=card(99,3);s.blind={key='bl_final_acorn',chips=1e9}
local calls,seen=0,{}
local scorer={score=function(q,indices)
 calls=calls+1;local keys={};for _,j in ipairs(q.jokers)do keys[#keys+1]=j.key end
 local world=table.concat(keys,',');local action=table.concat(indices,',')
 seen[world]=seen[world] or {};check(not seen[world][action],'no repeated cell');seen[world][action]=true
 return {legal=true,score=#indices,warnings={}}
end}
original=Snap.fingerprint(s)
local action,used,diag=O.suggest(s,belief,scorer,B,{max_order_evaluations=0})
check(action and diag.complete and not diag.all_legal_subsets,'bounded action family completes')
check(used==46080 and calls==used and diag.legal_subsets==381,'64 actions times all720 worlds, below original cap')
local reference,worlds=nil,0
for _,family in pairs(seen)do worlds=worlds+1;reference=reference or family
 local count=0;for key in pairs(family)do count=count+1;check(reference[key],'identical candidate family in every world')end
 check(count==64,'each world complete')
end
check(worlds==720 and Snap.fingerprint(s)==original,'all public worlds and immutable state')
check(not O.suggest(s,belief,{score=function()error('small cap')end},B,{max_evaluations=1000}),'caller cap retained')
local function tarot(key,negative)return {key=key,id=key,ability={set='Tarot'},sell_cost=negative and 4 or 1,edition=negative and {negative=true} or nil}end
local function stock()
 local q=state();q.phase='shop';q.teacher_profile='perkeo_yorick_win_v1';q.ante=6;q.blind={chips=0}
 q.jokers={{key='j_perkeo',ability={name='Perkeo'},sell_cost=10},{key='j_yorick',ability={name='Yorick',x_mult=6},sell_cost=10}}
 for _,c in ipairs(q.playing_cards)do c.enhancement='m_mult' end
 q.consumeables={tarot('c_empress',true),tarot('c_empress',true),{key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}},sell_cost=1}}
 q.consumable_limit=4;return q
end
s=stock();original=Snap.fingerprint(s)
local advice=T.manage_teacher_stock(s)
check(advice and advice.action.kind=='sell' and advice.action.index==1,'sell saturated Negative Empress instead of diluting useful planet pool')
check(Snap.fingerprint(s)==original,'stock planning immutable')
for _,c in ipairs(s.playing_cards)do c.face_down=true end
check(T.manage_teacher_stock(s).action.kind=='sell','shop face-down rendering does not erase public deck composition')
local integrated=D.run(s,{strategy=T,scoring=S,search=dofile(p..'search.lua')})
check(integrated.action and integrated.action.kind=='sell' and integrated.action.area=='consumeables','stock action survives production decision routing')
s=stock();s.teacher_profile=nil;check(not T.manage_teacher_stock(s),'normal collection objective unchanged')
s=stock();s.consumeables={tarot('c_hermit')};check(not T.manage_teacher_stock(s),'useful only template retained')
s=stock();s.consumeables={tarot('c_temperance'),tarot('c_temperance')};s.consumable_limit=2
advice=T.manage_teacher_stock(s);check(advice and advice.action.kind=='use','collect profitable duplicated Temperance before selling')
s=stock();s.used_vouchers={v_observatory=true};s.consumeables={s.consumeables[3],Snap.copy(s.consumeables[3])}
check(not T.manage_teacher_stock(s),'matching Observatory planets neither used nor sold by stock cleanup')
s=stock();s.consumeables={s.consumeables[3],Snap.copy(s.consumeables[3])}
advice=T.manage_teacher_stock(s);check(advice and advice.action.kind=='use','use surplus main-hand planet without Observatory')
s=stock();for _,c in ipairs(s.playing_cards)do c.enhancement='c_base' end
advice=T.manage_teacher_stock(s);check(not advice or advice.action.kind~='sell','useful enhancement stock is not surplus')
print('marathon_repairs366: '..n..' manufactured checks passed')
