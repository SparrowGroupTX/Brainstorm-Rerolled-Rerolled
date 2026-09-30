"""One-use native product integration; no search, game or profile access."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'Brainstorm/Core/Brainstorm.lua'
s=p.read_text(encoding='utf-8')
def replace(old,new):
    global s
    assert s.count(old)==1,old[:90]
    s=s.replace(old,new)
replace('Brainstorm.NATIVE_FILE = "Immolate-advisor-a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885.dll"',
        'Brainstorm.NATIVE_FILE = "Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll"')
replace('      const char* brainstorm_estimate_v1(', '''      const char* brainstorm_v9(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int stakeLevel, bool noPerishableJokers, bool interchangeableCopies, const char* missingNames, int minimumDistinct, int firstAnte, int lastAnte, int budgetMs);
      void brainstorm_cancel_v9();
      const char* brainstorm_estimate_v1(''')
replace('function Brainstorm.requestSearchEstimate()\n', 'function Brainstorm.requestSearchEstimate()\n  if Brainstorm.native_search_busy then return false end\n')
replace('      if generation ~= Brainstorm.search_estimate_generation then', '      if Brainstorm.native_search_busy or generation ~= Brainstorm.search_estimate_generation then')
replace('function Brainstorm.autoReroll()\n', 'function Brainstorm.autoReroll()\n  if Brainstorm.native_search_busy then return nil end\n')
replace('  Brainstorm.Advisor = assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/runtime.lua")))()','''  local start_opening=Brainstorm.startChallengeOpeningSearch
  Brainstorm.startChallengeOpeningSearch=function(...)
    if Brainstorm.native_search_busy then return false,'A bounded search is already running.' end
    return start_opening(...)
  end
  Brainstorm.Advisor = assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/runtime.lua")))()
  Brainstorm.CollectionSearch=assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/collection_search.lua")))()
  local collection_runtime=assert(load(nfs.read(Brainstorm.PATH .. "/Core/collection_search_runtime.lua")))()
  collection_runtime.attach(Brainstorm,{native=function()return ensureImmolateLoaded()end,
    now=function()return love.timer.getTime()end})
  local collection_product=assert(load(nfs.read(Brainstorm.PATH .. "/Core/collection_search_product.lua")))()
  collection_product.attach(Brainstorm)
'''.rstrip())
replace('  assert(load(nfs.read(Brainstorm.PATH .. "/UI/ui.lua")))()', '  assert(load(nfs.read(Brainstorm.PATH .. "/UI/collection_run.lua")))()\n  assert(load(nfs.read(Brainstorm.PATH .. "/UI/ui.lua")))()')
replace('function Controller:key_press_update(key, dt)\n', '''function Controller:key_press_update(key, dt)
    if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Keyboard input.') end
    if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.stop('Keyboard input.') end
''')
replace('            if Brainstorm.ar_active then\n', '''            if Brainstorm.native_search_busy then
                Brainstorm.CollectionSearchProduct.stop('Search hotkey pressed.')
            elseif Brainstorm.ar_active then
''')
replace('local update_ref = Game.update', '''-- Actual player input interrupts an explicitly armed run before its callback.
for _,method in ipairs({'queue_L_cursor_press','queue_R_cursor_press'}) do
  local original=Controller[method]
  if type(original)=='function' then
    Controller[method]=function(self,...)
      if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Mouse input.') end
      if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.stop('Mouse input.') end
      return original(self,...)
    end
  end
end

local update_ref = Game.update''')
replace('  if Brainstorm.Checkpoints then Brainstorm.Checkpoints:update(dt) end', '''  if Brainstorm.Checkpoints then Brainstorm.Checkpoints:update(dt) end
  if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.update() end''')
replace('    Brainstorm.Advisor.update(dt)\n  end', '    Brainstorm.Advisor.update(dt)\n  end\n  if Brainstorm.AutoRun then Brainstorm.AutoRun:update(dt) end')
p.write_text(s,encoding='utf-8',newline='\n')
p=ROOT/'Brainstorm/Advisor/runtime.lua';s=p.read_text(encoding='utf-8')
replace('if not A.active() or Brainstorm.ar_active or G.screenwipe then', 'if not A.active() or Brainstorm.ar_active or Brainstorm.native_search_busy or G.screenwipe then')
p.write_text(s,encoding='utf-8',newline='\n')
p=ROOT/'Brainstorm/UI/ui.lua';s=p.read_text(encoding='utf-8')
replace('  "Gold search",\n}', '  "Gold search",\n  "Quick Gold run",\n}')
replace('  Brainstorm.createGoldSearchPage,\n}', '  Brainstorm.createGoldSearchPage,\n  Brainstorm.createCollectionRunPage,\n}')
replace('local function create_brainstorm_tab()', '''function Brainstorm.showCollectionRunPage()
  for index,label in ipairs(brainstorm_page_labels) do
    if label=='Quick Gold run' then
      G.FUNCS.change_brainstorm_page({cycle_config={current_option=index}})
      return
    end
  end
end

local function create_brainstorm_tab()''')
p.write_text(s,encoding='utf-8',newline='\n')
print('Native product integration written; drafts must be staged and tested before use.')
