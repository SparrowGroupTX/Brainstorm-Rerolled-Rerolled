-- Loaded in memory by engine_probe.py. All engine modules below are original
-- unmodified source read from the user's installed executable.
io.stdout:setvbuf('no')
local storage={}
local storage_calls=0
local function unsupported(area)
    return setmetatable({}, {__index=function(_,key) error('HEADLESS_BOUNDARY '..area..'.'..key) end})
end
love={
    system={getOS=function() return 'Windows' end},
    filesystem={
        getInfo=function(path) return storage[path] and {type='file'} or nil end,
        createDirectory=function(path) storage_calls=storage_calls+1; storage[path]=''; return true end,
        append=function(path,value) storage_calls=storage_calls+1; storage[path]=(storage[path] or '')..value; return true end,
        read=function(path) return storage[path] end,
        write=function(path,value) storage_calls=storage_calls+1; storage[path]=value; return true end,
    },
    graphics=unsupported('graphics'), window=unsupported('window'),
    thread=unsupported('thread'), audio=unsupported('audio'),
    timer={getTime=function() return 0 end},
}
-- This process has no filesystem/network/native-extension escapes after modules
-- have been inserted in package.preload by the host.
io.open=function() error('HEADLESS_BOUNDARY io.open') end
io.popen=function() error('HEADLESS_BOUNDARY io.popen') end
os.execute=function() error('HEADLESS_BOUNDARY os.execute') end
os.remove=function() error('HEADLESS_BOUNDARY os.remove') end
os.rename=function() error('HEADLESS_BOUNDARY os.rename') end
package.loadlib=function() error('HEADLESS_BOUNDARY native module load') end
loadfile=function() error('HEADLESS_BOUNDARY loadfile') end
dofile=function() error('HEADLESS_BOUNDARY dofile') end
package.loaders={package.loaders[1]}
_RELEASE_MODE=true; _DEMO=false
require('engine/object')
require('bit')
require('engine/string_packer')
require('engine/event')
require('engine/controller')
require('engine/node')
require('engine/moveable')
require('engine/sprite')
require('engine/animatedsprite')
require('engine/particles')
require('functions/misc_functions')
require('game')
require('globals')
require('functions/common_events')
require('functions/state_events')
require('functions/button_callbacks')
require('back')
require('tag')
require('card')
require('cardarea')
require('blind')
require('challenges')

-- Save/meta boundaries are intentionally synthetic, in memory only. A real
-- benchmark must declare its unlock profile; no user profile is consulted.
convert_save_to_meta=function() end
get_compressed=function(path) return storage[path] end
G.SETTINGS.profile=1
G.SETTINGS.tutorial_complete=true
G.F_NO_SAVING=true
G.F_NO_ACHIEVEMENTS=true
G.F_SOUND_THREAD=false
G.F_MUTE=true
G.localization=require('localization/en-us')
init_localization()
G:init_item_prototypes()
assert(PROBE_PROFILE_SPEC and PROBE_PROFILE_SPEC.schema==1,'HEADLESS_BOUNDARY undeclared source profile')
assert(PROBE_PROFILE_SPEC.name=='source_defaults_v1' or
    PROBE_PROFILE_SPEC.name=='all_unlocked_discovered_v1','HEADLESS_BOUNDARY unknown source profile')
if PROBE_PROFILE_SPEC.name=='all_unlocked_discovered_v1' then
    for _,scope in ipairs(PROBE_PROFILE_SPEC.scope) do
        for _,center in pairs(assert(G[scope],'HEADLESS_BOUNDARY profile scope unavailable')) do
            center.unlocked=true;center.discovered=true
        end
    end
end
print('PROBE original item prototypes loaded',#G.P_CENTER_POOLS.Joker,#G.CHALLENGES)
G.GAME=G:init_game_object()
G.GAME.pseudorandom.seed='ADVISOR1'
G.GAME.pseudorandom.hashed_seed=pseudohash('ADVISOR1')
G.jokers={cards={}}
G.playing_cards={}
G.GAME.round_resets.ante=1
local pool,key=get_current_pool('Joker',nil,nil,'sho')
local selected=pseudorandom_element(pool,pseudoseed(key))
print('PROBE original shop pool sampled',key,selected,#pool)
print('PROBE original boss sampled',get_new_boss())
print('PROBE original voucher sampled',get_next_voucher_key())
print('PROBE original tag sampled',get_next_tag_key())
local rng_state=copy_table(G.GAME.pseudorandom)
local rng_a=pseudorandom('probe')
G.GAME.pseudorandom=copy_table(rng_state)
local rng_b=pseudorandom('probe')
assert(rng_a==rng_b,'native game RNG state restoration is not deterministic')
print('PROBE native LuaJIT/game RNG deterministic',rng_a)
print('PROBE no physical save access; in-memory storage calls',storage_calls)
print('PROBE full-run adapter qualification',false)

-- Explicitly scoped display metadata only, preserving original Node/Sprite/
-- Card constructors and their RNG calls. All actual rendering stays forbidden.
love.graphics.getWidth=function() return 1280 end
love.graphics.getHeight=function() return 720 end
love.graphics.setDefaultFilter=function() end
love.graphics.setLineStyle=function() end
love.graphics.newImage=function(path,options)
    local dims=assert(PROBE_PNG[path],'Missing original PNG dimensions: '..path)
    local scale=(options or {}).dpiscale or 1
    return {getDimensions=function() return dims[1]/scale,dims[2]/scale end}
end
love.graphics.newQuad=function(x,y,w,h,iw,ih)
    return {x=x,y=y,w=w,h=h,iw=iw,ih=ih,
        setViewport=function(self,a,b,c,d) self.x=a;self.y=b;self.w=c;self.h=d end}
end
love.resize=function() end
G.CONTROLLER=Controller()
-- Original overlay_menu saves/restores the cursor context after win accounting.
-- A display-only Moveable supplies its position/state; no window/cursor API runs.
G.CURSOR=Moveable(0,0,0.3,0.3)
G.E_MANAGER=EventManager()
G.real_dt=1/60
G:load_profile(1)
local unlock_profile={}
for _,scope in ipairs(PROBE_PROFILE_SPEC.scope) do
    for key,center in pairs(assert(G[scope],'HEADLESS_BOUNDARY profile scope unavailable')) do
        unlock_profile[#unlock_profile+1]=scope..':'..key..':'..tostring(center.unlocked)..':'..tostring(center.discovered)
    end
end
table.sort(unlock_profile)
PROBE_UNLOCK_PROFILE_TEXT=table.concat(unlock_profile,'\n')
assert(PROBE_RECORD_PROFILE(PROBE_UNLOCK_PROFILE_TEXT)==1,'HEADLESS_BOUNDARY source profile verification failed')
if PROBE_PROFILE_ONLY then return end
Game.save_settings=function() storage_calls=storage_calls+1 end
G:set_render_settings()

-- Explicit HUD elements used by start_run/new_round. They contain only display
-- state; gameplay values remain on the untouched original G.GAME/Card objects.
local hud_ids={row_blind=true,hand_chips=true,hand_mult=true,ante_UI_count=true,
    round_UI_count=true,hand_chip_total=true,hand_name=true,hand_level=true,
    chip_UI_count=true,HUD_blind_count=true,blind_spacer=true,HUD_blind_name=true,
    dollars_to_be_earned=true,HUD_blind_debuff_1=true,HUD_blind_debuff_2=true,
    dollar_text_UI=true,hand_UI_count=true,discard_UI_count=true,
    prompt_dynatext1=true,prompt_dynatext2=true}
local function hud_node()
    local node=Moveable(0,0,1,1)
    node.config.object={update=function() end,pop_in=function() end,pop_out=function() end,
        pulse=function() end,update_text=function() end}
    node.config.ref_table={}
    node.alignment={offset={x=0,y=0}}
    node.recalculate=function() end
    node.get_UIE_by_ID=function(self,id)
        assert(hud_ids[id],'HEADLESS_BOUNDARY unknown HUD ID '..tostring(id))
        self.probe_nodes=self.probe_nodes or {}
        if not self.probe_nodes[id] then
            local child=hud_node();child.parent=self;self.probe_nodes[id]=child
        end
        return self.probe_nodes[id]
    end
    node.parent={parent={states={visible=true}},states={visible=true}}
    return node
end
create_UIBox_HUD=function() return 'probe_hud' end
create_UIBox_HUD_blind=function() return 'probe_hud_blind' end
-- Original attention_text only constructs/removes a transient text/particle
-- overlay; its callers perform all rule mutations before invoking it.
attention_text=function(args)
    assert(not args.func and not args.callback,'Unexpected attention callback')
end
UIBox=function(args)
    assert(args.definition=='probe_hud' or args.definition=='probe_hud_blind',
        'HEADLESS_BOUNDARY unimplemented UI definition')
    return hud_node()
end

local function pump(frames,draw_to_hand)
    for i=1,frames do
        G.TIMERS.REAL=G.TIMERS.REAL+1/60
        G.TIMERS.TOTAL=G.TIMERS.TOTAL+1/60
        G.TIMERS.UPTIME=G.TIMERS.UPTIME+1/60
        G.real_dt=1/60
        G.E_MANAGER:update(1/60)
        if draw_to_hand and G.STATE==G.STATES.DRAW_TO_HAND then G:update_draw_to_hand(1/60) end
        for _,area in ipairs(G.I.CARDAREA) do area:update(1/60);area:align_cards() end
        if draw_to_hand and G.STATE==G.STATES.SELECTING_HAND then return end
    end
end

-- Deliberately exercise untouched start_run to identify the first missing
-- adapter surface. A caller must not mislabel this as a completed episode.
local ok,reason=xpcall(function()
    if PROBE_DECK then
        G.GAME.selected_back=Back(assert(G.P_CENTERS[PROBE_DECK],'Unknown ordinary deck'))
        G:start_run({seed=PROBE_SEED,stake=PROBE_STAKE})
        assert(G.GAME.challenge==nil and G.GAME.stake==PROBE_STAKE,'Normal stake initialization mismatch')
        assert(G.GAME.selected_back.effect.center.key==PROBE_DECK,'Normal deck initialization mismatch')
    else
        local challenge=G.CHALLENGES[tonumber(PROBE_CHALLENGE)]
        for _,candidate in ipairs(G.CHALLENGES) do if candidate.id==PROBE_CHALLENGE then challenge=candidate end end
        assert(challenge,'Unknown challenge: '..tostring(PROBE_CHALLENGE))
        G:start_run({seed=PROBE_SEED,challenge=challenge})
    end
    pump(600)
    print('PROBE authentic challenge initialization',G.GAME.challenge,#G.deck.cards,#G.jokers.cards)
    -- Full episodes must let the same policy choose the very first blind too.
    -- The opening-only probe below deliberately exercises a fixed Small Blind.
    if PROBE_EPISODE then return end
    G.blind_select=hud_node()
    G.blind_prompt_box=hud_node()
    G.GAME.blind_on_deck='Small'
    G.FUNCS.select_blind({config={ref_table=G.P_BLINDS.bl_small}})
    pump(1200,true)
    assert(G.STATE==G.STATES.SELECTING_HAND,'Opening hand did not settle')
    local cards={}; for _,card in ipairs(G.hand.cards) do cards[#cards+1]=card.config.card_key end
    print('PROBE authentic opening blind',G.GAME.blind.name,G.GAME.blind.chips,
        G.GAME.current_round.hands_left,G.GAME.current_round.discards_left,table.concat(cards,','))
end,debug.traceback)
print('PROBE authentic start_run completed',ok)
if not ok then print('PROBE authentic start_run boundary',reason) end
print('PROBE challenge created before boundary',G.GAME.challenge,
    G.deck and #G.deck.cards or 0,G.GAME.modifiers.no_interest or false)
if PROBE_EPISODE then
    assert(ok,'Challenge initialization failed; episode not started')
    local episode_ok,episode_error=xpcall(assert(loadstring(PROBE_EPISODE,'@engine_run.lua')),debug.traceback)
    if not episode_ok then
        if PROBE_EXPORT_FAILURE_CONTEXT then
            local exported,text=pcall(PROBE_EXPORT_FAILURE_CONTEXT)
            if exported then print(text);PROBE_FAILURE_CONTEXT_EMITTED=true end
        end
        error(episode_error)
    end
elseif not ok then
    error(reason)
end
