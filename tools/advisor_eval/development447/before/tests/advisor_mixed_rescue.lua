local M=dofile('Brainstorm/Advisor/mixed_rescue.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local modules={consumables=C,scoring=S,strategy=Strategy}
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function state()
    local card={id='p1',rank=14,suit='Spades',nominal=11,ability={}}
    return {phase='hand',hand={card},playing_cards={card},deck={},jokers={
        {key='j_cavendish',id='j1',ability={name='Cavendish',extra={Xmult=3}}},
        {key='j_joker',id='j2',ability={name='Joker',mult=4}}},
        consumeables={{key='c_pluto',ability={set='Planet',consumeable={hand_type='High Card'}}}},
        hands={},dollars=10,ante=3,blind={chips=350},chips=0,hands_left=1,discards_left=0,
        current_round={hands_left=1,hands_played=0},probabilities={normal=1},hand_limit=5,hand_size=1,modifiers={}}
end
local function base(s) local p=S.score(s,{1});p.indices={1};return {kind='play',play=p} end
local function rearrange(s,order)
    local t=Snapshot.copy(s);t.jokers={};for _,old in ipairs(order) do t.jokers[#t.jokers+1]=Snapshot.copy(s.jokers[old]) end;return t
end
local old_random=math.random;math.random=function() error('Mixed rescue used global RNG') end
do
    local s=state();local fingerprint=Snapshot.fingerprint(s)
    local r,count,diag=M.suggest(s,modules,base(s))
    check(r and r.action.kind=='reorder_jokers','joint tactic emits executable reorder first')
    check(table.concat(r.action.order,',')=='2,1','additive Mult is moved before XMult')
    check(r.play.score==468 and r.reorder_play.score==240 and r.consumable_only_play.score==260,'all three outcomes are independently fully scored')
    check(count==4 and diag.completed_comparisons==4,'minimal rescue needs only four complete scores')
    check(r.sequence.index==1 and r.sequence.name=='Pluto' and not r.action.followup,'projected use is descriptive metadata, never queued gameplay')
    check(Snapshot.fingerprint(s)==fingerprint,'joint projection leaves snapshot unchanged')
    check(Snapshot.fingerprint(r)==Snapshot.fingerprint(M.suggest(s,modules,base(s))),'unchanged state gives identical result')
    local after=rearrange(s,r.action.order)
    check(M.suggest(after,modules,base(after))==nil,'after reorder the module does not reverse or repeat the setup')
    local use=C.suggest(after,S,base(after),nil,{strategy=Strategy})
    check(use and use.action.kind=='use' and use.play.score==468,'fresh ordinary consumable advice supplies concrete second step')
    local played=assert(C.apply(after,use.action.index,use.action.targets))
    check(S.score(played,{1}).score==468,'final detached play reproduces the promised joint score')
    check(M.suggest(after,modules,{play=base(after).play,consumable=use})==nil,'existing consumable clear wins before any mixed exploration')
end
do
    local s=state();s.blind.chips=200
    check(M.suggest(s,modules,base(s))==nil,'reorder alone does not trigger consumable setup')
    s.blind.chips=250
    check(M.suggest(s,modules,base(s))==nil,'consumable alone does not trigger unnecessary reorder')
    s.blind.chips=100
    local r,count=M.suggest(s,modules,base(s))
    check(not r and count==0,'existing reliable play clears without work')
    s=state();s.jokers[1].pinned=true
    check(M.suggest(s,modules,base(s))==nil,'pinned position blocks illegal two-card swap')
    s=state();s.jokers[1].face_down=true
    check(M.suggest(s,modules,base(s))==nil,'concealed row prevents reorder speculation')
    s=state();s.blind.key='bl_final_acorn'
    check(M.suggest(s,modules,base(s))==nil,'Acorn shuffle forbids order setup')
    s=state();s.ordering_safe=false
    check(M.suggest(s,modules,base(s))==nil,'moving Joker row is not used')
    s=state();s.hands_left=0
    check(M.suggest(s,modules,base(s))==nil,'no play resource means no rescue')
end
do
    local s=state();local r,count,diag=M.suggest(s,modules,base(s),nil,{max_evaluations=3})
    check(not r and count==3 and diag.truncated,'budget ends without treating unfinished joint candidate as evidence')
    r,count=M.suggest(s,modules,base(s),nil,{max_evaluations=0})
    check(not r and count==0,'zero budget performs no scoring')
    s.jokers[1].ability.name='Unknown Custom'
    check(M.suggest(s,modules,{})==nil,'unmodeled scorer warnings cannot establish a joint clear')
    s=state();local fake={strategy=Strategy,consumables=C,scoring={score=function(t,indices)
        local p=S.score(t,indices);p.uncertain=true;return p
    end}}
    check(M.suggest(s,fake,{})==nil,'uncertain expected score never certifies a combined clear')
end
do
    local s=state();s.jokers[3]={key='j_egg',id='j3',ability={name='Egg'},pinned=true}
    local r=M.suggest(s,modules,base(s))
    check(r and r.action.order[3]==3,'legal movable prefix preserves an unrelated pinned slot')
    s=state();local fake={strategy=Strategy,scoring=S,consumables={rescue_candidates=function()
        local t=assert(C.apply(s,1,{}));table.remove(t.hand,1)
        return {{state=t,index=1,targets={},name='Changed population'}}
    end}}
    check(M.suggest(s,fake,base(s))==nil,'hand population changes need a distinct mapping and are not falsely compared')
end
do
    local s=state();s.blind.chips=210
    s.jokers={s.jokers[2],{key='j_blueprint',id='copy',ability={name='Blueprint'}},
        {key='j_egg',id='egg',ability={name='Egg'},pinned=true}}
    local r=M.suggest(s,modules,base(s))
    check(r and r.play.score==260 and table.concat(r.action.order,',')=='2,1,3','joint planner handles copy-target setup rather than only Mult sorting')
    s=state();s.blind.chips=1000000000
    for i=2,12 do s.hand[i]={id='p'..i,rank=2+i%13,suit='Hearts',ability={}} end
    for i=3,8 do s.jokers[i]={id='j'..i,key='j_joker',ability={mult=4}} end
    local fake={strategy=Strategy,scoring={score=function() return {score=1,hand='High Card'} end},
        consumables={rescue_candidates=function()
            local out={};for i=1,8 do out[i]={state=Snapshot.copy(s),index=i,targets={},name='Bound test'} end;return out
        end}}
    local r,count,diag=M.suggest(s,fake,{},nil,{max_evaluations=999999,max_subsets=999,max_orders=999,max_candidates=999})
    check(not r and count==1152 and count<=1500,'all candidate/layout/subset caps remain enforced under oversized requested budgets')
    check(diag.completed_comparisons==72 and not diag.truncated,'bounded maximum completes only complete comparison sets')
end
math.random=old_random
print('advisor_mixed_rescue: '..checks..' checks passed')
