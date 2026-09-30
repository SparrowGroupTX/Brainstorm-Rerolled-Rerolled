-- Pure source-adapter boundary semantics. Mirroring executable phases is tested
-- against execution.lua; score floors are deliberately distinct from exact scores.
local M={}
function M.trace_number(value)
    assert(type(value)=='number','Trace number expected')
    if value~=value then return '{"nonfinite_number":"nan"}' end
    if value==math.huge then return '{"nonfinite_number":"positive_infinity"}' end
    if value==-math.huge then return '{"nonfinite_number":"negative_infinity"}' end
    return tostring(value)
end
function M.trace_projection(result,sha256)
    local seen,strings={},{}
    local function project(value)
        if type(value)~='table' then return value end
        if seen[value] then return seen[value] end
        local out={};seen[value]=out
        for key,item in pairs(value) do
            if key=='observation_key' and type(item)=='string' and #item>128 then
                -- This is a repeated internal readiness cache key, not an
                -- action, sample, outcome or source replay fingerprint.
                if not strings[item] then strings[item]={trace_omitted='raw_cache_observation_key',
                    bytes=#item,sha256=sha256(item)} end
                out[key]=strings[item]
            else out[key]=project(item) end
        end
        return out
    end
    return project(result)
end
local phases={play={hand=true},discard={hand=true},buy={shop=true},open={shop=true},buy_and_use={shop=true},
    choose={pack=true},cash_out={round=true},leave_shop={shop=true},reroll={shop=true},skip_pack={pack=true},
    select_blind={blind=true},skip_blind={blind=true},reorder_hand={hand=true,pack=true},
    use={hand=true,shop=true,blind=true,pack=true,round=true},sell={hand=true,shop=true,blind=true,pack=true,round=true},
    reorder_jokers={hand=true,shop=true,blind=true,pack=true,round=true}}
function M.phase_allowed(kind,phase) return not not (phases[kind] and phases[kind][phase]) end
function M.select_cards(hand,indices,minimum,maximum,allow_forced)
    assert(hand and hand.cards and hand.highlighted and hand.config,'HEADLESS_BOUNDARY missing selectable hand')
    assert(type(indices)=='table','HEADLESS_BOUNDARY missing selected indices')
    local count,seen,wanted=#indices,{},{}
    assert(count>=minimum and count<=maximum,'HEADLESS_BOUNDARY invalid selection count')
    for key in pairs(indices) do
        assert(type(key)=='number' and key%1==0 and key>=1 and key<=count,'HEADLESS_BOUNDARY sparse selected indices')
    end
    for _,index in ipairs(indices) do
        assert(type(index)=='number' and index%1==0 and hand.cards[index] and not seen[hand.cards[index]],
            'HEADLESS_BOUNDARY invalid selected index')
        local card=hand.cards[index];seen[card]=true;wanted[#wanted+1]=card
    end
    for _,card in ipairs(hand.cards) do
        if card.ability and card.ability.forced_selection and not seen[card] then
            assert(allow_forced,'HEADLESS_BOUNDARY selected action omits forced card')
            seen[card]=true;wanted[#wanted+1]=card
        end
    end
    assert(#wanted<=(hand.config.highlighted_limit or 5),'HEADLESS_BOUNDARY selection exceeds highlight limit')
    hand:unhighlight_all()
    local retained={};for _,card in ipairs(hand.highlighted) do retained[card]=true end
    -- Original unhighlight_all retains forced cards, and add_to_highlighted does
    -- not deduplicate. Match product Execute instead of adding that object twice.
    for _,card in ipairs(wanted) do if not retained[card] then hand:add_to_highlighted(card,true) end end
    assert(#hand.highlighted==#wanted,'HEADLESS_BOUNDARY source rejected complete selection')
    local actual={}
    for _,card in ipairs(hand.highlighted) do
        assert(seen[card] and not actual[card],'HEADLESS_BOUNDARY source selected different cards')
        actual[card]=true
    end
    return wanted
end
function M.selected_prediction(snapshot,action,prediction,scoring)
    assert(action and action.kind=='play' and type(action.indices)=='table','Missing selected play')
    local matched=prediction and type(prediction.indices)=='table' and #prediction.indices==#action.indices
    if matched then for i,index in ipairs(action.indices) do
        if prediction.indices[i]~=index then matched=false;break end
    end end
    if matched then return prediction,'matching_advisor_play' end
    -- A specialist may replace the ordinary play without replacing result.play.
    -- This source-side verifier runs after the policy decision and never feeds
    -- its actual-state score or hidden identities back into action selection.
    return scoring.score(snapshot,action.indices),'selected_action_rescore'
end
function M.score_check(prediction,actual)
    local score=prediction and prediction.score
    if not prediction or prediction.uncertain then return true,'unverified_random_mean' end
    if type(score)~='number' or score~=score or math.abs(score)==math.huge or
        type(actual)~='number' or actual~=actual or math.abs(actual)==math.huge then return false,'invalid_score' end
    if prediction.reliable_bound and prediction.bound_kind=='supported_random_floor' then
        return actual>=score,'supported_random_floor'
    end
    if prediction.reliable_bound or prediction.bound_kind then return false,'unknown_score_bound' end
    return actual==score,'deterministic_score'
end
return M
