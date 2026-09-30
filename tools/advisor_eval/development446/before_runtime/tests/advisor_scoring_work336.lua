-- Pure manufactured states only; no game, captured-state replay or search.
local before_path='tests/fixtures/advisor_scoring_reuse336/scoring_before.lua'
local candidate_path='Brainstorm/Advisor/scoring.lua'
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local checks,comparisons=0,0
--436 adds typed uncertainty alongside the already-compared Boolean/warnings.
-- This historical arithmetic/work oracle compares its original output surface;
-- the typed channel has explicit positive/negative tests in owned_lucky436.
local function legacy_surface(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do if k~='uncertainty' then out[k]=legacy_surface(x) end end;return out
end
local function eq(a,b,label)
    assert(Snap.fingerprint(legacy_surface(a))==Snap.fingerprint(legacy_surface(b)),label)
    checks=checks+1
end
local function truth(v,label) assert(v,label);checks=checks+1 end
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return (s:gsub('\r\n','\n')) end
local baseline_source=read(before_path)
local function literal_between(first,last)
    local a=assert(baseline_source:find(first,1,true))
    local _,b=assert(baseline_source:find(last,a,true))
    return baseline_source:sub(a,b)
end
local literals={
    enhancement=literal_between("{['Stone Card']='m_stone'","['Lucky Card']='m_lucky'}"),
    blind=literal_between("{bl_psychic='The Psychic'","bl_hook='The Hook'}"),
    classification_suits="{'Spades','Hearts','Clubs','Diamonds'}",
    seeing_double_suits="{'Clubs','Diamonds','Spades','Hearts'}",
    flower_pot_suits="{'Hearts','Diamonds','Spades','Clubs'}",
}
local function replace_once(source,old,new)
    local a,b=assert(source:find(old,1,true))
    assert(not source:find(old,b+1,true),'instrumentation site must be unique')
    return source:sub(1,a-1)..new..source:sub(b+1)
end
local function load_instrumented(path)
    local source=read(path)
    local counts={enh_calls=0,rank_calls=0,nominal_calls=0,lowest_visits=0,score_calls=0}
    for key,literal in pairs(literals) do
        counts[key]=0
        -- The literal argument is constructed before this count is incremented.
        source=replace_once(source,literal,"__allocation('"..key.."',"..literal..')')
    end
    source=replace_once(source,'local function enh(c)',
        'local function enh(c) __counts.enh_calls=__counts.enh_calls+1;')
    source=replace_once(source,'local function rank(c)',
        'local function rank(c) __counts.rank_calls=__counts.rank_calls+1;')
    source=replace_once(source,'local function nominal(c)',
        'local function nominal(c) __counts.nominal_calls=__counts.nominal_calls+1;')
    source=replace_once(source,'function M.score(snapshot, selected, transition, floor_mode, prepared)',
        'function M.score(snapshot, selected, transition, floor_mode, prepared) __counts.score_calls=__counts.score_calls+1;')
    local scan="for _,ci in ipairs(held) do local c=hand[ci]; if enh(c)~='m_stone'"
    source=replace_once(source,scan,
        "for _,ci in ipairs(held) do __counts.lowest_visits=__counts.lowest_visits+1; local c=hand[ci]; if enh(c)~='m_stone'")
    local chunk=assert(loadstring(source,'@'..path..':manufactured-instrumentation'))
    setfenv(chunk,setmetatable({__counts=counts,__allocation=function(key,value)
        counts[key]=counts[key]+1;return value
    end},{__index=_G}))
    return chunk(),counts
end
local Before,bc=load_instrumented(before_path)
local After,ac=load_instrumented(candidate_path)
local PlainBefore=dofile(before_path)
local PlainAfter=dofile(candidate_path)
local function card(id,r,s,enhancement)
    return {id=id,key='c_base',base={id=r,nominal=r==14 and 11 or math.min(r,10),suit=s},
        rank=r,suit=s,enhancement=enhancement,ability={}}
end
local function state()
    local s={hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},
        blind={key='bl_small',chips=500},dollars=13,chips=0,hand_size=8,hand_limit=5,
        hands_left=2,discards_left=3,hands_played=0,current_round={hands_played=0},
        probabilities={normal=1},modifiers={},used_vouchers={}}
    local ranks={14,14,13,12,10,5,3,2}
    local suits={'Spades','Hearts','Clubs','Diamonds'}
    for i,r in ipairs(ranks) do s.hand[i]=card(i,r,suits[(i-1)%4+1]);s.playing_cards[i]=s.hand[i] end
    for i=9,12 do local c=card(i,i,'Spades');s.deck[#s.deck+1]=c;s.playing_cards[#s.playing_cards+1]=c end
    return s
end
local function compare(s,selected,label,cached)
    local before=Snap.fingerprint(s)
    local left,right=Before,After
    if cached then left=Cache.new(Before);right=Cache.new(After) end
    local a,b=left.score(s,selected),right.score(s,selected)
    eq(a,b,label..' complete expected score');comparisons=comparisons+1
    eq(left.lower_bound(s,selected),right.lower_bound(s,selected),label..' complete floor')
    eq(left.upper_bound(s,selected),right.upper_bound(s,selected),label..' complete ceiling/guard')
    if cached then
        eq(left.score(s,selected),right.score(s,selected),label..' repeat classification reuse')
    end
    local ta,tb={},{}
    eq(Before.score(s,selected,ta),After.score(s,selected,tb),label..' transition score')
    eq(ta,tb,label..' ordered transition trace including cards/states/creation')
    eq(Snap.fingerprint(s),before,label..' input immutable')
end
local function combinations(n,limit,visit)
    local selected={}
    local function walk(first)
        if #selected>0 then visit(selected) end
        if #selected==limit then return end
        for i=first,n do selected[#selected+1]=i;walk(i+1);selected[#selected]=nil end
    end
    walk(1)
end
-- Normal exported plain cards have no explicit enhancement, so the fallback
-- enhancement map is exercised for every classification/scoring helper call.
local plain=state()
local start_b,start_a=Snap.copy(bc),Snap.copy(ac)
combinations(8,5,function(indices) compare(plain,indices,'plain subset',true) end)
local plain_counts={}
for key in pairs(bc) do plain_counts[key]={baseline=bc[key]-start_b[key],candidate=ac[key]-start_a[key]} end
eq(plain_counts.score_calls.baseline,plain_counts.score_calls.candidate,'no full scoring passes elided')
eq(plain_counts.lowest_visits.candidate,0,'no lowest-held scan without Raised Fist')
truth(plain_counts.lowest_visits.baseline>1000,'meaningful held-card traversal reduction')
truth(plain_counts.enhancement.baseline>10000,'meaningful repeated enhancement-map allocations')
eq(plain_counts.enhancement.candidate,0,'no per-score candidate enhancement-map construction')

local variants={
    {label='active alias Fist',jokers={{key='j_raised_fist'}}},
    {label='copied Fist',jokers={{key='j_blueprint'},{key='j_raised_fist'},{key='j_brainstorm'}}},
    {label='chained copied Fist',jokers={{key='j_blueprint'},{key='j_blueprint'},{key='j_raised_fist'}}},
    {label='debuffed Fist and copies',jokers={{key='j_blueprint'},{key='j_raised_fist',debuff=true},{key='j_brainstorm'}}},
    {label='debuffed copy active Fist',jokers={{key='j_blueprint',debuff=true},{key='j_raised_fist'}}},
    {label='incompatible copied Fist',jokers={{key='j_blueprint'},{key='j_raised_fist',blueprint_compat=false}}},
    {label='unknown copy target',jokers={{key='j_blueprint'},{key='j_unknown',ability={name='Unknown Effect'}}}},
    {label='ability name precedence',jokers={{key='j_raised_fist',ability={name='Joker',mult=4}}}},
    {label='custom key exact Fist name',jokers={{key='custom_effect',ability={name='Raised Fist'}}}},
    {label='copied custom key Fist',jokers={{key='j_blueprint'},{key='custom_effect',ability={name='Raised Fist'}}}},
    {label='name fallback Fist',jokers={{name='Raised Fist'}}},
    {label='cycle copies',jokers={{key='j_blueprint'},{key='j_brainstorm'}}},
    {label='suit consumers',jokers={{key='j_seeing_double'},{key='j_flower_pot'},{key='j_smeared'}}},
    {label='classification flags',jokers={{key='j_four_fingers'},{key='j_shortcut'},{key='j_splash'}}},
    {label='ordered before mutations',jokers={{key='j_midas_mask'},{key='j_vampire',ability={x_mult=1,extra=.1}},{key='j_hiker'}}},
    {label='created population',jokers={{key='j_dna'},{key='j_hologram',ability={x_mult=1,extra=.25}}}},
    {label='ordered Fist Baron',jokers={{key='j_raised_fist'},{key='j_baron'},{key='j_mime'}}},
    {label='ordered Baron Fist',jokers={{key='j_baron'},{key='j_raised_fist'},{key='j_mime'}}},
}
local selections={{1},{8},{1,2},{2,1},{1,3,4},{4,3,1},{1,2,3,4,5},{5,4,3,2,1}}
local active_fist={['active alias Fist']=true,['copied Fist']=true,['chained copied Fist']=true,
    ['debuffed copy active Fist']=true,['incompatible copied Fist']=true,
    ['custom key exact Fist name']=true,['copied custom key Fist']=true,['name fallback Fist']=true,
    ['ordered Fist Baron']=true,['ordered Baron Fist']=true}
for _,variant in ipairs(variants) do
    local s=state();s.jokers=variant.jokers
    -- Equal low ranks with different nominal values protect last-tie behavior;
    -- Stone/debuff/Steel and Red retriggers protect held-effect ordering.
    s.hand[6]=card(6,2,'Clubs');s.hand[6].nominal=7;s.hand[6].seal='Red'
    s.hand[7]=card(7,2,'Hearts');s.hand[7].nominal=9
    s.hand[8].enhancement='m_stone';s.hand[7].debuff=true
    s.hand[3].enhancement='m_steel';s.hand[4].enhancement='m_wild'
    s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
    for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
    local start_b,start_a=bc.lowest_visits,ac.lowest_visits
    for _,selection in ipairs(selections) do compare(s,selection,variant.label,true) end
    eq(ac.lowest_visits-start_a,active_fist[variant.label] and bc.lowest_visits-start_b or 0,
        variant.label..' exact guard visits including copied and debuffed routes')
    -- Instrumentation must preserve the uninstrumented behavior too.
    eq(Before.score(s,{1}),PlainBefore.score(s,{1}),variant.label..' baseline counter transparency')
    eq(After.score(s,{1}),PlainAfter.score(s,{1}),variant.label..' candidate counter transparency')
end
-- Every fallback enhancement, explicit precedence and warning branch.
for _,effect in ipairs({'Stone Card','Wild Card','Bonus','Mult','Glass Card','Steel Card','Gold Card','Lucky Card','Unknown Enhancement'}) do
    local s=state();s.hand[1].ability.effect=effect;s.hand[2].enhancement='m_steel'
    s.hand[3].key='m_glass';s.hand[3].ability.effect='Mult'
    s.hand[4].enhancement='m_unknown';s.hand[4].face_down=true
    s.hand[5].rank=nil;s.hand[5].base.id=nil
    s.consumeables={{edition={holo=true},ability={set='Planet',consumeable={hand_type='Pair'}}},
        {edition={polychrome=true},ability={set='Planet',consumeable={hand_type='Pair'}}}}
    s.used_vouchers.v_observatory=true
    compare(s,{1,2},effect,true);compare(s,{3,2,1},effect..' ordered',false)
    local reverse=Snap.copy(s);reverse.consumeables={s.consumeables[2],s.consumeables[1]}
    compare(reverse,{1,2},effect..' reversed retained inventory',true)
end
for _,blind in ipairs({
    {key='bl_psychic'},{key='bl_eye',hands={Pair=true}},
    {key='bl_mouth',only_hand='Flush'},{key='bl_flint'},{key='bl_arm'},
    {key='bl_ox'},{key='bl_tooth'},{key='bl_hook'},
    {key='bl_unknown'},{key='bl_psychic',name='The Tooth'},
    {key='bl_psychic',disabled=true},
}) do
    local s=state();s.blind=blind;s.current_round.most_played_poker_hand='Pair'
    s.hands.Pair={chips=40,mult=5,level=3,l_chips=15,l_mult=1}
    compare(s,{1,2},'blind '..blind.key,true)
end
-- The new slice has no table-identity assumptions. Mutating inputs between raw
-- calls must be observed. Existing prepared caches retain their immutable-
-- decision contract, so a changed state receives a fresh wrapper here.
local changing=state()
compare(changing,{1},'before in-place changes',true)
changing.jokers[1]={key='j_raised_fist'}
compare(changing,{1},'added Fist in same row table',true)
changing.jokers[1].debuff=true
compare(changing,{1},'debuffed Fist in place',true)
changing.jokers[1].debuff=false;changing.jokers[1].ability={name='Unknown Effect'}
changing.hand[8].ability.effect='Stone Card';changing.blind.key='bl_tooth'
changing.dollars=1;changing.deck[1].rank=2;changing.modifiers.debuff_played_cards=true
compare(changing,{1},'changed card blind money population unknown mechanics',true)
changing.hand[8].ability.effect='Steel Card';changing.hand[8].debuff=true
changing.hand[1],changing.hand[8]=changing.hand[8],changing.hand[1]
compare(changing,{8,1},'changed order and held effect',true)
changing.hand[2].ability.forced_selection=true
compare(changing,{1},'forced invalid selection',true)
compare(changing,{1,2},'forced legal selection',true)
compare(changing,{1,1},'duplicate invalid selection',true)
local all_played=state()
while #all_played.hand>5 do table.remove(all_played.hand) end
all_played.jokers={{key='j_raised_fist'}}
compare(all_played,{5,4,3,2,1},'no held cards',true)
compare(all_played,{},'empty invalid selection',true)

-- Numeric nominal values include zero, negative, NaN and infinities; the
-- original `c.nominal or base.nominal` precedence is preserved for false,
-- nonnumeric and absent inputs. Only rank's eager duplicate work is removed.
local nominal_variants={
    {label='explicit numeric',value=17,base=4},
    {label='explicit zero',value=0,base=4},
    {label='explicit negative',value=-3,base=4},
    {label='base numeric',base=6},
    {label='nonnumeric suppresses base',value='custom',base=6},
    {label='false selects base',value=false,base=6},
    {label='false base fallback',value=false,base=false},
    {label='omitted nominals'},
    {label='NaN nominal',value=0/0,base=6},
    {label='positive infinity nominal',value=math.huge,base=6},
    {label='negative infinity nominal',value=-math.huge,base=6},
}
for _,variant in ipairs(nominal_variants) do
    for _,kind in ipairs({'Ace','ordinary','Stone'}) do
        local s=state();local c=s.hand[1]
        c.rank=kind=='Ace' and 14 or 9;c.base.id=c.rank
        c.enhancement=kind=='Stone' and 'm_stone' or nil
        c.nominal=variant.value;c.base.nominal=variant.base
        compare(s,{1},variant.label..' '..kind,true)
        -- Exercise same-card in-place changes through direct calls and fresh
        -- prepared scopes, never retaining a nominal value across calls.
        c.nominal=variant.value==false and 0 or false;c.base.nominal=19
        c.rank=14;c.base.id=14
        compare(s,{1},variant.label..' '..kind..' in-place value/rank change',true)
    end
end

-- Sampled Lucky event traces and population mutation through after_play.
local lucky=state();lucky.hand[1].enhancement='m_lucky';lucky.hand[1].seal='Red'
local context={lucky_outcomes={[1]={{mult=true,dollars=false},{mult=false,dollars=true}}},glass_outcomes={}}
local na,ea=Before.after_play(lucky,{1},context)
local nb,eb=After.after_play(lucky,{1},context)
eq(na,nb,'sampled Lucky next state');eq(ea,eb,'sampled Lucky full effects')
local glass=state();glass.hand[1].enhancement='m_glass'
local ga,ge=Before.after_play(glass,{1},{glass_outcomes={[1]=true}})
local gb,gf=After.after_play(glass,{1},{glass_outcomes={[1]=true}})
eq(ga,gb,'Glass destruction complete population');eq(ge,gf,'Glass destruction effects')

for key in pairs(literals) do
    eq(ac[key],1,'candidate '..key..' literal allocated once at module load')
    truth(bc[key]>1,'baseline '..key..' repeated allocation measured')
end
eq(ac.score_calls,bc.score_calls,'all instrumented score invocations retained')
truth(ac.lowest_visits>0,'candidate retains Fist scans')
truth(ac.lowest_visits<bc.lowest_visits,'candidate skips only unnecessary Fist scans')
truth(ac.enh_calls<bc.enh_calls,'helper invocation reduction measured')
truth(ac.rank_calls<bc.rank_calls,'rank invocation reduction measured')
eq(ac.nominal_calls,bc.nominal_calls,'every nominal lookup retained')
print('scoring reuse checks='..checks..' complete comparison cases='..comparisons)
for _,key in ipairs({'score_calls','lowest_visits','enh_calls','rank_calls','nominal_calls','enhancement','blind','classification_suits','seeing_double_suits','flower_pot_suits'}) do
    print('all '..key..' baseline='..bc[key]..' candidate='..ac[key])
end
for _,key in ipairs({'score_calls','lowest_visits','enh_calls','rank_calls','nominal_calls','enhancement','blind'}) do
    print('plain '..key..' baseline='..plain_counts[key].baseline..' candidate='..plain_counts[key].candidate)
end
