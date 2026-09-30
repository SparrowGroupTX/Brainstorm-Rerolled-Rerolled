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
local tight=D.run(state(),modules,nil,{search={fast_clear=true,max_evaluations=1}})
check(tight.evaluations<=1,'real fast search and exhaustion share a one-score caller cap')
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

s=state();s.hand[2].enhancement='m_steel';s.hand[2].ability.h_x_mult=1.5;s.hand[3].seal='Blue';s.blind.chips=1620
r=D.run(s,modules,nil,options)
check(r.action.kind=='discard','held Steel clear can retain a safe alternative: '..tostring(r.discard_before_clear and r.discard_before_clear.reason))
for _,i in ipairs(r.action.indices) do check(i~=1 and i~=2 and i~=3,'keep clearing Ace, required Steel and valuable Blue Seal') end
for _,row in ipairs({
 {key='j_green_joker',ability={name='Green Joker',mult=100,extra={hand_add=1,discard_sub=1}}},
 {key='j_banner',ability={name='Banner',extra=30}},
 {key='j_ramen',ability={name='Ramen',x_mult=2,extra=0.01}}
}) do
 s=state();s.jokers={row};s.blind.chips=S.score(s,{1}).score
 r=D.run(s,modules,nil,options)
 check(r.action.kind=='play' and r.discard_before_clear.status=='exception',row.key..' cannot destroy a barely supported clear')
 check(r.discard_before_clear.reason~=nil,'exception is explained')
end
s=state();s.modifiers.discard_cost=1
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and r.discard_before_clear.reason=='Discarding spends current cash.','paid-discard resource exception')
s=state();s.blind.key='bl_final_bell';s.hand[1].ability.forced_selection=true
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and r.discard_before_clear.status=='exception','forced clearing card is not illegally omitted from discard')
s=state();for i=2,#s.hand do s.hand[i].seal='Purple' end
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and r.discard_before_clear.reason:find('Purple Seal',1,true),'unsupported generation is a model gap, not a fabricated draw')
s=state();s.hand={s.hand[1]};s.hand_size=1
r=D.run(s,modules,nil,options)
check(r.action.kind=='play' and r.discard_before_clear.status=='exception','sole physical clear is not discarded blindly')

-- Inject only the final-arbitration proposal; transitions and scoring remain real.
local function selected(snapshot,indices,reported,extras)
 local play=S.score(snapshot,reported or indices);play.indices=reported or indices
 local result={kind='play',play=play,action={kind='play',area='hand',indices=indices},evaluations=0}
 for k,v in pairs(extras or {}) do result[k]=v end
 return result
end
local function seam(s,indices,reported,extras,opts,more)
 local m={scoring=S,growth=Growth,strategy=Strategy,search={run=function() return selected(s,indices,reported,extras) end},
  phase_copy={apply=function(_,_,result) result.action={kind='play',area='hand',indices=indices};return result end}}
 for k,v in pairs(more or {}) do m[k]=v end
 return D.run(s,m,nil,opts or {})
end
s=state()
r=seam(s,{2},{1})
check(r.action.kind=='play' and r.action.indices[1]==2,'stale clearing proposal does not replace a nonclearing actual action')
check(r.discard_before_clear.evaluations==2 and r.evaluations==2,'floor and upper-bound rescore work appears in final receipt')
check(r.discard_before_clear.reason=='selected_play_cannot_clear','bounded nonclear is not mislabeled possible random clear')
r=seam(s,{1},{2})
check(r.action.kind=='discard','actual clearing action is checked despite nonclearing stored proposal')
check(r.evaluations<=12 and r.discard_before_clear.evaluations<=12,'rescore and growth share one12-call allowance')
r=seam(s,{1},{1},{evaluations=70},{search={max_evaluations=70}})
check(r.action.kind=='play' and r.discard_before_clear.category=='work_limit' and r.evaluations==70,'no allowance renewal at caller cap')
r=seam(s,{1},{1},nil,{retry={unavailable=true}})
check(r.action==nil,'unavailable retry remains blocked')
r=seam(s,{1},{1},nil,{retry={active=true}}, {retry_policy={apply=function(_,result) return result end}})
check(r.action.kind=='play' and r.discard_before_clear.category=='retry_constraint','recorded retry is not silently changed')
r=seam(s,{1},{1},nil,{}, {phase_copy={apply=function(_,_,result) result.action={kind='play',indices={2},area='hand'};return result end}})
check(r.action.kind=='play' and r.action.indices[1]==2,'guard follows final copy arbitration')

local hidden=state();hidden.jokers={{face_down=true,identity_redacted=true}}
hidden.public_joker_belief={worlds={{}},epoch=1,revision=1}
local no_hidden_score=function() error('raw hidden Joker score reached') end
r=D.run(hidden,{scoring={score=no_hidden_score},acorn_belief={validate=function() return true end},
 acorn_ordering={suggest=function() return {kind='play',action={kind='play',area='hand',indices={1}},minimum_score=2000,mean_score=2000,immediate_clear_all_worlds=true},0,{} end}})
check(r.action.kind=='play' and r.discard_before_clear.category=='public_model_gap','Acorn uses explicit public-model exception without raw hidden scoring')
r=D.run(state(),{scoring={score=no_hidden_score},concealed_belief={run=function()
 return {kind='play',action={kind='play',area='hand',indices={1}},concealed_belief={supported=true},evaluations=0}
end}})
check(r.discard_before_clear.category=='public_model_gap','concealed sampled clear is not called a guaranteed retained clear')

local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local compact=Journal.compact_discard_before_clear({discard_before_clear={status='exception',reason='fixture',
 remaining_discards=3,worlds={{secret=true}},snapshot=state(),evaluations=0/0}})
check(compact.status=='exception' and compact.worlds==nil and compact.snapshot==nil and compact.evaluations==nil,'public receipt strips nested states and nonfinite values')
-- Smaller anchor probes must not newly spend a valuable held first card.
for _,field in ipairs({'gold','blue'}) do
 s=state();s.ante=2;s.blind.boss=false;s.blind.chips=600
 if field=='gold' then s.hand[1].enhancement='m_gold';s.hand[1].ability.h_dollars=3 else s.hand[1].seal='Blue' end
 local original=S.score(s,{2,3});original.indices={2,3}
 local g,n,d=Growth.suggest(s,modules,original,{exhaust_discards=true,max_evaluations=12})
 check(g and g.action.kind=='discard' and d.smaller_anchor,field..' case admits a smaller resource-safe anchor')
 check(g.growth.retained_original_indices[1]~=1,field..' held first card cannot become new reserved play')
 for _,i in ipairs(g.action.indices) do check(i~=1,field..' held resource survives discard') end
 check(n<=12,'anchor and discard resource checks retain12-call limit')
end
print('advisor_discard_before_clear410: '..checks..' checks passed')
