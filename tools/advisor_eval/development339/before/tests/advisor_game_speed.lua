-- Manufactured settings/menu doubles only. No original source or player files.
local Speed = dofile('Brainstorm/UI/game_speed.lua')
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function setup(speed)
  local e = {calls=0, saves=0}
  e.G = {SETTINGS={GAMESPEED=speed, paused=true, other=42}, FUNCS={}}
  e.G.save_settings = function(self) check(self==e.G,'native save receives game'); e.saves=e.saves+1 end
  e.create_option_cycle = function(args, extra)
    e.calls=e.calls+1; e.args=args; e.extra=extra; return args,'second result'
  end
  check(Speed.attach(e),'hook installs')
  return e
end
local function args(options)
  return {opt_callback='change_gamespeed',options=options or {.5,1,2,4},current_option=99,
    label='localized Game speed',w=4,scale=.8,colour={},focus_args={snap_to=true}}
end
local function choose(e,index,value)
  return e.G.FUNCS.brainstorm_change_gamespeed({to_val=value,cycle_config={current_option=index}})
end
for index, speed in ipairs({.5,1,2,4,8,16}) do
  local e=setup(speed); local a=args(); local built,second=e.create_option_cycle(a,'forwarded')
  check(second=='second result' and e.extra=='forwarded','all original returns/arguments preserved')
  check(built~=a and built.options~=a.options,'never mutate original tables')
  check(#a.options==4 and a.current_option==99 and a.opt_callback=='change_gamespeed','caller config unchanged')
  check(#built.options==6 and built.current_option==index,'reopened setting has correct selected index')
  check(built.w==a.w and built.scale==a.scale and built.label==a.label and built.colour==a.colour
    and built.focus_args==a.focus_args,'native layout and focus preserved')
  check(e.G.SETTINGS.GAMESPEED==speed and e.saves==0,'opening menu never changes settings')
  for j,value in ipairs({.5,1,2,4,8,16}) do
    check(built.options[j]==value,'all offered speeds in order')
    check(choose(e,j,value),'valid selection accepted')
    check(e.G.SETTINGS.GAMESPEED==value and e.saves==j,'selection saved exactly once')
    check(e.G.SETTINGS.paused==true and e.G.SETTINGS.other==42,'unrelated settings preserved')
  end
  for _,bad in ipairs({{}, {cycle_config={}}, {cycle_config={current_option=7},to_val=32},
    {cycle_config={current_option=5},to_val=16}, {cycle_config={current_option=5.5},to_val=8},
    {cycle_config={current_option='5'},to_val=8}, {cycle_config={current_option=0/0},to_val=8}}) do
    check(not e.G.FUNCS.brainstorm_change_gamespeed(bad),'malformed/stale selection rejected')
    check(e.saves==6 and e.G.SETTINGS.GAMESPEED==16,'rejected selection does not save/change speed')
  end
  check(not e.G.FUNCS.brainstorm_change_gamespeed(nil),'nil selection rejected')
end
do
  local e=setup(3); local a=args({.5,1,2,3,4,8,16,32}); e.create_option_cycle(a)
  check(#e.args.options==8 and e.args.current_option==4,'additional mod speeds retained without duplicate8/16')
  check(choose(e,8,32) and e.G.SETTINGS.GAMESPEED==32,'existing extra speed still selectable')
  local cb=e.G.FUNCS.brainstorm_change_gamespeed;e.G={}
  check(not cb({to_val=8,cycle_config={current_option=6}}),'old game callback cannot change a replacement game')
end
do
  local e=setup(8);local a=args({'0.5','1','2','4'});e.create_option_cycle(a)
  check(e.args.current_option==5 and e.args.options[5]=='8' and e.args.options[6]=='16','numeric string speed labels extended')
  check(choose(e,6,'16') and e.G.SETTINGS.GAMESPEED==16,'string selection persists numeric speed')
  check(not choose(e,5,8) and e.saves==1,'selection must match actual offered label')
  check(e.args.options[1]=='0.5' and a.options[5]==nil,'original string labels preserved')
end
for _,options in ipairs({{}, {1,4,2}, {'slow','fast'}, {1,math.huge}, {1,0/0}, {0,1}, {-1,1},
  {[1]=1,[3]=4}, {[1]=1, extra=4}, {[1]=1,[1.5]=4}}) do
  local e=setup(1); local a=args(options); check(e.create_option_cycle(a)==a,'unfamiliar options delegated intact')
  check(not e.G.FUNCS.brainstorm_change_gamespeed and e.saves==0,'no custom callback/settings on refusal')
end
do
  local e=setup(4);local a=args();a.opt_callback='other_setting'
  check(e.create_option_cycle(a)==a,'other setting unaffected')
  local missing=args();e.G.save_settings=nil;check(e.create_option_cycle(missing)==missing,'missing persistence delegated')
  e=setup(7);a=args();check(e.create_option_cycle(a)==a,'unknown saved speed preserved')
  e=setup(4);a=args();for i=1,65 do a.options[i]=i end
  check(e.create_option_cycle(a)==a,'bounded option inspection')
  check(not Speed.attach({}),'unavailable constructor is harmless')
end
print('advisor_game_speed: '..checks..' checks passed')
