-- Detached, deterministic vanilla scoring model. Never calls a game callback or RNG.
-- Input cards and joker order are the order they will resolve in the game.
-- Random effects use their mean; warnings describe incomplete/uncertain effects.
local M = {}
-- Immutable lookup data; no card, row or score results are retained.
local enhancement_effects={['Stone Card']='m_stone',['Wild Card']='m_wild',['Bonus']='m_bonus',['Mult']='m_mult',
          ['Glass Card']='m_glass',['Steel Card']='m_steel',['Gold Card']='m_gold',['Lucky Card']='m_lucky'}
local score_blind_names={bl_psychic='The Psychic',bl_eye='The Eye',bl_mouth='The Mouth',bl_flint='The Flint',bl_arm='The Arm',bl_ox='The Ox',bl_tooth='The Tooth',bl_hook='The Hook'}
local classification_suits={'Spades','Hearts','Clubs','Diamonds'}
local seeing_double_suits={'Clubs','Diamonds','Spades','Hearts'}
local flower_pot_suits={'Hearts','Diamonds','Spades','Clubs'}
local floor, min, max = math.floor, math.min, math.max
local function num(v, default) return type(v) == 'number' and v or (default or 0) end
local function copy(t) local r = {}; for k,v in pairs(t or {}) do r[k] = v end; return r end
local function finite_nonnegative(v) return type(v)=='number' and v==v and v>=0 and v<math.huge end
local function lucky_identities(snapshot)
    local ids={}
    for _,area in ipairs({snapshot.hand or {},snapshot.deck or {}}) do for _,c in ipairs(area) do
        local id=c.id
        if not (type(id)=='string' and id~='' or type(id)=='number' and id==id and math.abs(id)<math.huge) then
            return nil,'Sampled Lucky effects require present physical card identities.'
        end
        local key=tostring(id)
        if ids[key] then return nil,'Sampled Lucky effects require distinct physical card identities.' end
        ids[key]=true
    end end
    return true
end
local detached, population_ids
local aliases = {
    j_joker='Joker', j_half='Half Joker', j_stencil='Joker Stencil', j_four_fingers='Four Fingers',
    j_mime='Mime', j_ceremonial='Ceremonial Dagger', j_banner='Banner', j_mystic_summit='Mystic Summit',
    j_loyalty_card='Loyalty Card', j_misprint='Misprint', j_dusk='Dusk', j_raised_fist='Raised Fist',
    j_fibonacci='Fibonacci', j_steel_joker='Steel Joker', j_scary_face='Scary Face', j_abstract='Abstract Joker',
    j_hack='Hack', j_pareidolia='Pareidolia', j_gros_michel='Gros Michel', j_even_steven='Even Steven',
    j_odd_todd='Odd Todd', j_scholar='Scholar', j_business='Business Card', j_supernova='Supernova',
    j_ride_the_bus='Ride the Bus', j_space='Space Joker', j_blackboard='Blackboard', j_runner='Runner',
    j_ice_cream='Ice Cream', j_dna='DNA', j_splash='Splash', j_blue_joker='Blue Joker',
    j_constellation='Constellation', j_hiker='Hiker', j_green_joker='Green Joker', j_todo_list='To Do List',
    j_cavendish='Cavendish', j_card_sharp='Card Sharp', j_red_card='Red Card', j_madness='Madness',
    j_square='Square Joker', j_vampire='Vampire', j_shortcut='Shortcut', j_hologram='Hologram',
    j_baron='Baron', j_obelisk='Obelisk', j_midas_mask='Midas Mask', j_photograph='Photograph',
    j_erosion='Erosion', j_reserved_parking='Reserved Parking', j_fortune_teller='Fortune Teller',
    j_stone='Stone Joker', j_lucky_cat='Lucky Cat', j_baseball='Baseball Card', j_bull='Bull',
    j_flash='Flash Card', j_popcorn='Popcorn', j_trousers='Spare Trousers', j_ancient='Ancient Joker',
    j_ramen='Ramen', j_walkie_talkie='Walkie Talkie', j_selzer='Seltzer', j_castle='Castle',
    j_smiley='Smiley Face', j_campfire='Campfire', j_ticket='Golden Ticket', j_acrobat='Acrobat',
    j_sock_and_buskin='Sock and Buskin', j_swashbuckler='Swashbuckler', j_smeared='Smeared Joker',
    j_hanging_chad='Hanging Chad', j_rough_gem='Rough Gem', j_bloodstone='Bloodstone',
    j_arrowhead='Arrowhead', j_onyx_agate='Onyx Agate', j_glass='Glass Joker', j_flower_pot='Flower Pot',
    j_blueprint='Blueprint', j_wee='Wee Joker', j_idol='The Idol', j_seeing_double='Seeing Double',
    j_hit_the_road='Hit the Road', j_stuntman='Stuntman', j_brainstorm='Brainstorm',
    j_shoot_the_moon='Shoot the Moon', j_drivers_license="Driver's License", j_bootstraps='Bootstraps',
    j_caino='Caino', j_triboulet='Triboulet', j_yorick='Yorick', j_burnt='Burnt Joker',
    j_trading='Trading Card', j_mail='Mail-In Rebate', j_faceless='Faceless Joker',
}
local alias_names={};for _,value in pairs(aliases) do alias_names[value]=true end
local function name(j) return (j.ability and j.ability.name) or j.name or aliases[j.key] or j.key or 'Unknown Joker' end
local function enh(c)
    return c.enhancement or (c.key and c.key:sub(1,2) == 'm_' and c.key) or
        enhancement_effects[(c.ability or {}).effect] or 'c_base'
end
local function rank(c) if enh(c) == 'm_stone' then return 0 end; return num(c.rank or (c.base or {}).id) end
local function nominal(c)
    local value=c.nominal or (c.base or {}).nominal
    if type(value)=='number' then return value end
    local r=rank(c)
    return r == 14 and 11 or min(r, 10)
end
local function flags(jokers)
    local r = {}; for _,j in ipairs(jokers or {}) do if not j.debuff then r[name(j)] = true end end; return r
end
local function suit(c, wanted, f, flush, bypass)
    if enh(c) == 'm_stone' then return false end
    if c.debuff and not (flush or bypass) then return false end
    if enh(c) == 'm_wild' and (not c.debuff or not flush) then return true end
    local actual = c.suit or (c.base or {}).suit
    if f['Smeared Joker'] then
        return (actual == 'Hearts' or actual == 'Diamonds') == (wanted == 'Hearts' or wanted == 'Diamonds')
    end
    return actual == wanted
end
local function face(c, f) local r = rank(c); return not c.debuff and ((r >= 11 and r <= 13) or f.Pareidolia) end
local hand_defaults = {
    ['High Card']={5,1,10,1}, Pair={10,2,15,1}, ['Two Pair']={20,2,20,1},
    ['Three of a Kind']={30,3,20,2}, Straight={30,4,30,3}, Flush={35,4,15,2},
    ['Full House']={40,4,25,2}, ['Four of a Kind']={60,7,30,3}, ['Straight Flush']={100,8,40,4},
    ['Five of a Kind']={120,12,35,3}, ['Flush House']={140,14,40,4}, ['Flush Five']={160,16,50,3},
}

-- Returns the winning category, contributing indices, and categories contained.
local function raw_classify(snapshot, selected, prepared)
    local f = prepared and prepared.flags and prepared.flags(snapshot.jokers,flags) or flags(snapshot.jokers)
    local hand, groups = snapshot.hand or {}, {}
    local best, best_rank = selected[1], -1
    for _,i in ipairs(selected) do
        local c = hand[i]; local r = rank(c)
        if r > best_rank then best, best_rank = i, r end
        if r > 0 then groups[r] = groups[r] or {}; groups[r][#groups[r]+1] = i end
    end
    local pairs_, triple, four, five = {}, nil, nil, nil
    for r=14,2,-1 do local g=groups[r]; if g then
        if #g==2 then pairs_[#pairs_+1]=g elseif #g==3 then triple=g elseif #g==4 then four=g elseif #g==5 then five=g end
    end end
    local need = f['Four Fingers'] and 4 or 5
    local flush
    if #selected >= need then
        for _,s in ipairs(classification_suits) do
            local same={}; for _,i in ipairs(selected) do if suit(hand[i],s,f,true) then same[#same+1]=i end end
            if #same >= need then flush=same; break end
        end
    end
    local straight, run, length, skipped, found = nil, {}, 0, false, false
    if #selected >= need then
        for r=1,14 do
            local g=groups[r==1 and 14 or r]
            if g then
                length=length+1; skipped=false
                for _,i in ipairs(g) do run[#run+1]=i end
            elseif f.Shortcut and not skipped and r ~= 14 then skipped=true
            else
                length=0; skipped=false
                if found then break end
                run={}
            end
            if length >= need then found=true end
        end
        if found then straight=run end
    end
    local contains = {['High Card']=#selected>0}
    contains.Pair = #pairs_>0 or triple~=nil or four~=nil or five~=nil
    contains['Two Pair'] = #pairs_==2 or (triple~=nil and #pairs_==1)
    contains['Three of a Kind'] = triple~=nil or four~=nil or five~=nil
    contains['Four of a Kind'] = four~=nil or five~=nil
    contains['Five of a Kind'] = five~=nil
    contains.Straight = straight~=nil; contains.Flush = flush~=nil
    contains['Full House'] = triple~=nil and #pairs_==1
    contains['Straight Flush'] = straight~=nil and flush~=nil
    contains['Flush House'] = contains['Full House'] and flush~=nil
    contains['Flush Five'] = five~=nil and flush~=nil
    local category, raw = 'High Card', {best}
    local function join(a,b) local r={}; for _,i in ipairs(a) do r[#r+1]=i end; for _,i in ipairs(b) do r[#r+1]=i end; return r end
    if contains['Flush Five'] then category,raw='Flush Five',five
    elseif contains['Flush House'] then category,raw='Flush House',join(triple,pairs_[1])
    elseif five then category,raw='Five of a Kind',five
    elseif contains['Straight Flush'] then category,raw='Straight Flush',join(straight,flush)
    elseif four then category,raw='Four of a Kind',four
    elseif contains['Full House'] then category,raw='Full House',join(triple,pairs_[1])
    elseif flush then category,raw='Flush',flush
    elseif straight then category,raw='Straight',straight
    elseif triple then category,raw='Three of a Kind',triple
    elseif #pairs_==2 then category,raw='Two Pair',join(pairs_[1],pairs_[2])
    elseif #pairs_==1 then category,raw='Pair',pairs_[1] end
    local included, scoring = {}, {}
    for _,i in ipairs(raw) do included[i]=true end
    for _,i in ipairs(selected) do
        if included[i] or f.Splash or enh(hand[i])=='m_stone' then scoring[#scoring+1]=i end
    end
    return category, scoring, contains
end

function M.classify(snapshot,selected,prepared)
    if prepared and prepared.classify then
        if not prepared.classification_flags then prepared.classification_flags=function(s) return prepared.flags and prepared.flags(s.jokers,flags) or flags(s.jokers) end end
        return prepared.classify(snapshot,selected,raw_classify)
    end
    return raw_classify(snapshot,selected)
end

local passive = {}
for _,s in ipairs({'Egg','Credit Card','Marble Joker','Burglar','Golden Joker','Rocket','Satellite','To the Moon',
    'Turtle Bean','Diet Cola','Mr. Bones','Invisible Joker','Luchador','Oops! All 6s','Certificate',
    'Juggler','Troubadour','Drunkard','Merry Andy','Chaos the Clown','Delayed Gratification',
    'Cloud 9','Mail-In Rebate','Hallucination','Gift Card','Trading Card','Faceless Joker','Burnt Joker',
    'Riff-raff','Cartomancer','Astronomer','Showman','Chicot','Perkeo','Vagabond','Superposition','Seance',
    '8 Ball','Sixth Sense','Matador','Four Fingers','Shortcut','Smeared Joker','Splash','Pareidolia'}) do passive[s]=true end
local individual = {}
for _,s in ipairs({'Hiker','Photograph','The Idol','Scary Face','Smiley Face','Golden Ticket','Scholar','Walkie Talkie',
    'Business Card','Fibonacci','Even Steven','Odd Todd','Greedy Joker','Lusty Joker','Wrathful Joker','Gluttonous Joker',
    'Rough Gem','Onyx Agate','Arrowhead','Bloodstone','Ancient Joker','Triboulet','Shoot the Moon','Baron',
    'Reserved Parking','Raised Fist','Sock and Buskin','Hanging Chad','Dusk','Seltzer','Hack','Mime','Baseball Card',
    'Midas Mask','Space Joker','DNA','To Do List'}) do individual[s]=true end
local addmult_names={Joker=true,['Ceremonial Dagger']=true,Swashbuckler=true,['Spare Trousers']=true,['Ride the Bus']=true,['Flash Card']=true,Popcorn=true,['Green Joker']=true,['Red Card']=true}
local xmult_names={Madness=true,Constellation=true,Hologram=true,Vampire=true,Obelisk=true,['Lucky Cat']=true,['Glass Joker']=true,Ramen=true,Campfire=true,Throwback=true,['Hit the Road']=true,Yorick=true}
local known_enhancements={c_base=true,m_stone=true,m_wild=true,m_bonus=true,m_mult=true,m_glass=true,m_steel=true,m_gold=true,m_lucky=true}

-- Copy routing depends only on this detached immutable Joker row. Reusing it
-- does not reuse scores, cash, growth state or random outcomes across hands.
local function score_row(jokers)
    local names,resolved={},{}
    for i,j in ipairs(jokers) do names[i]=name(j) end
    local function resolve(i,visited)
        local j=jokers[i];if not j or j.debuff then return nil end
        visited=visited or {};if visited[i] then return nil end;visited[i]=true
        local n=names[i]
        if n=='Blueprint' or n=='Brainstorm' then
            local to=n=='Blueprint' and i+1 or 1
            if not jokers[to] or jokers[to].blueprint_compat==false then return nil end
            return resolve(to,visited)
        end
        return i
    end
    for i=1,#jokers do resolved[i]=resolve(i) end
    return {names=names,resolved=resolved}
end
local writable_jokers={['Spare Trousers']=true,['Square Joker']=true,Runner=true,
    ['Green Joker']=true,['Ride the Bus']=true,Obelisk=true,Vampire=true,Hologram=true,
    ['Wee Joker']=true,['Lucky Cat']=true}

-- transition is an internal output sink used by after_play. Ordinary score calls
-- retain only their score result; they never clone the whole snapshot.
function M.score(snapshot, selected, transition, floor_mode, prepared)
    local hand, jokers = snapshot.hand or {}, snapshot.jokers or {}
    local warnings, warned, chosen = {}, {}, {}
    local uncertain = false
    local function warn(s)
        uncertain=true
        if transition and s:match('^Unmodeled') then transition.unsupported=s end
        if not warned[s] and not snapshot.suppress_warnings then warned[s]=true; warnings[#warnings+1]=s end
    end
    local function random_warn(s) if not floor_mode then warn(s) end end
    local function invalid(reason, category, scoring)
        return {score=0, chips=0, mult=0, hand=category or 'High Card', warnings=warnings,
            scoring_indices=scoring or {}, legal=false, reason=reason, uncertain=uncertain}
    end
    if #selected<1 or #selected>5 then return invalid('Select one to five cards.') end
    for _,i in ipairs(selected) do
        if not hand[i] or chosen[i] then return invalid('Invalid or duplicate card selection.') end
        chosen[i]=true
    end
    for i,c in ipairs(hand) do
        if (c.ability or {}).forced_selection and not chosen[i] then return invalid('Include the card forced by Cerulean Bell.') end
        if c.face_down then warn('This estimate uses the identities of face-down cards from the snapshot.') end
        if not c.rank and not (c.base or {}).id then warn('An unknown card is treated as having no rank.') end
        if not known_enhancements[enh(c)] then warn('Unmodeled card enhancement: '..tostring(enh(c))..'. Custom effects are omitted.') end
    end
    local category, scoring, contains=M.classify(snapshot,selected,prepared)
    local b=snapshot.blind or {}; local bn=not b.disabled and (b.name or score_blind_names[b.key])
    local bd=not b.disabled and b.debuff or {}
    if (bn=='The Psychic' and #selected~=5) or (bd.h_size_ge and #selected<bd.h_size_ge) then return invalid('The blind requires more cards in the played hand.',category,scoring) end
    if bd.h_size_le and #selected>bd.h_size_le then return invalid('The blind limits played hand size.',category,scoring) end
    if bd.hand and contains[bd.hand] then return invalid('This hand is debuffed by the blind.',category,scoring) end
    if bn=='The Eye' and (b.hands or {})[category] then return invalid('The Eye forbids repeating '..category..'.',category,scoring) end
    if bn=='The Mouth' and b.only_hand and b.only_hand~=category then return invalid('The Mouth requires '..b.only_hand..'.',category,scoring) end
    if bn=='The Hook' and not b.hook_resolved then warn('The Hook randomly discards held cards before scoring; held effects may change.') end
    local f=prepared and prepared.flags and prepared.flags(jokers,flags) or flags(jokers)
    local row=prepared and prepared.row and prepared.row(jokers,score_row) or score_row(jokers)
    local names,resolved=row.names,row.resolved
    local hs=(snapshot.hands or {})[category] or {}; local defaults=hand_defaults[category]
    local chips=num(hs.chips,defaults[1]); local mult=num(hs.mult,defaults[2])
    local dollars=num(snapshot.dollars); local round=snapshot.current_round or {}
    if bn=='The Tooth' then dollars=dollars-#selected end
    if bn=='The Ox' and category==round.most_played_poker_hand then dollars=0 end
    local capped=(snapshot.modifiers or {}).chips_dollar_cap
    -- ease_dollars queues earnings until evaluate_play returns. The chip cap reads
    -- existing dollars; Bull/Bootstraps read those dollars plus the earning buffer.
    local cap_dollars=dollars
    local function cap(v) return capped and min(v,max(cap_dollars,0)) or v end
    local function addchips(v) chips=cap(chips+v) end
    local prob=num((snapshot.probabilities or {}).normal,1)
    local function chance(odds) return max(0,min(1,prob/max(num(odds,1),1))) end
    local function score_chance(odds)
        local p=chance(odds)
        -- Supported random score contributions are nonnegative. Taking every
        -- optional trigger to fail is conservative even for correlated rolls.
        if floor_mode=='ceiling' then return p>0 and 1 or 0 end
        return floor_mode and (p>=1 and 1 or 0) or p
    end
    local level=num(hs.level,1)
    if bn=='The Arm' and level>1 then level=level-1; chips=max(0,chips-num(hs.l_chips,defaults[3])); mult=max(1,mult-num(hs.l_mult,defaults[4])) end
    if num(snapshot.first_used_hand_level)>0 then level=level+snapshot.first_used_hand_level; chips=chips+num(hs.l_chips,defaults[3])*snapshot.first_used_hand_level; mult=mult+num(hs.l_mult,defaults[4])*snapshot.first_used_hand_level end
    local held, localcards, created_cards={},{},{}
    local writable_cards=transition or f['Midas Mask'] or f.Vampire or f.Hiker
    for i,c in ipairs(hand) do
        if not chosen[i] then held[#held+1]=i end
        if chosen[i] then
            if writable_cards then localcards[i]=copy(c);localcards[i].ability=copy(c.ability)
            else localcards[i]=c end
        end
    end
    local states={}
    for i,j in ipairs(jokers) do
        if transition or writable_jokers[names[i]] then
            states[i]=copy(j.ability);states[i].extra=type(states[i].extra)=='table' and copy(states[i].extra) or states[i].extra
        else
            states[i]=j.ability or {}
        end
    end
    local function extra(a,k,default) return type(a.extra)=='table' and num(a.extra[k],default) or (k==nil and num(a.extra,default) or num(nil,default)) end
    -- Before-scoring growth occurs once per real Joker. Copies share its new value.
    for i,j in ipairs(jokers) do if not j.debuff then
        local n,a=names[i],states[i]
        if n=='Spare Trousers' and contains['Two Pair'] then a.mult=num(a.mult)+extra(a,nil,2)
        elseif n=='Square Joker' and #selected==4 then a.extra=a.extra or {}; a.extra.chips=extra(a,'chips')+extra(a,'chip_mod',4)
        elseif n=='Runner' and contains.Straight then a.extra=a.extra or {}; a.extra.chips=extra(a,'chips')+extra(a,'chip_mod',15)
        elseif n=='Green Joker' then a.mult=num(a.mult)+extra(a,'hand_add',1)
        elseif n=='Ride the Bus' then
            local hasface=false; for _,ci in ipairs(scoring) do if face(localcards[ci],f) then hasface=true end end
            a.mult=hasface and 0 or num(a.mult)+extra(a,nil,1)
        elseif n=='Obelisk' then
            local highest=true; for h,v in pairs(snapshot.hands or {}) do if h~=category and v.visible and num(v.played)>=num(hs.played)+1 then highest=false end end
            a.x_mult=highest and 1 or num(a.x_mult,1)+extra(a,nil,0.2)
        elseif n=='Midas Mask' then
            for _,ci in ipairs(scoring) do local c=localcards[ci]; if face(c,f) then
                c.enhancement='m_gold'; c.ability.bonus=0; c.ability.mult=0; c.ability.x_mult=1; c.ability.h_x_mult=0; c.ability.h_mult=0; c.ability.p_dollars=0; c.ability.h_dollars=3
            end end
        elseif n=='Vampire' then
            local eaten=0; for _,ci in ipairs(scoring) do local c=localcards[ci]; if not c.debuff and not c.vampired and enh(c)~='c_base' then
                eaten=eaten+1; c.vampired=true; c.enhancement='c_base'; c.ability.bonus=0; c.ability.mult=0; c.ability.x_mult=1; c.ability.h_x_mult=0; c.ability.h_mult=0; c.ability.p_dollars=0; c.ability.h_dollars=0
            end end
            a.x_mult=num(a.x_mult,1)+eaten*extra(a,nil,0.1)
        end
        local ri=resolved[i]
        if ri then local rn,ra=names[ri],states[ri]
            if rn=='Space Joker' then
                random_warn('Space Joker is modeled using average hand levels, not guaranteed upgrades.')
                if floor_mode and (num(hs.l_chips,defaults[3])<0 or num(hs.l_mult,defaults[4])<0) then warn('Unmodeled negative Space Joker upgrade for a score bound.') end
                level=level+score_chance(ra.extra)
                chips=chips+num(hs.l_chips,defaults[3])*score_chance(ra.extra); mult=mult+num(hs.l_mult,defaults[4])*score_chance(ra.extra)
            elseif rn=='To Do List' and category==(ra.to_do_poker_hand or (type(ra.extra)=='table' and ra.extra.poker_hand)) then dollars=dollars+extra(ra,'dollars',4)
            elseif rn=='DNA' and num(snapshot.hands_played,round.hands_played)==0 and #selected==1 then
                local source=localcards[selected[1]];local ca=source.ability or {}
                local ids,reason=population_ids(snapshot,{source})
                if not ids or #held>=20 or num(ca.h_size)~=0 or num(ca.d_size)~=0 or
                    source.edition=='negative' or type(source.edition)=='table' and source.edition.negative then
                    warn('Unmodeled DNA copy: '..(reason or 'playing-card resource modifiers or bounded hand size.'))
                else
                    -- The source callback copies at its position in the before
                    -- row. Earlier Midas/Vampire changes are already present;
                    -- later Hiker bonuses and Glass loss do not change the copy.
                    if #created_cards==0 then hand=copy(hand) end
                    local c=detached(source);local suffix=#created_cards+1
                    for _,v in ipairs(created_cards) do ids[v.id]=true end
                    repeat c.id='advisor-dna:'..tostring(source.id)..':'..suffix;suffix=suffix+1 until not ids[c.id]
                    c.base=c.base or {};c.base.times_played=0;c.base.original_value=nil
                    c.base.suit_nominal_original=({Diamonds=0.001,Clubs=0.002,Hearts=0.003,Spades=0.004})[c.suit or c.base.suit]
                    c.ability.played_this_ante=true;c.ability.forced_selection=nil
                    c.face_down=false;c.shattered=nil;c.removed=nil;c.vampired=nil
                    created_cards[#created_cards+1]=c;hand[#hand+1]=c;held[#held+1]=#hand
                    for hi,hj in ipairs(jokers) do if not hj.debuff and not hj.getting_sliced and names[hi]=='Hologram' then
                        states[hi].x_mult=num(states[hi].x_mult,1)+extra(states[hi],nil,0.25)
                    end end
                end
            end
        end
    end end
    if transition then
        transition.level=level; transition.hand_chips=chips; transition.hand_mult=mult
        transition.states=states; transition.cards=localcards
        transition.created_cards=created_cards
    end
    chips=cap(chips)
    if bn=='The Flint' then chips=cap(max(floor(chips*0.5+0.5),0)); mult=max(floor(mult*0.5+0.5),1) end
    local firstface
    for _,ci in ipairs(scoring) do if face(localcards[ci],f) then firstface=ci; break end end
    local function repetitions(c,ci,held_card)
        local count=1+(c.seal=='Red' and 1 or 0)
        for ji=1,#jokers do local ri=resolved[ji]; if ri then local n,a=names[ri],states[ri]
            if held_card then if n=='Mime' then count=count+extra(a,nil,1) end
            elseif (n=='Sock and Buskin' and face(c,f)) or (n=='Hanging Chad' and ci==scoring[1]) or
                (n=='Dusk' and num(snapshot.hands_left,round.hands_left)==1) or (n=='Hack' and rank(c)>=2 and rank(c)<=5) then count=count+extra(a,nil,n=='Hanging Chad' and 2 or 1)
            elseif n=='Seltzer' then count=count+1 end
        end end
        return min(count,100)
    end
    local function edition(c,phase)
        local e=c.edition or {}
        if phase~='after' then addchips(num(e.chips,e.foil and 50 or 0)); mult=mult+num(e.mult,e.holo and 10 or 0) end
        if phase~='before' then mult=mult*num(e.x_mult,e.polychrome and 1.5 or 1) end
    end
    local lucky_growth=0
    -- Only after_play supplies this private common-world family. Ordinary mean
    -- scoring and the independent floor/ceiling passes never consume outcomes.
    local lucky_outcomes=not floor_mode and transition and transition.lucky_outcomes
    local sampled_lucky_events=0
    local lucky_ids_checked=false
    local function lucky_event(c,ci,repetition)
        if not lucky_ids_checked then
            local identities,reason=lucky_identities(snapshot)
            if not identities then return nil,'Unmodeled '..reason end
            lucky_ids_checked=true
        end
        local a=c.ability or {}
        if not finite_nonnegative(num(a.mult,20)) or a.mult~=nil and type(a.mult)~='number' or
            not finite_nonnegative(num(a.p_dollars,20)) or a.p_dollars~=nil and type(a.p_dollars)~='number' or
            not finite_nonnegative(prob) or (snapshot.probabilities or {}).normal~=nil and
                type(snapshot.probabilities.normal)~='number' then
            return nil,'Unmodeled Lucky effect: Mult, dollars and normal probability must be nonnegative finite numbers.'
        end
        local row=type(lucky_outcomes)=='table' and lucky_outcomes[ci]
        local event=type(row)=='table' and row[repetition]
        if type(event)~='table' or type(event.mult)~='boolean' or type(event.dollars)~='boolean' then
            return nil,'Unmodeled sampled Lucky effect: every scoring repetition needs explicit Boolean Mult and dollar outcomes.'
        end
        if next(jokers) and (not transition.lucky_floor or event.mult or event.dollars) then
            return nil,'Owned-Joker Lucky transitions support only an explicit no-trigger floor.'
        end
        for _,item in ipairs({{event.mult,5},{event.dollars,15}}) do
            local p=chance(item[2])
            if p<=0 and item[1] or p>=1 and not item[1] then
                return nil,'Unmodeled sampled Lucky outcome contradicts a certain probability.'
            end
        end
        return event
    end
    for _,ci in ipairs(scoring) do local c=localcards[ci]; if not c.debuff then
        for repetition=1,repetitions(c,ci,false) do
            local a=c.ability or {}; local e=enh(c); local r=rank(c)
            addchips((e=='m_stone' and 0 or nominal(c))+num(a.bonus,e=='m_stone' and 50 or e=='m_bonus' and 30 or 0)+num(a.perma_bonus))
            if e=='m_lucky' then
                if lucky_outcomes~=nil and lucky_outcomes~=false then
                    local event,reason=lucky_event(c,ci,repetition)
                    if not event then warn(reason);return invalid(reason,category,scoring) end
                    mult=mult+(event.mult and num(a.mult,20) or 0)
                    dollars=dollars+(event.dollars and num(a.p_dollars,20) or 0)
                    lucky_growth=0;sampled_lucky_events=sampled_lucky_events+1
                else
                    random_warn('Lucky cards and other random effects use averages; a clearing estimate is not a guarantee.')
                    if floor_mode and (num(a.mult,20)<0 or num(a.p_dollars,20)<0) then warn('Unmodeled negative Lucky Card effect for a score bound.') end
                    mult=mult+num(a.mult,20)*score_chance(5); dollars=dollars+num(a.p_dollars,20)*score_chance(15)
                    lucky_growth=1-(1-score_chance(5))*(1-score_chance(15))
                end
            else mult=mult+num(a.mult,e=='m_mult' and 4 or 0); dollars=dollars+num(a.p_dollars); lucky_growth=0 end
            mult=mult*max(1,num(a.x_mult,e=='m_glass' and 2 or 1))
            if c.seal=='Gold' then dollars=dollars+3 end
            edition(c)
            local hiker_bonus=0
            for ji=1,#jokers do local ri=resolved[ji]; if ri then
                local n,ja=names[ri],states[ri]; local ex=ja.extra
                if n=='Hiker' then hiker_bonus=hiker_bonus+extra(ja,nil,5)
                elseif n=='Wee Joker' and r==2 and ji==ri then ja.extra=ja.extra or {}; ja.extra.chips=extra(ja,'chips')+extra(ja,'chip_mod',8)
                elseif n=='Lucky Cat' then
                    if floor_mode and extra(ja,nil,0.25)<0 then warn('Unmodeled negative Lucky Cat growth for a score bound.') end
                    if lucky_growth>0 and ji==ri then ja.x_mult=num(ja.x_mult,1)+extra(ja,nil,0.25)*lucky_growth; random_warn('Lucky Cat growth uses an approximation to correlated lucky triggers.') end
                elseif n=='Photograph' and ci==firstface then mult=mult*extra(ja,nil,2)
                elseif n=='The Idol' and r==(round.idol_card or {}).id and suit(c,(round.idol_card or {}).suit,f) then mult=mult*extra(ja,nil,2)
                elseif n=='Scary Face' and face(c,f) then addchips(extra(ja,nil,30))
                elseif n=='Smiley Face' and face(c,f) then mult=mult+extra(ja,nil,5)
                elseif n=='Golden Ticket' and e=='m_gold' then dollars=dollars+extra(ja,nil,4)
                elseif n=='Scholar' and r==14 then addchips(extra(ja,'chips',20)); mult=mult+extra(ja,'mult',4)
                elseif n=='Walkie Talkie' and (r==10 or r==4) then addchips(extra(ja,'chips',10)); mult=mult+extra(ja,'mult',4)
                elseif n=='Business Card' and face(c,f) then dollars=dollars+2*score_chance(ex); if f.Bull or f.Bootstraps then random_warn('Dollar-dependent Joker scores use average earnings; thresholds may vary.') end
                elseif n=='Fibonacci' and (r==2 or r==3 or r==5 or r==8 or r==14) then mult=mult+extra(ja,nil,8)
                elseif n=='Even Steven' and r>=2 and r<=10 and r%2==0 then mult=mult+extra(ja,nil,4)
                elseif n=='Odd Todd' and ((r>=2 and r<=10 and r%2==1) or r==14) then addchips(extra(ja,nil,31))
                elseif ja.effect=='Suit Mult' and type(ex)=='table' and suit(c,ex.suit,f) then mult=mult+num(ex.s_mult,3)
                elseif n=='Rough Gem' and suit(c,'Diamonds',f) then dollars=dollars+extra(ja,nil,1)
                elseif n=='Onyx Agate' and suit(c,'Clubs',f) then mult=mult+extra(ja,nil,7)
                elseif n=='Arrowhead' and suit(c,'Spades',f) then addchips(extra(ja,nil,50))
                elseif n=='Bloodstone' and suit(c,'Hearts',f) then
                    random_warn('Bloodstone uses expected triggers; actual score varies.')
                    if floor_mode and extra(ja,'Xmult',1.5)<1 then warn('Unmodeled negative Bloodstone effect for a score bound.') end
                    mult=mult*(1+score_chance(extra(ja,'odds',2))*(extra(ja,'Xmult',1.5)-1))
                elseif n=='Ancient Joker' and suit(c,(round.ancient_card or {}).suit,f) then mult=mult*extra(ja,nil,1.5)
                elseif n=='Triboulet' and (r==12 or r==13) then mult=mult*extra(ja,nil,2) end
            end end
            if writable_cards then a.perma_bonus=num(a.perma_bonus)+hiker_bonus end
        end
    end end
    local lowest,lowest_rank=nil,15
    -- Only an active Raised Fist route consumes the lowest held-card result.
    -- Copy routes require that same nondebuffed source in the row flags.
    if f['Raised Fist'] then
        for _,ci in ipairs(held) do local c=hand[ci]; if enh(c)~='m_stone' and rank(c)<=lowest_rank then lowest,lowest_rank=ci,rank(c) end end
    end
    for _,ci in ipairs(held) do local c=hand[ci]; if not c.debuff then
        local a=c.ability or {}; local hm=num(a.h_mult); local hx=num(a.h_x_mult,enh(c)=='m_steel' and 1.5 or 0)
        local effects=hm>0 or hx>0
        for ji=1,#jokers do local ri=resolved[ji]; if ri then local n=names[ri]; if (n=='Shoot the Moon' and rank(c)==12) or (n=='Baron' and rank(c)==13) or (n=='Raised Fist' and ci==lowest) or (n=='Reserved Parking' and face(c,f)) then effects=true end end end
        if effects then for _=1,repetitions(c,ci,true) do
            mult=(mult+hm)*max(1,hx)
            for ji=1,#jokers do local ri=resolved[ji]; if ri then local n,ja=names[ri],states[ri]
                if n=='Shoot the Moon' and rank(c)==12 then mult=mult+13
                elseif n=='Baron' and rank(c)==13 then mult=mult*extra(ja,nil,1.5)
                elseif n=='Raised Fist' and ci==lowest then mult=mult+2*nominal(c)
                elseif n=='Reserved Parking' and face(c,f) then
                    if floor_mode and extra(ja,'dollars',1)<0 then warn('Unmodeled negative Reserved Parking effect for a score bound.') end
                    dollars=dollars+extra(ja,'dollars',1)*score_chance(extra(ja,'odds',2)); if f.Bull or f.Bootstraps then random_warn('Dollar-dependent Joker scores use average earnings; thresholds may vary.') end end
            end end
        end end
    end end
    for ji,j in ipairs(jokers) do
        if not j.debuff then edition(j,'before') end
        local ri=resolved[ji]
        if ri then
            local n,a=names[ri],states[ri]; local applied=true
            if num(a.x_mult)>1 and n~='Seeing Double' and (a.type==nil or a.type=='' or contains[a.type]) then mult=mult*a.x_mult
            elseif num(a.t_mult)>0 and contains[a.type] then mult=mult+a.t_mult
            elseif num(a.t_chips)>0 and contains[a.type] then addchips(a.t_chips)
            elseif a.type and a.type~='' and (num(a.t_mult)>0 or num(a.t_chips)>0 or num(a.x_mult)>1) then -- recognized, condition not met
            elseif addmult_names[n] then mult=mult+num(a.mult,n=='Joker' and 4 or 0)
            elseif xmult_names[n] then -- base X1 has no effect
            elseif n=='Half Joker' then if #selected<=extra(a,'size',3) then mult=mult+extra(a,'mult',20) end
            elseif n=='Abstract Joker' then mult=mult+#jokers*extra(a,nil,3)
            elseif n=='Acrobat' then if num(snapshot.hands_left,round.hands_left)==1 then mult=mult*extra(a,nil,3) end
            elseif n=='Mystic Summit' then if num(snapshot.discards_left,round.discards_left)==extra(a,'d_remaining') then mult=mult+extra(a,'mult',15) end
            elseif n=='Misprint' then random_warn('Misprint uses its average Mult; actual score varies.'); mult=mult+(floor_mode=='ceiling' and max(extra(a,'min'),extra(a,'max',23)) or floor_mode and min(extra(a,'min'),extra(a,'max',23)) or (extra(a,'min')+extra(a,'max',23))/2)
            elseif n=='Banner' then addchips(max(0,num(snapshot.discards_left,round.discards_left))*extra(a,nil,30))
            elseif n=='Stuntman' then addchips(extra(a,'chip_mod',250))
            elseif n=='Supernova' then mult=mult+num(hs.played)+1
            elseif n=='Wee Joker' or n=='Castle' or n=='Square Joker' or n=='Runner' or n=='Ice Cream' then addchips(extra(a,'chips',n=='Ice Cream' and 100 or 0))
            elseif n=='Blue Joker' then addchips(#(snapshot.deck or {})*extra(a,nil,2))
            elseif n=='Erosion' then mult=mult+max(0,num(snapshot.starting_deck_size,52)-#(snapshot.playing_cards or {})-#created_cards)*extra(a,nil,4)
            elseif n=='Stone Joker' then addchips(num(a.stone_tally)*extra(a,nil,25))
            elseif n=='Steel Joker' then mult=mult*(1+num(a.steel_tally)*extra(a,nil,0.2))
            elseif n=='Bull' then
                if floor_mode and extra(a,nil,2)<0 then warn('Unmodeled negative dollar scaling for a score bound.') end
                addchips(max(0,dollars)*extra(a,nil,2))
            elseif n=="Driver's License" then if num(a.driver_tally)>=16 then mult=mult*extra(a,nil,3) end
            elseif n=='Blackboard' then
                local allblack=true; for _,ci in ipairs(held) do if not suit(hand[ci],'Clubs',f,true) and not suit(hand[ci],'Spades',f,true) then allblack=false end end
                if allblack then mult=mult*extra(a,nil,3) end
            elseif n=='Joker Stencil' then
                local empty=num(snapshot.joker_limit,5)-#jokers; for _,v in ipairs(jokers) do if name(v)=='Joker Stencil' then empty=empty+1 end end
                mult=mult*max(1,empty)
            elseif n=='Fortune Teller' then mult=mult+num((snapshot.consumeable_usage_total or {}).tarot)
            elseif n=='Gros Michel' then mult=mult+extra(a,'mult',15)
            elseif n=='Cavendish' then mult=mult*extra(a,'Xmult',3)
            elseif n=='Card Sharp' then if num(hs.played_this_round)>=1 then mult=mult*extra(a,'Xmult',3) end
            elseif n=='Bootstraps' then
                if floor_mode and (extra(a,'mult',2)<0 or extra(a,'dollars',5)<=0) then warn('Unmodeled negative dollar scaling for a score bound.') end
                mult=mult+extra(a,'mult',2)*max(0,floor(dollars/extra(a,'dollars',5)))
            elseif n=='Caino' then mult=mult*max(1,num(a.caino_xmult,1))
            elseif n=='Loyalty Card' then
                local every=extra(a,'every',5)
                if (every-1-(num(snapshot.hands_played_total)-num(a.hands_played_at_create)))%(every+1)==every then mult=mult*extra(a,'Xmult',4) end
            elseif n=='Seeing Double' or n=='Flower Pot' then
                local suits=n=='Seeing Double' and seeing_double_suits or flower_pot_suits
                local seen={}
                for _,ci in ipairs(scoring) do local c=localcards[ci]; if enh(c)~='m_wild' then
                    for _,s in ipairs(suits) do if suit(c,s,f,false,n=='Flower Pot') and not seen[s] then seen[s]=true; if n=='Flower Pot' then break end end end
                end end
                for _,ci in ipairs(scoring) do local c=localcards[ci]; if enh(c)=='m_wild' then
                    for _,s in ipairs(suits) do if not seen[s] and suit(c,s,f) then seen[s]=true; break end end
                end end
                if (n=='Seeing Double' and seen.Clubs and (seen.Hearts or seen.Spades or seen.Diamonds)) or (n=='Flower Pot' and seen.Hearts and seen.Spades and seen.Diamonds and seen.Clubs) then mult=mult*extra(a,nil,n=='Flower Pot' and 3 or 2) end
            elseif not passive[n] and not individual[n] then applied=false end
            if not applied then warn('Unmodeled Joker: '..n..'. Its effect is omitted.') end
        end
        -- Baseball resolves once for each physical uncommon Joker, then its edition XMult.
        if j.rarity==2 then for k=1,#jokers do local bi=resolved[k]; if bi and names[bi]=='Baseball Card' and bi~=ji then mult=mult*extra(states[bi],nil,1.5) end end end
        if not j.debuff then edition(j,'after') end
    end
    for _,c in ipairs(snapshot.consumeables or {}) do if not c.debuff then
        edition(c,'before')
        local a=c.ability or {}
        if (snapshot.used_vouchers or {}).v_observatory and a.set=='Planet' and (a.consumeable or {}).hand_type==category then mult=mult*1.5 end
        edition(c,'after')
    end end
    if snapshot.deck_key=='b_plasma' or (snapshot.modifiers or {}).balance then local avg=(chips+mult)/2; chips=cap(avg); mult=avg end
    -- Original destruction rolls once per scoring Glass card, after enhancement
    -- changes and all retriggers. Fragile uses its live normal probability (4),
    -- so ordinary Glass breaks certainly there. Held/non-scoring cards never roll.
    local glass_exposure,glass_loss={},0
    for _,ci in ipairs(scoring) do
        local c=localcards[ci]
        if not c.debuff and enh(c)=='m_glass' then
            local probability=chance(num((c.ability or {}).extra,4))
            glass_exposure[#glass_exposure+1]={index=ci,probability=probability}
            glass_loss=glass_loss+probability
        end
    end
    local result={score=max(0,floor(chips*mult)), chips=chips, mult=mult, hand=category,
        warnings=warnings, scoring_indices=scoring, legal=true, uncertain=uncertain, expected_dollars=dollars-num(snapshot.dollars),
        glass_exposure=glass_exposure,glass_loss=glass_loss,created_cards=created_cards,
        sampled_lucky=sampled_lucky_events>0 or nil,sampled_lucky_events=sampled_lucky_events>0 and sampled_lucky_events or nil,
        score_kind=sampled_lucky_events>0 and 'private_sampled_lucky' or nil}
    if sampled_lucky_events>0 then result.score_guaranteed=false end
    return result
end

-- One additional scoring pass, with no sampling and no copied snapshot. The
-- result is a conservative immediate score for supported vanilla randomness;
-- hidden/unknown cards, Hook/DNA and unsupported effects retain uncertainty.
-- Glass exposure keeps its actual probability because loss follows scoring.
function M.lower_bound(snapshot,selected,prepared)
    local result=M.score(snapshot,selected,nil,true,prepared)
    result.reliable_bound=result.legal~=false and not result.uncertain
    result.bound_kind='supported_random_floor'
    return result
end

-- A deliberately restricted maximum, never an expected score. Independent
-- additive Joker effects resolve before independent multipliers, bounding any
-- ordering of the supported row. Callers must still cover every ordered play,
-- directly or through the separate proven order-equivalence admission below.
-- Copy routing, order-sensitive before callbacks, repeated-card identity and
-- mixed held additions/multipliers are declined rather than approximated.
local ceiling_blocked={Blueprint=true,Brainstorm=true,['Midas Mask']=true,Vampire=true,
    DNA=true,Hiker=true,['Hanging Chad']=true,Photograph=true,['Raised Fist']=true,
    ['Shoot the Moon']=true,['Baseball Card']=true,['Flower Pot']=true,['Seeing Double']=true}
local ceiling_individual_x={['The Idol']=true,Bloodstone=true,['Ancient Joker']=true,
    Triboulet=true,Baron=true}
local ceiling_main_x={Acrobat=true,['Steel Joker']=true,["Driver's License"]=true,
    Blackboard=true,['Joker Stencil']=true,Cavendish=true,['Card Sharp']=true,Caino=true,
    ['Loyalty Card']=true}
local ceiling_main_add={['Half Joker']=true,['Abstract Joker']=true,['Mystic Summit']=true,
    Misprint=true,Banner=true,Stuntman=true,Supernova=true,['Wee Joker']=true,Castle=true,
    ['Square Joker']=true,Runner=true,['Ice Cream']=true,['Blue Joker']=true,Erosion=true,
    ['Stone Joker']=true,Bull=true,['Fortune Teller']=true,['Gros Michel']=true,Bootstraps=true}
local ceiling_typed={['The Duo']=true,['The Trio']=true,['The Family']=true,
    ['The Order']=true,['The Tribe']=true,['Jolly Joker']=true,['Zany Joker']=true,
    ['Mad Joker']=true,['Crazy Joker']=true,['Droll Joker']=true,['Sly Joker']=true,
    ['Wily Joker']=true,['Clever Joker']=true,['Devious Joker']=true,['Crafty Joker']=true}
local ceiling_keys={}
for key in pairs(aliases) do ceiling_keys[key]=true end
for _,key in ipairs({'j_duo','j_trio','j_family','j_order','j_tribe','j_jolly','j_zany',
    'j_mad','j_crazy','j_droll','j_sly','j_wily','j_clever','j_devious','j_crafty',
    'j_perkeo','j_chicot','j_egg','j_credit_card','j_marble','j_burglar','j_golden',
    'j_rocket','j_satellite','j_to_the_moon','j_turtle_bean','j_diet_cola','j_mr_bones',
    'j_invisible','j_luchador','j_oops','j_certificate','j_juggler','j_troubadour',
    'j_drunkard','j_merry_andy','j_chaos','j_delayed_grat','j_cloud_9','j_hallucination',
    'j_gift','j_riff_raff','j_cartomancer','j_astronomer','j_showman','j_vagabond',
    'j_superposition','j_seance','j_8_ball','j_sixth_sense','j_matador','j_throwback',
    'j_greedy_joker','j_lusty_joker','j_wrathful_joker','j_gluttenous_joker'}) do ceiling_keys[key]=true end
local ceiling_blinds={}
for _,key in ipairs({'bl_small','bl_big','bl_hook','bl_ox','bl_house','bl_wall','bl_wheel',
    'bl_arm','bl_club','bl_fish','bl_psychic','bl_goad','bl_water','bl_window','bl_manacle',
    'bl_eye','bl_mouth','bl_plant','bl_serpent','bl_pillar','bl_needle','bl_head','bl_tooth',
    'bl_flint','bl_mark','bl_final_acorn','bl_final_leaf','bl_final_vessel','bl_final_heart',
    'bl_final_bell'}) do ceiling_blinds[key]=true end
local ceiling_blind_names={['Small Blind']=true,['Big Blind']=true,['Amber Acorn']=true,
    ['Verdant Leaf']=true,['Violet Vessel']=true,['Crimson Heart']=true,['Cerulean Bell']=true}
for _,n in ipairs({'Hook','Ox','House','Wall','Wheel','Arm','Club','Fish','Psychic','Goad',
    'Water','Window','Manacle','Eye','Mouth','Plant','Serpent','Pillar','Needle','Head',
    'Tooth','Flint','Mark'}) do ceiling_blind_names['The '..n]=true end
local function nonnegative_numbers(value)
    if type(value)=='number' then return value>=0 and value<math.huge end
    if type(value)=='table' then for _,v in pairs(value) do
        if not nonnegative_numbers(v) then return false end
    end end
    return true
end
local function ceiling_state(snapshot)
    local b=snapshot.blind or {}
    if not b.disabled and ((b.key and not ceiling_blinds[b.key]) or
        (b.name and not ceiling_blind_names[b.name])) then return nil,'Unknown blind mechanics.' end
    if not nonnegative_numbers(snapshot.hands or {}) or not nonnegative_numbers(snapshot.probabilities or {}) or
        num(snapshot.dollars)~=num(snapshot.dollars) or math.abs(num(snapshot.dollars))==math.huge then
        return nil,'Negative or nonfinite hand/probability mechanics.'
    end
    local state=copy(snapshot);state.jokers={}
    local categories={}
    local played_repeats,held_repeats=2,2 -- include a possible Red seal
    for i,j in ipairs(snapshot.jokers or {}) do
        local n,a=name(j),j.ability or {}
        if j.face_down or (j.key and not ceiling_keys[j.key]) or ceiling_blocked[n] or
            not (passive[n] or individual[n] or addmult_names[n] or xmult_names[n] or
                ceiling_main_x[n] or ceiling_main_add[n] or ceiling_typed[n]) then
            return nil,'Unsupported maximum for Joker '..n..'.'
        end
        if not nonnegative_numbers(a) or not nonnegative_numbers(j.edition or {}) then return nil,'Negative or nonfinite Joker mechanics.' end
        local ex=a.extra
        local scalar=type(ex)=='number' and ex or nil
        local shrink=(num(a.x_mult)>0 and num(a.x_mult)<1) or
            (ceiling_individual_x[n] and n~='Bloodstone' and scalar and scalar<1) or
            ((n=='Acrobat' or n=='Blackboard' or n=="Driver's License") and scalar and scalar<1) or
            ((n=='Cavendish' or n=='Card Sharp' or n=='Loyalty Card') and type(ex)=='table' and
                ex.Xmult~=nil and num(ex.Xmult)<1) or
            (n=='Bloodstone' and type(ex)=='table' and ex.Xmult~=nil and num(ex.Xmult)<1)
        if shrink then return nil,'Shrinking Joker multipliers are outside the maximum model.' end
        if j.edition=='holo' or j.edition=='polychrome' then return nil,'Nonstandard Joker edition representation.' end
        local edition=type(j.edition)=='table' and j.edition or {}
        if num(edition.mult,edition.holo and 10 or 0)~=0 or num(edition.x_mult,edition.polychrome and 1.5 or 1)~=1 then
            return nil,'Mixed Joker edition ordering is outside the maximum model.'
        end
        if individual[n] and num(a.x_mult)>1 then return nil,'Modified individual Joker also has a main multiplier.' end
        if not j.debuff then
            if n=='Mime' then held_repeats=held_repeats+num(a.extra,1)
            elseif n=='Dusk' or n=='Sock and Buskin' or n=='Hack' then played_repeats=played_repeats+num(a.extra,1)
            elseif n=='Seltzer' then played_repeats=played_repeats+1 end
        end
        local category=(ceiling_individual_x[n] or ceiling_main_x[n] or xmult_names[n] or num(a.x_mult)>1) and 1 or 0
        categories[j]=category;state.jokers[i]=j
    end
    -- Ordinary scoring intentionally has a 100-repetition execution guard.
    -- It cannot serve as a maximum when a large Negative row or modified
    -- retrigger count could exceed that guard in the source game.
    if played_repeats>100 or held_repeats>100 then return nil,'Potential source repetitions exceed the bounded scorer.' end
    -- Equal categories commute in the supported row. The stable source index
    -- avoids dependence on Lua's ordering of equivalent table.sort entries.
    local positions={};for i,j in ipairs(state.jokers) do positions[j]=i end
    table.sort(state.jokers,function(a,b)
        if categories[a]~=categories[b] then return categories[a]<categories[b] end
        return positions[a]<positions[b]
    end)
    for _,c in ipairs(snapshot.hand or {}) do
        local r=c.rank or (c.base or {}).id
        if type(r)~='number' or r%1~=0 or r<2 or r>14 or nominal(c)<0 or nominal(c)>=math.huge then
            return nil,'Unknown playing-card rank or nominal value.'
        end
        if not nonnegative_numbers(c.ability or {}) or not nonnegative_numbers(c.edition or {}) or
            num((c.ability or {}).h_mult)~=0 then return nil,'Unsupported held or negative card mechanics.' end
    end
    for _,c in ipairs(snapshot.consumeables or {}) do
        local e=type(c.edition)=='table' and c.edition or {}
        if c.face_down or c.edition=='holo' or c.edition=='polychrome' or not nonnegative_numbers(e) or num(e.mult,e.holo and 10 or 0)~=0 or
            num(e.x_mult,e.polychrome and 1.5 or 1)~=1 then
            return nil,'Mixed or concealed held-consumable scoring is outside the maximum model.'
        end
    end
    return state
end

-- Sufficient (not necessary) conditions for replacing ordered-play enumeration
-- with every unordered subset. This is an admission proof, not a score pass.
-- No selected/held card changes Mult, money, state or repetitions; the admitted
-- row only adds order-independent values. Poker category/scoring membership is
-- set-dependent for these plain cards, and equal-rank cards have equal nominal
-- chips. Individual callbacks, copies, multipliers and card editions decline.
local order_independent_passive={Juggler=true,Chicot=true,['Credit Card']=true,
    Egg=true,['Golden Joker']=true,['Burnt Joker']=true,Troubadour=true,Drunkard=true,
    ['Merry Andy']=true}
local function small_integers(value)
    if type(value)=='number' then return value>=0 and value<=1048576 and value%1==0 end
    if type(value)=='table' then for _,v in pairs(value) do if not small_integers(v) then return false end end end
    return true
end
local function integer_fields(value,fields)
    for _,field in ipairs(fields) do
        if value[field]~=nil and (type(value[field])~='number' or not small_integers(value[field])) then return false end
    end
    return true
end
local function integer_values(value)
    if type(value)=='number' then return small_integers(value) end
    if type(value)~='table' then return false end
    for _,v in pairs(value) do if not integer_values(v) then return false end end
    return true
end
function M.upper_bound_order_independent(snapshot)
    local state,reason=ceiling_state(snapshot)
    if not state then return false,reason end
    local cards,jokers=snapshot.hand or {},snapshot.jokers or {}
    if #cards<1 or #cards>20 or #jokers>20 or type(snapshot.deck)~='table' or
        type(snapshot.playing_cards)~='table' or #snapshot.deck>120 or #snapshot.playing_cards>120 or
        #(snapshot.consumeables or {})>120 then
        return false,'Plain additive order equivalence requires bounded complete card lists and row.'
    end
    if snapshot.deck_key=='b_plasma' or (snapshot.modifiers or {}).balance or
        (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory then
        return false,'Balancing and Observatory are outside plain additive order equivalence.'
    end
    if not small_integers(snapshot.hands or {}) or not integer_values(snapshot.consumeable_usage_total or {}) or
        not integer_values(snapshot.probabilities or {}) or
        snapshot.dollars~=nil and type(snapshot.dollars)~='number' or
        math.abs(num(snapshot.dollars))>1048576 or num(snapshot.dollars)%1~=0 then
        return false,'Order equivalence requires bounded exact integer score inputs.'
    end
    for _,h in pairs(snapshot.hands or {}) do
        if type(h)~='table' or not integer_fields(h,{'chips','mult','l_chips','l_mult','level','played','played_this_round'}) then
            return false,'Noninteger or large poker-hand score input.'
        end
    end
    if not integer_fields(snapshot,{'starting_deck_size','first_used_hand_level','hands_left','discards_left'}) then
        return false,'Noninteger or large scoring resource.'
    end
    local round=snapshot.current_round or {}
    if not integer_fields(round,{'hands_left','discards_left'}) then
        return false,'Noninteger or large round resource.'
    end
    for _,c in ipairs(cards) do
        local a=c.ability or {};local r=c.rank or (c.base or {}).id
        if c.face_down or enh(c)~='c_base' or (c.key and c.key~='c_base') or c.seal or
            c.edition~=nil and (type(c.edition)~='table' or next(c.edition)~=nil) or
            nominal(c)~=(r==14 and 11 or min(r,10)) or not small_integers(a) then
            return false,'Order equivalence requires visible plain unsealed uneditioned cards.'
        end
        for _,field in ipairs({'bonus','perma_bonus','mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips'}) do
            if a[field]~=nil and (type(a[field])~='number' or a[field]~=0) then
                return false,'A playing-card score modifier prevents order equivalence.'
            end
        end
        if a.x_mult~=nil and a.x_mult~=1 then return false,'A playing-card multiplier prevents order equivalence.' end
    end
    for _,j in ipairs(jokers) do
        local n,a=name(j),j.ability or {}
        if not (addmult_names[n] or ceiling_main_add[n] or ceiling_typed[n] or order_independent_passive[n]) or
            not small_integers(a) or not small_integers(j.edition or {}) or
            not integer_fields(a,{'mult','t_mult','t_chips','bonus','perma_bonus','chips','stone_tally'}) or
            a.extra~=nil and not integer_values(a.extra) or
            type(j.edition)=='table' and not integer_fields(j.edition,{'chips','mult','x_mult'}) or
            a.x_mult~=nil and a.x_mult~=1 then
            return false,'The Joker row is outside independent bounded additive effects.'
        end
    end
    for _,c in ipairs(snapshot.consumeables or {}) do
        if not small_integers(c.edition or {}) or
            type(c.edition)=='table' and not integer_fields(c.edition,{'chips','mult','x_mult'}) then
            return false,'Noninteger held-consumable scoring.'
        end
    end
    -- With <=20 rows/held cards, <=120 consumables, and each input <=2^20,
    -- the largest added term is <=2^40 (cash/tally scaling or hand-level boost).
    -- Their aggregate is below 2^46, hence every chip/Mult addition is exact in
    -- binary64. The same final product is computed for every equivalent order.
    return true,'All ordered plays in each subset share the same supported maximum.'
end
function M.upper_bound(snapshot,selected,prepared)
    local state,reason
    if prepared then
        prepared.ceiling_states=prepared.ceiling_states or setmetatable({},{__mode='k'})
        local cached=prepared.ceiling_states[snapshot]
        if not cached then
            state,reason=ceiling_state(snapshot);cached={state=state,reason=reason};prepared.ceiling_states[snapshot]=cached
        end
        state,reason=cached.state,cached.reason
    else state,reason=ceiling_state(snapshot) end
    if not state then return {score=0,legal=true,uncertain=true,reliable_bound=false,
        bound_kind='supported_random_ceiling',warnings={reason}} end
    local result=M.score(state,selected,nil,'ceiling',prepared)
    result.reliable_bound=not result.uncertain and result.score==result.score and result.score<math.huge
    result.bound_kind='supported_random_ceiling'
    result.order_scope='Independent Joker orders; one supplied ordered play.'
    return result
end

detached=function(value, seen)
    if type(value)~='table' then
        if type(value)=='number' or type(value)=='string' or type(value)=='boolean' then return value end
        return nil
    end
    seen=seen or {}; if seen[value] then return seen[value] end
    local result={}; seen[value]=result
    for k,v in pairs(value) do if type(k)=='number' or type(k)=='string' then result[k]=detached(v,seen) end end
    return result
end

-- Resolves the original Blueprint/Brainstorm callback route. Copy eligibility
-- is enforced by each effect's context.blueprint branch; the source callback
-- does not inspect the UI's blueprint_compat label. Cycles have no effect.
local function discard_target(jokers,index,seen)
    local j=jokers[index]
    if not j or j.debuff then return nil end
    seen=seen or {}; if seen[index] then return nil end; seen[index]=true
    local n=name(j)
    if n=='Blueprint' then return discard_target(jokers,index+1,seen)
    elseif n=='Brainstorm' then return discard_target(jokers,1,seen) end
    return index
end

population_ids=function(snapshot,required)
    local ids={}
    for _,c in ipairs(snapshot.playing_cards or {}) do
        if not c.id or ids[c.id] then return nil,'Population mutation requires unique full-population identities.' end
        ids[c.id]=true
    end
    for _,c in ipairs(required or {}) do
        if not c.id or not ids[c.id] then return nil,'Population target is absent from the full population.' end
    end
    return ids
end

local function refresh_population_tallies(state)
    local steel,stone,enhanced=0,0,0
    for _,c in ipairs(state.playing_cards or {}) do
        local e=enh(c)
        steel=steel+(e=='m_steel' and 1 or 0);stone=stone+(e=='m_stone' and 1 or 0)
        enhanced=enhanced+(e~='c_base' and 1 or 0)
    end
    for _,j in ipairs(state.jokers or {}) do
        local n,a=name(j),j.ability or {};j.ability=a
        if n=='Steel Joker' then a.steel_tally=steel
        elseif n=='Stone Joker' then a.stone_tally=stone
        elseif n=="Driver's License" then a.driver_tally=enhanced end
    end
end

-- Exact supported discard callbacks and resources, BEFORE replacement draws.
-- No RNG/live callbacks. The caller supplies Bell/Serpent replacement draws.
-- Success also returns effect metadata; unsupported population/generation
-- effects return nil, reason so continuation cannot silently invent certainty.
function M.after_discard(snapshot, selected, context)
    context=context or {}
    local round=snapshot.current_round or {}
    if not context.hook and num(snapshot.discards_left,round.discards_left)<=0 then return nil,'No discards remain.' end
    if #selected<1 or #selected>5 then return nil,'Select one to five cards.' end
    local chosen,ordered={},{}
    for _,ci in ipairs(selected) do
        local c=(snapshot.hand or {})[ci]
        if not c or chosen[ci] then return nil,'Invalid or duplicate card selection.' end
        chosen[ci]=true; ordered[#ordered+1]=ci
    end
    table.sort(ordered)
    if not context.hook then
        for ci,c in ipairs(snapshot.hand or {}) do
            if (c.ability or {}).forced_selection and not chosen[ci] then
                return nil,'Include the card forced by Cerulean Bell.'
            end
        end
    end
    local used=num(snapshot.discards_used,round.discards_used)
    local trading=0
    for _,j in ipairs(snapshot.jokers or {}) do if not j.debuff then
        local n,a=name(j),j.ability or {}
        if n=='Trading Card' and used<=0 and #selected==1 then trading=trading+1 end
        if n=='Yorick' and (type(a.yorick_discards)~='number' or type(a.extra)~='table' or
            type(a.extra.discards)~='number' or type(a.extra.xmult)~='number' or type(a.x_mult)~='number') then
            return nil,'Yorick live growth fields are unavailable.'
        end
    end end
    if trading>0 then
        local ids,reason=population_ids(snapshot,{snapshot.hand[ordered[1]]})
        if not ids then return nil,reason end
    end
    local state=detached(snapshot)
    local effects={discarded_count=#ordered,burnt_levels=0,yorick_growth=0,dollars=0,
        destroyed_indices={},destroyed_cards={},population_delta=0,generated_consumables={}}
    local occupied=#(snapshot.consumeables or {})+num(snapshot.consumeable_buffer)
    for _,ci in ipairs(ordered) do local c=state.hand[ci]
        if not c.debuff and c.seal=='Purple' and occupied<num(snapshot.consumable_limit,2) then
            local generated=(context.generated_consumables or {})[ci]
            if type(generated)~='table' or type(generated.key)~='string' or
                type(generated.ability)~='table' or generated.ability.set~='Tarot' then
                return nil,'Purple Seal generation needs an explicit full Tarot outcome.'
            end
            local created=detached(generated)
            state.consumeables=state.consumeables or {};state.consumeables[#state.consumeables+1]=created
            effects.generated_consumables[#effects.generated_consumables+1]=created;occupied=occupied+1
        end
    end
    if #effects.generated_consumables>0 then state.consumeable_buffer=0 end
    local jokers=state.jokers or {}
    -- Burnt runs before individual discarded-card effects and uses the actual
    -- category, even when this blind would forbid playing that category.
    if used<=0 and not context.hook then
        for i=1,#jokers do
            local ri=discard_target(jokers,i)
            if ri and name(jokers[ri])=='Burnt Joker' then
                effects.burnt_levels=effects.burnt_levels+1
            end
        end
        if effects.burnt_levels>0 then
            local category=M.classify(state,ordered)
            effects.burnt_hand=category
            state.hands=state.hands or {}
            local h=state.hands[category] or {}; state.hands[category]=h
            local d=hand_defaults[category]
            local level=num(h.level,1)
            local lc,lm=num(h.l_chips,d[3]),num(h.l_mult,d[4])
            -- Live s_chips/s_mult are authoritative. Older reduced fixtures
            -- can reconstruct them from their pre-upgrade level and values.
            local sc=num(h.s_chips,num(h.chips,d[1])-lc*(level-1))
            local sm=num(h.s_mult,num(h.mult,d[2])-lm*(level-1))
            h.level=max(0,level+effects.burnt_levels)
            h.chips=max(0,sc+lc*(h.level-1)); h.mult=max(1,sm+lm*(h.level-1))
        end
    end
    local f=flags(jokers)
    local removed={}
    for position,ci in ipairs(ordered) do
        local c=state.hand[ci]
        for i,j in ipairs(jokers) do if not j.debuff then
            local n,a=name(j),j.ability or {}; j.ability=a
            -- Physical growth is never repeated by a copying Joker.
            if n=='Yorick' then
                if a.yorick_discards<=1 then
                    a.yorick_discards=a.extra.discards; a.x_mult=a.x_mult+a.extra.xmult
                    effects.yorick_growth=effects.yorick_growth+a.extra.xmult
                else a.yorick_discards=a.yorick_discards-1 end
            elseif n=='Green Joker' and position==#ordered then
                local loss=type(a.extra)=='table' and num(a.extra.discard_sub,1) or 1
                a.mult=max(0,num(a.mult)-loss)
            elseif n=='Ramen' and not removed[i] then
                local loss=type(a.extra)=='number' and a.extra or 0.01
                if num(a.x_mult,2)-loss<=1 then removed[i]=true
                else a.x_mult=num(a.x_mult,2)-loss end
            elseif n=='Castle' and not c.debuff and suit(c,(round.castle_card or {}).suit,f) then
                a.extra=a.extra or {}; a.extra.chips=num(a.extra.chips)+num(a.extra.chip_mod,3)
            elseif n=='Hit the Road' and not c.debuff and rank(c)==11 then
                a.x_mult=num(a.x_mult,1)+num(a.extra,0.5)
            elseif n=='Trading Card' and trading>0 then
                effects.dollars=effects.dollars+num(a.extra,3)
            end
            local ri=discard_target(jokers,i)
            if ri then
                local target=jokers[ri]; local rn,ra=name(target),target.ability or {}
                if rn=='Mail-In Rebate' and not c.debuff and rank(c)==(round.mail_card or {}).id then
                    effects.dollars=effects.dollars+num(ra.extra,5)
                elseif rn=='Faceless Joker' and position==#ordered then
                    local count=0
                    for _,index in ipairs(ordered) do if face(state.hand[index],f) then count=count+1 end end
                    local aextra=type(ra.extra)=='table' and ra.extra or {}
                    if count>=num(aextra.faces,3) then effects.dollars=effects.dollars+num(aextra.dollars,5) end
                end
            end
        end end
        c.ability=c.ability or {}
        if trading>0 then
            if enh(c)=='m_glass' then c.shattered=true end
            effects.destroyed_indices[#effects.destroyed_indices+1]=ci
            effects.destroyed_cards[#effects.destroyed_cards+1]=c
            effects.population_delta=effects.population_delta-1
        else c.ability.discarded=true end
    end
    if trading>0 then
        local gone,faces,glass={},0,0
        for _,c in ipairs(effects.destroyed_cards) do
            gone[c.id]=true;faces=faces+(face(c,f) and 1 or 0);glass=glass+(c.shattered and 1 or 0)
        end
        for _,j in ipairs(jokers) do if not j.debuff then
            local n,a=name(j),j.ability
            if n=='Caino' then a.caino_xmult=num(a.caino_xmult,1)+faces*num(a.extra,1)
            elseif n=='Glass Joker' then a.x_mult=num(a.x_mult,1)+glass*num(a.extra,0.75) end
        end end
        for _,area in ipairs({'playing_cards','deck','discard','play'}) do
            local remaining={}
            for _,c in ipairs(state[area] or {}) do if not gone[c.id] then remaining[#remaining+1]=c end end
            state[area]=remaining
        end
        refresh_population_tallies(state)
    end
    local remaining={}
    for i,j in ipairs(jokers) do
        if removed[i] then
            if (j.edition or {}).negative then state.joker_limit=num(state.joker_limit,5)-1 end
            state.hand_size=num(state.hand_size,8)-num((j.ability or {}).h_size)
        else remaining[#remaining+1]=j end
    end
    state.jokers=remaining
    if next(removed) then
        local stencils=0
        for _,j in ipairs(remaining) do if name(j)=='Joker Stencil' then stencils=stencils+1 end end
        for _,j in ipairs(remaining) do
            if name(j)=='Joker Stencil' then j.ability.x_mult=num(state.joker_limit,5)-#remaining+stencils
            elseif name(j)=='Swashbuckler' then
                local total=0; for _,other in ipairs(remaining) do if other~=j then total=total+num(other.sell_cost) end end
                j.ability.mult=total
            end
        end
    end
    local held={}
    for i,c in ipairs(state.hand) do if not chosen[i] then held[#held+1]=c end end
    -- Preserve shared identity when snapshots refer to the same card table;
    -- also handle independently copied population records via their live IDs.
    local changed={}
    for _,ci in ipairs(ordered) do local c=state.hand[ci]; if c.id then changed[c.id]=c end end
    for i,c in ipairs(state.playing_cards or {}) do state.playing_cards[i]=changed[c.id] or c end
    for _,area in ipairs({state.hand,state.playing_cards or {},state.deck or {}}) do
        for _,c in ipairs(area) do if c.ability then c.ability.forced_selection=nil end end
    end
    state.hand=held
    state.current_round=state.current_round or {}
    state.discards_left=num(snapshot.discards_left,round.discards_left)-(context.hook and 0 or 1)
    state.discards_used=used+(context.hook and 0 or 1)
    state.current_round.discards_left=state.discards_left; state.current_round.discards_used=state.discards_used
    effects.dollars=effects.dollars-(context.hook and 0 or num((snapshot.modifiers or {}).discard_cost))
    state.dollars=num(snapshot.dollars)+effects.dollars
    local tax=num((snapshot.modifiers or {}).minus_hand_size_per_X_dollar)
    if tax>0 then state.hand_size=num(state.hand_size,8)+floor(num(snapshot.dollars)/tax)-floor(state.dollars/tax) end
    return state,effects
end

-- Hook's draws are not observed. The caller provides two sampled held indices
-- (or all held cards if fewer), in the ORIGINAL snapshot's hand coordinates.
-- This applies the actual unpaid discard before scoring and preserves card IDs.
function M.prepare_play(snapshot,selected,context)
    context=context or {};local blind=snapshot.blind or {}
    if blind.disabled or blind.hook_resolved or blind.name~='The Hook' and blind.key~='bl_hook' then
        return snapshot,selected,{original_indices={}}
    end
    local chosen={}
    if #selected<1 or #selected>5 then return nil,'Select one to five cards.' end
    for _,i in ipairs(selected) do if not (snapshot.hand or {})[i] or chosen[i] then return nil,'Invalid or duplicate card selection.' end;chosen[i]=true end
    local needed=min(2,#snapshot.hand-#selected);local indices=context.hook_indices or {}
    if #indices~=needed then return nil,'The Hook needs an explicit sampled held-card selection.' end
    local removed={}
    for _,i in ipairs(indices) do
        if not snapshot.hand[i] or chosen[i] or removed[i] then return nil,'Invalid sampled Hook selection.' end
        removed[i]=true
    end
    local state,effects
    if needed==0 then state=detached(snapshot);effects={dollars=0,population_delta=0}
    else state,effects=M.after_discard(snapshot,indices,{hook=true,generated_consumables=context.generated_consumables}) end
    if not state then return nil,effects end
    local to_new,to_original={},{}
    for i=1,#snapshot.hand do if not removed[i] then local n=#to_original+1;to_original[n]=i;to_new[i]=n end end
    local remapped={};for _,i in ipairs(selected) do remapped[#remapped+1]=to_new[i] end
    state.blind=state.blind or {};state.blind.hook_resolved=true
    effects.original_indices=to_original;effects.remapped_indices=to_new;effects.hook_indices=detached(indices)
    return state,remapped,effects
end

-- Exact finite Hook outcome family, with supported random floors afterwards.
-- Work is explicit so callers cannot count an exhaustive floor as one score.
-- Unknown generation/effects or an insufficient allowance certify nothing.
function M.hook_lower_bound(snapshot,selected,allowance,floor_score)
    local b=snapshot.blind or {}
    if b.disabled or b.hook_resolved or b.key~='bl_hook' and b.name~='The Hook' then return nil,0 end
    local chosen,held={},{}
    for _,i in ipairs(selected) do
        if chosen[i] or not (snapshot.hand or {})[i] then return nil,0 end
        chosen[i]=true
    end
    for i,c in ipairs(snapshot.hand or {}) do
        if c.face_down or c.unknown or c.identity_redacted then return nil,0 end
        if not chosen[i] then held[#held+1]=i end
    end
    local outcomes={}
    if #held<2 then outcomes[1]=held
    else for i=1,#held-1 do for j=i+1,#held do outcomes[#outcomes+1]={held[i],held[j]} end end end
    if type(allowance)~='number' or allowance~=allowance or allowance%1~=0 or #outcomes>allowance then return nil,0 end
    local worst,work=nil,0
    for _,indices in ipairs(outcomes) do
        local state,remapped,effects=M.prepare_play(snapshot,selected,{hook_indices=indices})
        if not state then return nil,work end
        local bound=(floor_score or M.lower_bound)(state,remapped);work=work+1
        if not bound or not bound.reliable_bound then return nil,work end
        for i,index in ipairs(bound.scoring_indices or {}) do
            bound.scoring_indices[i]=effects.original_indices[index]
        end
        for _,exposure in ipairs(bound.glass_exposure or {}) do
            exposure.index=effects.original_indices[exposure.index]
        end
        if not worst or bound.score<worst.score then worst=bound end
    end
    if worst then
        worst.bound_kind='complete_hook_random_floor'
        worst.hook_outcomes=#outcomes;worst.hook_floor=true
    end
    return worst,work
end

local function expired(j)
    local a=j.ability or {};return a.perishable and num(a.perish_tally)<=0
end
function M.crimson_candidates(snapshot)
    local indices={};local jokers=snapshot.jokers or {}
    for i,j in ipairs(jokers) do if not j.debuff or #jokers<2 then indices[#indices+1]=i end end
    return indices
end

-- Crimson Heart changes Joker debuffs AFTER the replacement draw. Applying
-- this before drawing would use the wrong capacity for Turtle Bean/Stuntman.
-- Scope is the remaining blind; shop price refreshes occur in the live refresh.
function M.after_draw(snapshot,context)
    local b=snapshot.blind or {};context=context or {}
    if b.disabled or not b.crimson_pending then return snapshot,{changed=false} end
    local eligible=M.crimson_candidates(snapshot);local wanted=context.crimson_index
    local allowed=#eligible==0 and wanted==nil
    for _,i in ipairs(eligible) do if i==wanted then allowed=true end end
    if not allowed then return nil,'Crimson Heart needs an explicit eligible Joker outcome.' end
    local state=detached(snapshot);state.current_round=state.current_round or {};state.round_resets=state.round_resets or {}
    local function switch(j,on)
        if expired(j) then on=true end
        if not not j.debuff==not not on then return true end
        local a,n=j.ability or {},name(j);j.ability=a
        if not alias_names[n] and not passive[n] and not individual[n] and not addmult_names[n] and not xmult_names[n] and
            not ({['Steel Joker']=true,['Stone Joker']=true,["Driver's License"]=true,['Erosion']=true,['Bull']=true,['Joker Stencil']=true,['Blackboard']=true,['Bootstraps']=true,['Caino']=true})[n] then
            return nil,'Unmodeled Joker debuff resources: '..n
        end
        if n=='Chicot' and not on then return nil,'Reactivating Chicot requires a full blind-disable transition.' end
        local direction=on and -1 or 1
        state.hand_size=num(state.hand_size,8)+direction*num(a.h_size)
        if num(a.d_size)>0 then
            state.discards_left=num(state.discards_left,state.current_round.discards_left)+direction*a.d_size
            state.current_round.discards_left=state.discards_left
            state.round_resets.discards=num(state.round_resets.discards)+direction*a.d_size
        end
        if n=='Turtle Bean' or n=='Troubadour' then
            state.hand_size=state.hand_size+direction*num(type(a.extra)=='table' and a.extra.h_size)
            if n=='Troubadour' then state.round_resets.hands=num(state.round_resets.hands)+direction*num(type(a.extra)=='table' and a.extra.h_plays) end
        elseif n=='Stuntman' then state.hand_size=state.hand_size-direction*num(type(a.extra)=='table' and a.extra.h_size)
        elseif n=='Oops! All 6s' then
            state.probabilities=state.probabilities or {normal=1}
            for k,v in pairs(state.probabilities) do if type(v)=='number' then state.probabilities[k]=v*(on and 0.5 or 2) end end
        elseif n=='Credit Card' then state.bankrupt_at=num(state.bankrupt_at)-direction*num(a.extra,20)
        elseif n=='To the Moon' then state.interest_amount=num(state.interest_amount,1)+direction*num(a.extra,1)
        elseif n=='Chaos the Clown' then state.current_round.free_rerolls=num(state.current_round.free_rerolls)+direction end
        if (j.edition or {}).negative then a.queue_negative_removal=on and true or nil end
        j.debuff=not not on;return true
    end
    -- Eligibility uses old debuffs; all cards are restored before the selection.
    for _,j in ipairs(state.jokers or {}) do local ok,reason=switch(j,false);if not ok then return nil,reason end end
    if wanted then local ok,reason=switch(state.jokers[wanted],true);if not ok then return nil,reason end end
    state.blind.crimson_pending=nil;state.blind.prepped=nil
    return state,{changed=true,crimson_index=wanted,scope='remaining_blind'}
end

-- A detached state after the play resolves, BEFORE replacement cards are drawn.
-- The caller samples the remaining deck and applies Bell/Serpent draw rules.
-- Random scoring/growth shares score()'s mean model unless an explicit private
-- no-owned-Joker Lucky event family is supplied. An opt-in owned-Joker
-- no-trigger floor is supported only for concealed continuation. Such a score
-- is not a calibrated Lucky outcome frequency. A sampled score is not a
-- guaranteed real outcome. Certain Glass loss is
-- exact; uncertain destruction needs an explicit sampled boolean per exposed
-- hand index in context.glass_outcomes, otherwise no future state is invented.
local function blocked_mouth(snapshot,selected,result)
    local b=snapshot.blind or {}
    if b.disabled or (b.key~='bl_mouth' and b.name~='The Mouth') or
        type(b.only_hand)~='string' or result.reason~='The Mouth requires '..b.only_hand..'.' then return end
    -- Vanilla debuffed-hand callbacks skip before/scoring effects. Matador,
    -- post-hand decay, and custom callbacks require separate transitions.
    local inert={Yorick=true,Perkeo=true,Blueprint=true,Brainstorm=true,['Green Joker']=true,
        Joker=true,['Smiley Face']=true,['The Duo']=true,['The Trio']=true,['The Family']=true,
        ['The Order']=true,['The Tribe']=true,['Wily Joker']=true,['Sly Joker']=true,
        ['Clever Joker']=true,['Devious Joker']=true,['Crafty Joker']=true,['Droll Joker']=true,
        ['Jolly Joker']=true,['Zany Joker']=true,['Mad Joker']=true,['Crazy Joker']=true,
        ['Shoot the Moon']=true,['Blue Joker']=true,Supernova=true,Swashbuckler=true,
        ['Abstract Joker']=true,['Card Sharp']=true,Scholar=true,['Scary Face']=true}
    local extra_keys={j_perkeo='Perkeo',j_jolly='Jolly Joker',j_zany='Zany Joker',j_mad='Mad Joker',
        j_crazy='Crazy Joker',j_droll='Droll Joker',j_sly='Sly Joker',j_wily='Wily Joker',
        j_clever='Clever Joker',j_devious='Devious Joker',j_crafty='Crafty Joker',
        j_duo='The Duo',j_trio='The Trio',j_family='The Family',j_order='The Order',j_tribe='The Tribe'}
    for _,j in ipairs(snapshot.jokers or {}) do
        if j.face_down or j.identity_redacted or not inert[name(j)] or
            j.key and (aliases[j.key] or extra_keys[j.key])~=name(j) then return end
    end
    for _,c in ipairs(snapshot.hand or {}) do
        local r=rank(c)
        if c.face_down or c.identity_redacted or not known_enhancements[enh(c)] or
            enh(c)~='m_stone' and (not finite_nonnegative(r) or r<2 or r>14 or r%1~=0) then return end
    end
    local state=detached(snapshot);local round=snapshot.current_round or {}
    state.hands_left=num(snapshot.hands_left,round.hands_left)-1
    state.hands_played=num(snapshot.hands_played,round.hands_played)+1
    state.hands_played_total=num(snapshot.hands_played_total)+1
    state.current_round=state.current_round or {}
    state.current_round.hands_left=state.hands_left;state.current_round.hands_played=state.hands_played
    state.last_hand_played=result.hand;state.hands=state.hands or {}
    local hs=state.hands[result.hand] or {};state.hands[result.hand]=hs
    hs.played=num(hs.played)+1;hs.played_this_round=num(hs.played_this_round)+1;hs.visible=true
    local chosen,scored,changed={},{},{}
    for _,i in ipairs(result.scoring_indices or {}) do scored[i]=true end
    for _,i in ipairs(selected) do
        chosen[i]=true;local c=state.hand[i];c.ability=c.ability or {};c.base=c.base or {}
        c.ability.forced_selection=nil;c.ability.played_this_ante=true
        c.base.times_played=num(c.base.times_played)+1
        if scored[i] and (state.modifiers or {}).debuff_played_cards then c.ability.perma_debuff=true;c.debuff=true end
        if c.id then changed[c.id]=c end
    end
    local held={};for i,c in ipairs(state.hand) do if not chosen[i] then held[#held+1]=c end end
    state.hand=held
    for i,c in ipairs(state.playing_cards or {}) do state.playing_cards[i]=changed[c.id] or c end
    local actual=copy(result);actual.legal=true;actual.score=0;actual.uncertain=false;actual.blocked_mouth=true
    return state,{blocked_mouth=true,population_delta=0,destroyed_indices={}},actual
end
function M.after_play(snapshot, selected, context)
    context=context or {}
    if context.lucky_error then return nil,context.lucky_error end
    if context.lucky_outcomes~=nil and type(context.lucky_outcomes)~='table' then
        return nil,'Sampled Lucky effects require an explicit outcome table.'
    end
    local blind=snapshot.blind or {}
    local bn=not blind.disabled and (blind.name or ({bl_hook='The Hook',bl_final_heart='Crimson Heart'})[blind.key])
    if bn=='The Hook' and not blind.hook_resolved then
        local before,remapped,hook=M.prepare_play(snapshot,selected,context)
        if not before then return nil,remapped end
        local nested=copy(context);nested.glass_outcomes={}
        for original,new in pairs(hook.remapped_indices or {}) do nested.glass_outcomes[new]=(context.glass_outcomes or {})[original] end
        if context.lucky_outcomes~=nil then
            nested.lucky_outcomes={}
            for original,new in pairs(hook.remapped_indices or {}) do nested.lucky_outcomes[new]=context.lucky_outcomes[original] end
        end
        local state,effects,result=M.after_play(before,remapped,nested)
        if not state then return nil,effects end
        state.blind.hook_resolved=nil;effects.hook=hook
        effects.population_delta=num(effects.population_delta)+num(hook.population_delta)
        for i,ci in ipairs(effects.destroyed_indices or {}) do effects.destroyed_indices[i]=hook.original_indices[ci] end
        for i,ci in ipairs(result.scoring_indices or {}) do result.scoring_indices[i]=hook.original_indices[ci] end
        for _,exposure in ipairs(result.glass_exposure or {}) do exposure.index=hook.original_indices[exposure.index] end
        result.expected_dollars=num(result.expected_dollars)+num(hook.dollars)
        return state,effects,result
    end
    if bn=='Crimson Heart' and not context.defer_crimson then return nil,'Crimson Heart needs an explicit deferred draw outcome.' end
    local round=snapshot.current_round or {}
    if num(snapshot.hands_left,round.hands_left)<=0 then return nil,'No hands remain.' end
    for _,j in ipairs(snapshot.jokers or {}) do if not j.debuff then
        local n=name(j)
        if num(snapshot.hands_played,round.hands_played)==0 and #selected==1 and
            n=='Sixth Sense' and snapshot.hand[selected[1]] and rank(snapshot.hand[selected[1]])==6 then
            return nil,n..' changes the card population.'
        end
        if n=='Matador' then return nil,'Matador earnings are not modeled for a follow-up hand.' end
    end end
    local next_state=detached(snapshot)
    local transition={lucky_outcomes=context.lucky_outcomes,lucky_floor=context.lucky_floor}
    local result=M.score(next_state,selected,transition)
    if not result.legal then
        local state,effects,actual=blocked_mouth(snapshot,selected,result)
        if state then return state,effects,actual end
        return nil,result.reason
    end
    if transition.unsupported then return nil,transition.unsupported end
    local destroyed,destroyed_ids,destroyed_cards={},{},{}
    local effects={destroyed_indices={},destroyed_cards=destroyed_cards,population_delta=0}
    effects.sampled_lucky=result.sampled_lucky;effects.sampled_lucky_events=result.sampled_lucky_events
    local f=flags(next_state.jokers)
    local destroyed_faces=0
    for _,exposure in ipairs(result.glass_exposure or {}) do
        local ci,p=exposure.index,exposure.probability
        local outcome=p>=1
        if p>0 and p<1 then
            outcome=(context.glass_outcomes or {})[ci]
            if type(outcome)~='boolean' then return nil,'Glass destruction needs an explicit sampled outcome for a follow-up hand.' end
            effects.sampled_glass=true
        end
        if outcome then
            local c=transition.cards[ci]
            c.shattered=true; destroyed[ci]=true
            if c.id then destroyed_ids[c.id]=true end
            destroyed_cards[#destroyed_cards+1]=c
            effects.destroyed_indices[#effects.destroyed_indices+1]=ci
            if face(c,f) then destroyed_faces=destroyed_faces+1 end
        end
    end
    effects.created_cards=transition.created_cards or {};effects.created_count=#effects.created_cards
    effects.population_delta=effects.created_count-#destroyed_cards
    local dollars=num(snapshot.dollars)+num(result.expected_dollars)
    local tax=num((snapshot.modifiers or {}).minus_hand_size_per_X_dollar)
    if tax>0 then
        if result.uncertain and dollars~=num(snapshot.dollars) then
            return nil,'Uncertain earnings may change the next hand size.'
        end
        -- CardArea:update subtracts floor(dollars / X); negative money can
        -- increase hand size too. Start from the already-adjusted live limit.
        next_state.hand_size=num(snapshot.hand_size,8)+floor(num(snapshot.dollars)/tax)-floor(dollars/tax)
    end
    next_state.dollars=dollars
    next_state.chips=num(snapshot.chips)+result.score
    next_state.hands_left=num(snapshot.hands_left,round.hands_left)-1
    next_state.hands_played=num(snapshot.hands_played,round.hands_played)+1
    next_state.hands_played_total=num(snapshot.hands_played_total)+1
    next_state.current_round=next_state.current_round or {}
    next_state.current_round.hands_left=next_state.hands_left
    next_state.current_round.hands_played=next_state.hands_played
    next_state.last_hand_played=result.hand
    if num(snapshot.first_used_hand_level)>0 then next_state.first_used_hand_level=nil end
    next_state.hands=next_state.hands or {}
    local hs=next_state.hands[result.hand] or {}; next_state.hands[result.hand]=hs
    hs.level=transition.level; hs.chips=transition.hand_chips; hs.mult=transition.hand_mult
    hs.played=num(hs.played)+1; hs.played_this_round=num(hs.played_this_round)+1; hs.visible=true
    next_state.blind=next_state.blind or {}
    if not blind.disabled then
        if blind.name=='The Eye' or blind.key=='bl_eye' then
            next_state.blind.hands=next_state.blind.hands or {}; next_state.blind.hands[result.hand]=true
        elseif blind.name=='The Mouth' or blind.key=='bl_mouth' then next_state.blind.only_hand=result.hand end
    end

    local chosen,changed,scored={},{},{}
    for _,ci in ipairs(result.scoring_indices) do scored[ci]=true end
    local delta_steel,delta_stone,delta_enhanced=0,0,0
    for _,ci in ipairs(selected) do
        chosen[ci]=true
        local original=next_state.hand[ci]; local c=transition.cards[ci]
        c.vampired=nil; c.ability.forced_selection=nil; c.ability.played_this_ante=true
        c.base=c.base or {}; c.base.times_played=num(c.base.times_played)+1
        if scored[ci] and (snapshot.modifiers or {}).debuff_played_cards then c.ability.perma_debuff=true; c.debuff=true end
        if original.id then changed[original.id]=c end
        changed[original]=c
        local before,after=enh(original),destroyed[ci] and 'c_base' or enh(c)
        delta_steel=delta_steel+(after=='m_steel' and 1 or 0)-(before=='m_steel' and 1 or 0)
        delta_stone=delta_stone+(after=='m_stone' and 1 or 0)-(before=='m_stone' and 1 or 0)
        delta_enhanced=delta_enhanced+(after~='c_base' and 1 or 0)-(before~='c_base' and 1 or 0)
    end
    local population={}
    for _,c in ipairs(next_state.playing_cards or {}) do
        local updated=changed[c.id] or changed[c] or c
        if not destroyed_ids[c.id] and not updated.shattered then
            if updated.ability then updated.ability.forced_selection=nil end
            population[#population+1]=updated
        end
    end
    next_state.playing_cards=population
    local held={}
    for i,c in ipairs(next_state.hand) do if not chosen[i] then
        c.ability=c.ability or {}; c.ability.forced_selection=nil; held[#held+1]=c
    end end
    next_state.hand=held
    for _,c in ipairs(effects.created_cards) do
        next_state.hand[#next_state.hand+1]=c;next_state.playing_cards[#next_state.playing_cards+1]=c
    end
    local deck={}
    for _,c in ipairs(next_state.deck or {}) do
        local updated=changed[c.id] or changed[c] or c
        if not destroyed_ids[c.id] and not updated.shattered then
            if updated.ability then updated.ability.forced_selection=nil end
            deck[#deck+1]=updated
        end
    end
    next_state.deck=deck
    local remaining_jokers={}
    for i,j in ipairs(next_state.jokers or {}) do
        j.ability=transition.states[i]
        local n,a=name(j),j.ability
        local remove=false
        if not j.debuff then
            -- Original remove_playing_cards callbacks happen after this hand's
            -- score and before perma-debuff. Blueprint/Brainstorm do not grow
            -- the physical source twice (both callbacks guard blueprint).
            if n=='Glass Joker' then a.x_mult=num(a.x_mult,1)+#destroyed_cards*num(a.extra,0.75)
            elseif n=='Caino' then a.caino_xmult=num(a.caino_xmult,1)+destroyed_faces*num(a.extra,1) end
            if n=='Ice Cream' then
                a.extra=a.extra or {}; a.extra.chips=num(a.extra.chips,100)-num(a.extra.chip_mod,5)
                remove=a.extra.chips<=0
            elseif n=='Seltzer' then a.extra=num(a.extra,10)-1; remove=a.extra<=0 end
        end
        if n=='Steel Joker' then a.steel_tally=max(0,num(a.steel_tally)+delta_steel)
        elseif n=='Stone Joker' then a.stone_tally=max(0,num(a.stone_tally)+delta_stone)
        elseif n=="Driver's License" then a.driver_tally=max(0,num(a.driver_tally)+delta_enhanced) end
        if remove then
            if (j.edition or {}).negative then next_state.joker_limit=num(next_state.joker_limit,5)-1 end
            next_state.hand_size=num(next_state.hand_size,8)-num(a.h_size)
        else remaining_jokers[#remaining_jokers+1]=j end
    end
    next_state.jokers=remaining_jokers
    for _,j in ipairs(remaining_jokers) do if name(j)=='Swashbuckler' then
        local total=0; for _,other in ipairs(remaining_jokers) do if other~=j then total=total+num(other.sell_cost) end end
        j.ability.mult=total
    end end
    if effects.created_count>0 then refresh_population_tallies(next_state) end
    if bn=='Crimson Heart' then next_state.blind.crimson_pending=true end
    if not blind.disabled and (blind.key=='bl_fish' or blind.name=='The Fish') then next_state.blind.prepped=true end
    return next_state,effects,result
end

return M
