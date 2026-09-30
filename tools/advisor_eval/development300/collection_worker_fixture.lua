local checks=0
local function check(v,s)checks=checks+1;assert(v,s)end
local saved_love,saved_ffi=love,package.loaded.ffi
local function scenario(mode)
  local replies,stops={},{}
  local calls,frees,loads,thread_mode=0,0,0,nil
  if mode=='pre_cancel' then stops[1]=true end
  love={thread={getChannel=function(name)
    if name=='reply' then return {push=function(_,v)replies[#replies+1]=v end} end
    return {pop=function()return table.remove(stops,1)end}
  end}}
  local args={'native.dll','reply','cancel',17,'11111111','','','Charm Tag',2,false,0,false,false,false,false,false,
    'No Filter','','',0,0,'Yorick\31Brainstorm\31Burnt Joker\31Perkeo','Red Deck',
    'soul_pack\31by_ante_5\31by_ante_5\31soul_pack',8,true,true,'Joker',1,1,8,30000}
  package.loaded.ffi={cdef=function()end,load=function(path)
    loads=loads+1;check(path=='native.dll','exact selected native artifact loaded')
    if mode=='load_error' then error('load failed')end
    return {brainstorm_set_search_thread_mode=function(value)thread_mode=value end,
      brainstorm_v9=function(...)
        calls=calls+1;local received={...};check(#received==28,'all primitive ABI fields forwarded')
        for i=1,28 do check(received[i]==args[i+4],'argument '..i..' retains exact type/value')end
        if mode=='null' then return nil end
        return 'pointer'
      end,
      free_result=function(ptr)check(ptr=='pointer','the allocated pointer is freed');frees=frees+1 end}
  end,string=function(ptr)
    check(ptr=='pointer','conversion reads allocated pointer')
    if mode=='convert_error' then error('conversion failed')end
    if mode=='post_cancel' then stops[1]=true end
    return '{"status":"timeout"}'
  end}
  assert(loadfile('tools/advisor_eval/development300/collection_search_worker.lua'))(unpack(args))
  check(#replies==1,'worker returns exactly one reply')
  check(replies[1].generation==17,'reply binds generation')
  if mode=='pre_cancel' then
    check(loads==0 and calls==0 and replies[1].status=='cancelled','pre-start stop skips native loading/search')
  elseif mode=='load_error' then
    check(calls==0 and replies[1].status=='error','loader failure stops without search')
  elseif mode=='null' then
    check(frees==0 and replies[1].status=='error','null allocation reports error')
  else
    check(calls==1 and frees==1 and thread_mode==1,'one maximum-CPU call and exactly one free')
    check(replies[1].status==(mode=='convert_error' and 'error' or mode=='post_cancel' and 'cancelled' or 'complete'),'specific outcome returned')
    if mode=='post_cancel' then check(replies[1].raw_result=='{"status":"timeout"}','canceled native outcome retained for logs')end
  end
end
for _,mode in ipairs({'success','pre_cancel','post_cancel','convert_error','null','load_error'})do scenario(mode)end
love,package.loaded.ffi=saved_love,saved_ffi
print('collection_worker fixture: '..checks..' checks passed')
