-- LOVE worker entry point. The controller must keep search/estimate globals
-- exclusive until this thread exits, including after cancellation.
-- start(nativePath, replyChannel, cancelChannel, generation, <28 v9 fields>)
local argv={...}
local reply=love.thread.getChannel(argv[2])
local cancel=love.thread.getChannel(argv[3])
local generation=argv[4]
local function send(status,raw,message)
  reply:push({generation=generation,status=status,raw_result=raw,error=message})
end
if cancel:pop() then send('cancelled');return end
local ok,err=pcall(function()
  assert(type(argv[1])=='string' and #argv==32,'Invalid native search request')
  local ffi=require('ffi')
  ffi.cdef([[
    const char* brainstorm_v9(const char* seed, const char* voucher, const char* pack,
      const char* tag, int souls, bool observatory, int observatoryDeadline,
      bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar,
      const char* customFilter, const char* targetRank, const char* targetSuit,
      int specificRankMin, int anyRankMin, const char* targetJokers,
      const char* deck, const char* targetJokerLocations, int stakeLevel,
      bool rejectPerishableTargets, bool interchangeableCopies,
      const char* missingNames, int minimumDistinct, int firstAnte, int lastAnte,
      int budgetMs);
    void brainstorm_set_search_thread_mode(int mode);
    void free_result(const char* result);
  ]])
  local lib=ffi.load(argv[1])
  lib.brainstorm_set_search_thread_mode(1)
  if cancel:pop() then send('cancelled');return end
  local ptr=lib.brainstorm_v9(unpack(argv,5,32))
  assert(ptr~=nil,'Native search returned no result')
  local converted,raw=pcall(ffi.string,ptr)
  lib.free_result(ptr)
  assert(converted,raw)
  -- The result remains logged for diagnosis but is never applied after stop.
  send(cancel:pop() and 'cancelled' or 'complete',raw)
end)
if not ok then send('error',nil,tostring(err)) end
