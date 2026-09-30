local C=dofile('tools/advisor_eval/engine_contract.lua')
local E=dofile('Brainstorm/Advisor/execution.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
for _,phase in ipairs({'hand','shop','blind','pack','round'}) do
    local states={hand=1,shop=2,blind=3,pack=4,round=5}
    local a={pinned=true,facing='front',states={drag={can=true}}}
    local b={facing='front',states={drag={can=true}}}
    local c={facing='front',states={drag={can=true}}}
    local area={cards={a,b,c},align_cards=function() end,set_ranks=function() end}
    local g={GAME={},STATE=states[phase],STATES={SELECTING_HAND=1,SHOP=2,BLIND_SELECT=3,TAROT_PACK=4,ROUND_EVAL=5},FUNCS={},jokers=area}
    local ok,why=E.execute(g,{kind='reorder_jokers',order={1,3,2}})
    check(ok==C.phase_allowed('reorder_jokers',phase),'source adapter agrees with executable Joker reorder in '..phase..': '..tostring(why))
    check(area.cards[1]==a and area.cards[2]==c,'accepted phase preserves pins and desired row')
end
check(not C.phase_allowed('reorder_hand','blind'),'hand reorder remains unavailable before blind')
check(C.phase_allowed('buy_and_use','shop') and not C.phase_allowed('buy_and_use','hand'),'buy-and-use is shop-only')
check(C.score_check({score=1134,reliable_bound=true,bound_kind='supported_random_floor'},1944),'recorded Misprint actual above supported floor is valid')
check(not C.score_check({score=1134,reliable_bound=true,bound_kind='supported_random_floor'},1133),'source below promised floor is a real parity defect')
check(C.score_check({score=1134},1134),'deterministic score still requires equality')
check(not C.score_check({score=1134},1944),'ordinary deterministic disagreement is not hidden by floor support')
check(not C.score_check({score=1134,reliable_bound=true,bound_kind='modded_claim'},1944),'unknown bound labels are rejected')
check(C.score_check({score=2065,uncertain=true},1944),'unrealized mean is not an exact parity assertion')
check(not C.score_check({score=0/0},1944),'NaN cannot verify deterministic parity')
local floor={indices={1},score=1134,reliable_bound=true,bound_kind='supported_random_floor'}
local called=0
local scorer={score=function(s,indices) called=called+1;return {indices=indices,score=1944} end}
local prediction,source=C.selected_prediction({},{kind='play',indices={1}},floor,scorer)
check(prediction==floor and called==0 and source=='matching_advisor_play','matching selected action preserves certified random floor')
prediction,source=C.selected_prediction({},{kind='play',indices={2}},floor,scorer)
check(prediction.score==1944 and prediction.indices[1]==2 and called==1 and source=='selected_action_rescore',
    'specialist action is verified against its actual indices instead of stale ordinary play')
prediction=C.selected_prediction({},{kind='play',indices={1}},nil,scorer)
check(prediction.score==1944 and called==2,'missing ordinary play receives post-decision verification only')
local function hand(limit)
    local cards={{ability={forced_selection=true}},{ability={}},{ability={}}}
    local area={cards=cards,highlighted={cards[1]},config={highlighted_limit=limit or 5}}
    function area:unhighlight_all()
        for i=#self.highlighted,1,-1 do
            if not self.highlighted[i].ability.forced_selection then table.remove(self.highlighted,i) end
        end
    end
    function area:add_to_highlighted(card)
        if #self.highlighted<self.config.highlighted_limit then self.highlighted[#self.highlighted+1]=card end
    end
    return area
end
local h=hand()
C.select_cards(h,{1,2},1,5,false)
check(#h.highlighted==2 and h.highlighted[1]==h.cards[1] and h.highlighted[2]==h.cards[2],
    'retained forced card is selected exactly once, with complete requested membership')
check(not pcall(C.select_cards,h,{2},1,5,false) and #h.highlighted==2,
    'omitting forced card rejects before changing a play or discard selection')
C.select_cards(h,{},0,0,true)
check(#h.highlighted==1 and h.highlighted[1]==h.cards[1],'zero-target consumable keeps original forced selection')
check(not pcall(C.select_cards,h,{2},1,2,false),'targeted consumable cannot silently add an omitted forced target')
C.select_cards(h,{1,2},1,2,false)
check(#h.highlighted==2,'targeted consumable including forced card preserves exact targets')
for _,invalid in ipairs({{1,1},{0},{1.5},{4},{[1]=1,[3]=2},{1,unexpected=2},{}}) do
    check(not pcall(C.select_cards,h,invalid,1,5,false),'malformed or empty play selection fails closed')
end
check(not pcall(C.select_cards,hand(1),{1,2},1,5,false),'highlight limit cannot silently truncate requested cards')
local rejecting=hand();rejecting.add_to_highlighted=function() end
check(not pcall(C.select_cards,rejecting,{1,2},1,5,false),'source refusing one requested card cannot verify a partial selection')
-- Exercise the product executor against the same source-like retained selection.
for _,action in ipairs({{kind='play',indices={1,2}},{kind='discard',indices={1,2}},
    {kind='play',indices={2}},{kind='discard',indices={2}}}) do
    local actual=hand()
    local g={GAME={current_round={hands_left=1}},STATE=1,STATES={SELECTING_HAND=1},hand=actual,FUNCS={}}
    g.FUNCS.can_play=function(e) e.config.button='play_cards_from_highlighted' end
    g.FUNCS.can_discard=function(e) e.config.button='discard_cards_from_highlighted' end
    g.FUNCS.play_cards_from_highlighted=function() end
    g.FUNCS.discard_cards_from_highlighted=function() end
    local accepted=E.execute(g,action)
    local adapter=pcall(C.select_cards,hand(),action.indices,1,5,false)
    check(accepted==adapter,'adapter and product agree on forced '..action.kind..' admission')
end
print('advisor_engine_contract: '..checks..' checks passed')
