-- A small intersection of consumable and Joker-order tactics. Publish only a
-- fully scored joint clear that neither single action provides on the common
-- subset set. Execute reorders first; the next settled decision chooses use.
local M={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function shallow(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function list(t) local out={};for i,v in ipairs(t or {}) do out[i]=v end;return out end
local function pinned(j) return j.pinned or (j.ability or {}).pinned end
local function name(j) return j.name or (j.ability or {}).name or j.key or 'Joker' end
local function reliable(p,target)
    if not p or p.legal==false or p.uncertain or type(p.score)~='number' or p.score~=p.score or p.score==math.huge then return false end
    for _,w in ipairs(p.warnings or {}) do
        local s=tostring(w):lower()
        if s:find('unmodeled',1,true) or s:find('not modeled',1,true) or s:find('not included',1,true) or s:find('unknown card',1,true) then return false end
    end
    return p.score>=target
end
local function same_layout(s,t)
    if #(s.hand or {})~=#(t.hand or {}) or #(s.jokers or {})~=#(t.jokers or {}) then return false end
    for _,field in ipairs({'hand','jokers'}) do for i,c in ipairs(s[field]) do
        local other=t[field][i]
        if c.id~=other.id or field=='jokers' and c.key~=other.key then return false end
    end end
    return true
end
local function orders(row,limit)
    local identity,free,out,seen={},{},{},{}
    for i,j in ipairs(row) do identity[i]=i;if not pinned(j) then free[#free+1]=i end end
    local function add(order)
        local key=table.concat(order,',')
        if not seen[key] and #out<limit then seen[key]=true;out[#out+1]=list(order) end
    end
    add(identity)
    local function tier(j)
        local a=j.ability or {};local e=type(a.extra)=='table' and a.extra or {}
        if num(a.mult)>0 or num(a.t_mult)>0 then return 1 end
        if num(a.x_mult,num(e.Xmult,1))>1 then return 3 end
        return 2
    end
    local sorted=list(free)
    table.sort(sorted,function(a,b) local x,y=tier(row[a]),tier(row[b]);return x==y and a<b or x<y end)
    local arranged=list(identity);for i,pos in ipairs(free) do arranged[pos]=sorted[i] end;add(arranged)
    for _,a in ipairs(free) do for _,b in ipairs(free) do if a<b then
        local order=list(identity);order[a],order[b]=order[b],order[a];add(order)
    end end end
    return out
end
local function subsets(s,base,limit)
    local out,seen,forced={},{},{}
    for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then forced[i]=true end end
    local maximum=math.min(5,num(s.hand_limit,5))
    local function add(selected)
        if not selected or #selected==0 or #selected>maximum or #out>=limit then return end
        local v=list(selected);table.sort(v);local chosen={}
        for _,i in ipairs(v) do if not s.hand[i] or chosen[i] then return end;chosen[i]=true end
        for i in pairs(forced) do if not chosen[i] then return end end
        local key=table.concat(v,',');if not seen[key] then seen[key]=true;out[#out+1]=v end
    end
    add(base.play and base.play.indices)
    local categories={}
    for _,p in ipairs(base.alternatives or {}) do if not categories[p.hand or ''] then categories[p.hand or '']=true;add(p.indices) end end
    local ranks,suits={},{ }
    for i,c in ipairs(s.hand) do
        local rank=num(c.rank,num((c.base or {}).id))
        ranks[rank]=ranks[rank] or {};ranks[rank][#ranks[rank]+1]=i
        local suit=c.suit or (c.base or {}).suit or ''
        suits[suit]=suits[suit] or {};suits[suit][#suits[suit]+1]=i
    end
    for r=2,14 do local group=ranks[r];if group then local picked={};for i=1,math.min(maximum,#group) do picked[#picked+1]=group[i] end;add(picked) end end
    for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
        local group=suits[suit];if group and #group>=maximum then local picked={};for i=1,maximum do picked[i]=group[i] end;add(picked) end
    end
    for i=1,#s.hand do add({i}) end
    for i=1,#s.hand do for j=i+1,#s.hand do add({i,j}) end end
    for _,p in ipairs(base.alternatives or {}) do add(p.indices) end
    return out
end
local function reordered(s,order)
    local state=shallow(s);state.jokers={}
    for i,old in ipairs(order) do state.jokers[i]=s.jokers[old] end
    return state
end

function M.suggest(snapshot,modules,base_result,yield_fn,options)
    local s,base=snapshot or {},base_result or {};options=options or {}
    local diag={evaluations=0,completed_comparisons=0,truncated=false,candidates=0,orders=0}
    local function stop(reason) diag.reason=reason;return nil,diag.evaluations,diag end
    if s.phase~='hand' or not modules or not modules.scoring or not modules.consumables or
        not modules.consumables.rescue_candidates or num(s.hands_left)<=0 then return stop('No settled mixed-action rescue is available.') end
    local target=num((s.blind or {}).chips)-num(s.chips)
    if target<=0 or target~=target or target==math.huge then return stop('No finite remaining blind target.') end
    for _,key in ipairs({'play','consumable','ordering','hand_ordering','boss_rescue'}) do
        local candidate=base[key]
        if reliable(key=='play' and candidate or candidate and (candidate.sequence and candidate.sequence.play or candidate.play),target) then
            return stop('An existing supported single-action plan already clears.')
        end
    end
    local blind=s.blind or {}
    if #((s.hand) or {})==0 or #s.hand>12 or #(s.jokers or {})<2 or #s.jokers>8 or
        s.jokers_shuffling or blind.shuffle_pending or s.ordering_safe==false or
        not blind.disabled and (blind.key=='bl_final_acorn' or blind.name=='Amber Acorn') then return stop('Row size or unsettled movement prevents a bounded reorder.') end
    for _,j in ipairs(s.jokers) do if j.face_down or j.facing=='back' then return stop('The Joker order is concealed.') end end
    local selections=subsets(s,base,math.max(1,math.min(16,math.floor(num(options.max_subsets,16)))))
    local layouts=orders(s.jokers,math.max(1,math.min(8,math.floor(num(options.max_orders,8)))))
    diag.subsets=#selections;diag.orders=#layouts
    if #layouts<2 or #selections==0 then return stop('No legal alternative order or common hand subset.') end
    local budget=math.max(0,math.min(1500,math.floor(num(options.max_evaluations,1500))))
    local function profile(state)
        if diag.evaluations+#selections>budget then diag.truncated=true;return nil,false end
        local best
        for _,indices in ipairs(selections) do
            local p=modules.scoring.score(state,indices);diag.evaluations=diag.evaluations+1
            if reliable(p,0) and (not best or p.score>best.score) then best=shallow(p);best.indices=list(indices) end
            if yield_fn and diag.evaluations%32==0 then yield_fn() end
        end
        diag.completed_comparisons=diag.completed_comparisons+1
        return best,true
    end
    local unconsumed={}
    for i,order in ipairs(layouts) do
        local p,complete=profile(reordered(s,order))
        if not complete then return stop('Budget ended before a full independent reorder comparison.') end
        if reliable(p,target) then return stop('Reordering alone supplies a checked clear; no consumable sequence is needed.') end
        unconsumed[i]=p or false
    end
    local candidates=modules.consumables.rescue_candidates(s,modules.strategy,
        math.max(0,math.min(8,math.floor(num(options.max_candidates,8)))))
    diag.candidates=#candidates
    for _,candidate in ipairs(candidates) do if same_layout(s,candidate.state) then
        local alone,complete=profile(candidate.state)
        if not complete then return stop('Budget ended before a complete consumable comparison.') end
        if reliable(alone,target) then return stop('The consumable alone supplies a checked clear; no extra reorder is needed.') end
        for i=2,#layouts do
            local play,finished=profile(reordered(candidate.state,layouts[i]))
            if not finished then return stop('Budget ended before a complete joint comparison.') end
            if reliable(play,target) then
                local labels={};for _,old in ipairs(layouts[i]) do labels[#labels+1]='#'..old..' '..name(s.jokers[old]) end
                local targets=#candidate.targets>0 and (' on hand card(s) '..table.concat(candidate.targets,', ')) or ''
                local suggestion={kind='mixed_rescue',title='Reorder Jokers to set up '..candidate.name,
                    lines={table.concat(labels,' -> '),
                        'Reorder first, then refresh advice. The projected next step is '..candidate.name..targets..'.',
                        'Together these changes enable '..play.hand..' at '..math.floor(play.score+0.5)..' chips; neither checked single action reaches the remaining target.',
                        'Only the reorder is executed. The use and play require fresh recommendations after each state change.'},
                    warnings={'The detached model verifies this joint clear on a bounded subset shortlist; future draws and longer action chains are not searched.'},
                    action={kind='reorder_jokers',order=list(layouts[i])},play=play,projected_play=play,
                    reorder_play=unconsumed[i] or nil,consumable_only_play=alone,
                    sequence={index=candidate.index,name=candidate.name,targets=list(candidate.targets),play=play}}
                diag.reason='A fully scored consumable plus Joker reorder jointly rescues the current blind.'
                return suggestion,diag.evaluations,diag
            end
        end
    end end
    return stop('No supported joint clear was found within the bounded combinations.')
end
return M
