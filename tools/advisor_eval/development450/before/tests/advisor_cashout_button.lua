-- Synthetic source-shaped UI ownership/readiness; no game, worker or save access.
local Execution=dofile(CASHOUT_EXECUTION_PATH or 'Brainstorm/Advisor/execution.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function box(major)
  local b={config={major=major},states={visible=true},elements={}}
  b.UIRoot={UIBox=b,states={visible=true},config={}}
  function b:get_UIE_by_ID(id)return self.elements[id]end
  return b
end
local function fixture(ready)
  local g={STATES={ROUND_EVAL=4,SHOP=2},STATE=4,STATE_COMPLETE=true,SETTINGS={},
    CONTROLLER={locks={}},GAME={STOP_USE=0,current_round={}},FUNCS={},play={cards={}},I={UIBOX={}}}
  g.round_eval=box();local detached=box(g.round_eval)
  local e={config={id='cash_out_button',button=ready and 'cash_out' or nil},states={visible=true},
    UIBox=detached,parent=detached.UIRoot}
  detached.elements.cash_out_button=e;g.I.UIBOX[1]=detached
  local calls=0
  g.FUNCS.cash_out=function(received)check(received==e,'dispatch receives actual detached source element');calls=calls+1 end
  g.FUNCS.can_cash_out=function()error('readiness must not invoke a game check callback')end
  return g,detached,e,function()return calls end
end
local function refusal(g,label)
  local okay,ready,why=pcall(Execution.button_ready,g,{kind='cash_out'})
  check(okay and ready==false and type(why)=='string' and #why>0,label..' has readable pure refusal')
  local accepted,reason,started=Execution.execute(g,{kind='cash_out'})
  check(accepted==false and started==false and type(reason)=='string',label..' never begins a callback')
end
do
  local g,b,e,calls=fixture(false)
  local registry=g.I.UIBOX;local root=g.round_eval
  for _=1,5 do refusal(g,'button not enabled yet')end
  check(calls()==0 and e.config.button==nil and g.I.UIBOX==registry and g.round_eval==root,
    'readiness never enables a button, replaces UI or dispatches action')
  e.config.button='cash_out'
  check(Execution.button_ready(g,{kind='cash_out'})==true,'uniquely anchored detached button becomes ready')
  check(calls()==0,'positive readiness is still read-only')
  local okay,why=Execution.execute(g,{kind='cash_out'})
  check(okay==true and calls()==1,why or 'one actual button callback')
end
do
  local g,b,e,calls=fixture(true)
  g.I.UIBOX={};g.round_eval=b;b.config.major=nil
  check(Execution.button_ready(g,{kind='cash_out'})==true,'legacy directly owned round-evaluation button remains supported')
  check(Execution.execute(g,{kind='cash_out'})==true and calls()==1,'legacy direct execution uses original element')
end
for _,case in ipairs({
  {'stale round anchor',function(g,b)g.round_eval=box()end},
  {'foreign same-id root',function(g,b)b.config.major={}end},
  {'foreign returned element owner',function(g,b,e)e.UIBox=box()end},
  {'hidden element',function(g,b,e)e.states.visible=false end},
  {'hidden ancestor',function(g,b,e)e.parent.states.visible=false end},
  {'hidden detached box',function(g,b)b.states.visible=false end},
  {'removed detached box',function(g,b)b.REMOVED=true end},
  {'disabled button',function(g,b,e)e.disable_button=true end},
  {'callback substitution',function(g,b,e)e.config.button='toggle_shop' end},
  {'removed current root',function(g)g.round_eval.REMOVED=true end},
  {'missing callback',function(g)g.FUNCS.cash_out=nil end},
  {'malformed element config',function(g,b,e)e.config=true end},
  {'malformed element states',function(g,b,e)e.states=true end},
  {'malformed box config',function(g,b,e)b.config=true end},
  {'malformed box states',function(g,b,e)b.states=true end},
})do
  local g,b,e,calls=fixture(true);case[2](g,b,e);refusal(g,case[1]);check(calls()==0,case[1]..' preserves callback count')
end
do
  local g,b,e,calls=fixture(true);local duplicate=box(g.round_eval)
  duplicate.elements.cash_out_button={config={button='cash_out'},states={visible=true},UIBox=duplicate,parent=duplicate.UIRoot}
  g.I.UIBOX[2]=duplicate
  refusal(g,'two distinct anchored cash-out buttons');check(calls()==0,'ambiguity never chooses the first registry result')
  duplicate.elements.cash_out_button.config.button=nil
  refusal(g,'ambiguous anchor with second currently disabled button')
end
do
  local g,b,e,calls=fixture(true);local foreign=box({})
  foreign.elements.cash_out_button={config={button='cash_out'},states={visible=true},UIBox=foreign,parent=foreign.UIRoot}
  g.I.UIBOX={foreign,b}
  check(Execution.button_ready(g,{kind='cash_out'})==true and calls()==0,'unrelated detached UI with same ID cannot mask the unique current owner')
end
do
  local g,b,e,calls=fixture(true);g.round_eval.elements.cash_out_button={config={button='cash_out'},states={visible=true},UIBox=g.round_eval}
  refusal(g,'direct and detached distinct buttons');check(calls()==0,'direct fallback does not mask ambiguity')
end
do
  local g,b,e,calls=fixture(true);g.STATE=g.STATES.SHOP;g.shop=box()
  local leave={config={button='toggle_shop'},states={visible=true},UIBox=g.shop,parent=g.shop.UIRoot}
  g.shop.elements.next_round_button=leave
  local leaves=0;g.FUNCS.toggle_shop=function(received)check(received==leave,'leave-shop uses original owned element');leaves=leaves+1 end
  check(Execution.button_ready(g,{kind='leave_shop'})==true,'direct next-round readiness remains supported')
  check(Execution.execute(g,{kind='leave_shop'})==true and leaves==1,'one supported shop departure')
  leave.config.button=nil
  local ready,why=Execution.button_ready(g,{kind='leave_shop'})
  check(ready==false and type(why)=='string','shop departure also waits for its actual enabled button')
  check(calls()==0,'cash-out is never invoked in shop fixture')
end
do
  local g,b,e,calls=fixture(true);local nested=box(g.shop)
  g.STATE=g.STATES.SHOP;g.shop=box();nested.config.major=g.shop
  local leave={config={button='toggle_shop'},states={visible=true},UIBox=nested,parent=nested.UIRoot}
  g.shop.elements.next_round_button=leave
  local leaves=0;g.FUNCS.toggle_shop=function(received)check(received==leave,'nested shop keeps actual subtree element');leaves=leaves+1 end
  check(Execution.button_ready(g,{kind='leave_shop'})==true,'existing lookup accepts a nested shop UIBox')
  check(Execution.execute(g,{kind='leave_shop'})==true and leaves==1,'nested shop departure still dispatches once')
  check(calls()==0,'nested shop never invokes Cash Out')
end
do
  local g,b,e,calls=fixture(true)
  for i=2,512 do g.I.UIBOX[i]=box({})end
  check(Execution.button_ready(g,{kind='cash_out'})==true,'512 registry entries fit the declared lookup bound')
  g.I.UIBOX[513]=box({})
  refusal(g,'UI registry larger than 512');check(calls()==0,'oversized registry dispatches no callback')
end
do
  local g,b,e,calls=fixture(true);e.parent=e
  refusal(g,'ancestry cycle');check(calls()==0,'cyclic ancestry dispatches no callback')
end
do
  local g,b,e,calls=fixture(true);local ancestor=e
  for _=1,65 do ancestor.parent={states={visible=true}};ancestor=ancestor.parent end
  refusal(g,'ancestry longer than 64');check(calls()==0,'oversized ancestry dispatches no callback')
end
do
  local g,b,e,calls=fixture(true);g.I.UIBOX={b,b,b}
  check(Execution.button_ready(g,{kind='cash_out'})==true,'duplicate registry references to same box and element are deduplicated')
  check(Execution.execute(g,{kind='cash_out'})==true and calls()==1,'duplicate references still dispatch exactly once')
end
do
  local g,b,e,calls=fixture(true);g.round_eval=b;b.config.major=b;g.I.UIBOX={b,b}
  check(Execution.button_ready(g,{kind='cash_out'})==true,'same direct/registered box and element are not falsely ambiguous')
  check(Execution.execute(g,{kind='cash_out'})==true and calls()==1,'direct/registered identity dedup dispatches once')
end
do
  local g,b,e=fixture(true)
  check(Execution.button_ready(g,{kind='play'})==true,'helper does not replace the existing card-action legality path')
  local okay=Execution.execute(g,{kind='play',indices={1}})
  check(okay==false,'a positive nonbutton helper result is not blanket action permission')
  g.FUNCS.cash_out=function()error('Synthetic cash-out callback failed')end
  local accepted,reason,started=Execution.execute(g,{kind='cash_out'})
  check(accepted==false and started==true and reason:find('Synthetic cash-out callback failed',1,true),
    'actual callback failure retains its original reason and may-have-started distinction')
end
print('advisor_cashout_button: '..checks..' synthetic checks passed')
