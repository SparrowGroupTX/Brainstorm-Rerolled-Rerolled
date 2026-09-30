local D=dofile('Brainstorm/Advisor/decision.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local modules={scoring=S,search=Search,growth=Growth,strategy=Strategy}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function card(id,rank) return {id=id,rank=rank,suit='Spades',enhancement='c_base',ability={}} end
local function state()
 local s={phase='hand',teacher_profile='perkeo_yorick_win_v1',ante=8,win_ante=8,
  blind={key='bl_big',chips=1600,boss=true},chips=0,hands_left=3,hands_played=0,
  discards_left=3,discards_used=0,current_round={},dollars=20,hand_limit=5,hand_size=5,
  hand={card('a',14),card('b',2),card('c',3),card('d',4),card('e',6)},deck={},playing_cards={},
  jokers={{id='j',key='j_joker',ability={name='Joker',mult=100}}},consumeables={},hands={},modifiers={},probabilities={normal=1}}
 for i=1,15 do s.deck[i]=card('d'..i,2+i%8) end
 for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
 return s
end
local options={search={fast_clear=true}}
local s=state();local before=Snapshot.fingerprint(s)
local r=D.run(s,modules,nil,options)
check(r.action and r.action.kind=='discard','teacher final-Boss clear spends a discard despite no growth engine and under5% margin')
check(Snapshot.fingerprint(s)==before,'decision preserves input')
check(r.evaluations<=70,'fast-clear allowance preserved')
check(r.discard_before_clear.selected and r.discard_before_clear.remaining_discards==3,'final discard receipt')
check(r.growth.growth.utility<=0,'negative optional-development merit no longer vetoes safe discard')
check(r.growth.play.score>=1600,'retained clear is a real supported score')
check(#r.action.indices==4,'maximal spare discard retains the Ace clear')
check(Snapshot.fingerprint(r)==Snapshot.fingerprint(D.run(s,modules,nil,options)),'deterministic result')
for n=3,1,-1 do
 r=D.run(s,modules,nil,options)
 check(r.action.kind=='discard' and s.discards_left==n,'use each remaining discard')
 local retained=s.hand[1].id
 s=assert(S.after_discard(s,r.action.indices))
 while #s.hand<s.hand_size and #s.deck>0 do s.hand[#s.hand+1]=table.remove(s.deck,1) end
 check(s.hand[1].id==retained,'physical clearing card survives each real manufactured draw')
end
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and s.discards_left==0,'finish after exhausting discards')

s=state();s.blind.chips=S.score(s,{1}).score
r=D.run(s,modules,nil,options)
check(r.action.kind=='discard','exact target is enough with a supported retained floor')
s=state();s.deck={};s.playing_cards=Snapshot.copy(s.hand)
r=D.run(s,modules,nil,options)
check(r.action.kind=='discard','empty deck alone does not prohibit legal retained-card discard')
s=state();s.ante=2;s.blind.boss=false
s.jokers[#s.jokers+1]={key='j_yorick',id='y',ability={name='Yorick',x_mult=20,yorick_discards=23,extra={discards=23,xmult=1}}}
r=D.run(s,modules,nil,options)
check(r.action.kind=='discard','distant mature Yorick threshold is not a reason to leave discards')

s=state();s.teacher_profile=nil
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and r.discard_before_clear==nil,'ordinary profile unchanged')
s=state();s.discards_left=0
check(D.run(s,modules,nil,options).action.kind=='play','no-discard control')
s=state();s.hand_limit=1
r=D.run(s,modules,nil,options)
check(r.action.kind=='discard' and #r.action.indices==1,'actual highlight limit respected')

s=state();s.hand[2].enhancement='m_steel';s.hand[2].ability.h_x_mult=1.5;s.hand[3].seal='Blue';s.blind.chips=2300
r=D.run(s,modules,nil,options)

for i=1,#s.hand do local p=S.lower_bound(s,{i});print(i,p.score,p.legal,p.uncertain,table.concat(p.warnings or {},";")) end
local p=S.score(s,{1});p.indices={1};local g,n,d=Growth.suggest(s,modules,p,{exhaust_discards=true,max_evaluations=12});print("growth",g,n,table.concat(d.reasons,";"))
