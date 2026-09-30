"""Inert graph/module doubles and manufactured JSON only. No captured decisions."""
from pathlib import Path
import json
import time
import unittest
import compare_public as worker
from lua_bytes import literal, lua_value
from module_graph import module_setup

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LIBRARY = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')

class HarnessTests(unittest.TestCase):
    def test_registration_required(self):
        with self.assertRaises((ValueError, FileNotFoundError)):
            worker.verify(HERE)
        self.assertEqual(worker.ROLES, ('baseline', 'candidate'))
        self.assertEqual(worker.CAPS, {'hand': 140000, 'shop': 50000, 'pack': 50000})
        self.assertEqual((worker.MAX_ROLE_BYTES, worker.MAX_TOTAL_BYTES), (16777216, 33554432))

    def test_public_validation_preserves_missing_context(self):
        snapshot = {'phase': 'shop', 'dollars': 20, 'completionist_goal': {'enabled': True}}
        before = worker.canonical(snapshot)
        self.assertEqual(worker.validate_snapshot(snapshot), 50000)
        self.assertEqual(worker.canonical(snapshot), before)
        self.assertNotIn('shop_forecast', snapshot)
        for forbidden in ('retry_context', '_retry', '_retry_context', '_shop_scoring', 'pseudorandom'):
            with self.assertRaises(ValueError):
                worker.validate_snapshot({**snapshot, forbidden: {}})
        with self.assertRaises(ValueError):
            worker.validate_snapshot({'phase': 'round'})

    def test_byte_exact_literals(self):
        source = b'local v=' + literal(b'1\r\n2\r3\00045\\"') + b';return v'
        self.assertEqual(worker.Lua(LIBRARY, time.perf_counter() + 5).evaluate(source), b'1\r\n2\r3\00045\\"')
        with self.assertRaises(ValueError):
            lua_value(float('nan'))

    def test_graph_derives_both_frozen_runtime_prefixes(self):
        for directory in ('log327_installed', 'shop329_installed'):
            raw = (ROOT / 'tools/advisor_eval/runs' / directory / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes()
            setup, omitted = module_setup(raw)
            self.assertEqual(len(omitted), 5)
            self.assertIn(b'A.strategy.pack_survival = A.pack_survival', setup)
            self.assertIn(b'A.shop_scoring.blind_finishing=A.blind_finishing', setup)
            self.assertNotIn(b"local nfs = require('nativefs')", setup)
            self.assertNotIn(b'function A.defaults', setup)
            with self.assertRaises(ValueError):
                module_setup(raw.replace(b'\nfunction A.defaults()', b'\nfunction A.unknown()'))

    def test_inert_driver_full_graph_caps_mutation_and_output(self):
        raw = (ROOT / 'tools/advisor_eval/runs/log327_installed/policy/Brainstorm/Advisor/runtime.lua').read_bytes()
        setup, _ = module_setup(raw)
        driver, verifier = (HERE / 'driver.lua').read_bytes(), (HERE / 'policy_wiring.lua').read_bytes()
        for mode in ('normal', 'cap', 'mutate', 'throw', 'wire', 'large', 'unicode', 'nodes', 'sparse', 'timeout'):
            with self.subTest(mode=mode):
                stub = b'''
local calls,decisions,clock_calls=0,0,0
local loaded={}
local env={PROFILE_INPUT={phase='shop',dollars=20,consumeables={},completionist_goal={enabled=true}},PROFILE_SCORE_CAP=50000,
 package={preload=setmetatable({},{__index=function()return function()end end})}}
env.PROBE_MONOTONIC_SECONDS=function()clock_calls=clock_calls+1;return clock_calls*.125 end
env.PROBE_DEADLINE_EXCEEDED=function()return MODE=='timeout'end
local verifier=assert(loadstring(VERIFIER))()
env.require=function(name)
 if name=='probe_policy_wiring'then return verifier end
 if name=='probe_engine_contract'then return {trace_number=function(v)return tostring(v)end}end
 assert(name:match('^probe_policy_'),'Only inert policy doubles allowed')
 loaded[name]=loaded[name]or {};local m=loaded[name]
 if name=='probe_policy_snapshot'then m.fingerprint=function(s)return s.phase..':'..s.dollars end
 elseif name=='probe_policy_gold_goal'then m.suggest=function()error('Unexpected inert Gold call')end
 elseif name=='probe_policy_hand_copy_preflight'then m.prepare=function()end;m.compare=function()end
 elseif name=='probe_policy_scoring'then m.score=function()calls=calls+1;return {score=10}end
 elseif name=='probe_policy_decision'then m.run=function(s,a,options)
  decisions=decisions+1;assert(options==nil and a.execution==nil and a.retry_memory==nil)
  assert(s.shop_forecast==nil,'Missing public forecast must remain absent')
  for _=1,(MODE=='cap'and 50001 or 10)do a.scoring.score(s,{1})end
  if MODE=='throw'then error('Synthetic failure')end
  if MODE=='mutate'then s.dollars=21 end
  local r={action={kind='buy',area='shop_jokers',index=2},evaluations=10,diagnostics={supported=false,reason='Missing shop_forecast'}}
  if MODE=='large'then r.large=string.rep('x',2048)end
  if MODE=='unicode'then r.large=string.rep(string.char(226,130,172),2048)end
  if MODE=='nodes'then r.many={};for i=1,50 do r.many[i]={};for j=1,40 do r.many[i][j]=i*j end end end
  if MODE=='sparse'then r.sparse={[2]='sparse numeric key'}end
  return r
 end end
 return m
end
setmetatable(env,{__index=_G})
local chunk=assert(loadstring(SETUP..(MODE=='wire'and '\\nA.strategy.pack_survival=nil\\n'or '\\n')..DRIVER))
setfenv(chunk,env)
local okay,result=pcall(chunk)
if MODE=='wire'then assert(not okay and decisions==0);return 'wire_rejected'end
assert(okay,result);assert(decisions==1 and clock_calls==2)
assert(calls==(MODE=='cap'and 50000 or MODE=='timeout'and 0 or 10))
return result
'''
                source = (b'MODE=' + literal(mode) + b';SETUP=' + literal(setup) + b';DRIVER=' + literal(driver) +
                          b';VERIFIER=' + literal(verifier) + b'\n' + stub)
                data = worker.Lua(LIBRARY, time.perf_counter() + 5).evaluate(source)
                if mode == 'wire':
                    self.assertEqual(data, b'wire_rejected')
                    continue
                result = json.loads(data); summary = result['summary']
                self.assertLessEqual(len(data), worker.MAX_ROLE_BYTES)
                self.assertEqual(summary['input_unchanged'], mode != 'mutate')
                self.assertFalse(summary['source_execution'])
                self.assertFalse(summary['action_dispatch'])
                self.assertFalse(summary['selected_action_rescore'])
                self.assertTrue(summary['public_input_gaps']['shop_forecast_absent'])
                self.assertEqual(summary['wiring']['retry_enabled'], False)
                if mode in ('cap', 'throw', 'timeout'):
                    self.assertEqual(summary['status'], 'timeout' if mode == 'timeout' else 'error')
                    self.assertNotIn('full_result', result)
                elif mode == 'sparse':
                    self.assertEqual(summary['full_result_status'], 'unavailable')
                    self.assertIn('non-JSON table keys', summary['full_result_gap'])
                else:
                    self.assertEqual(summary['full_result_status'], 'preserved')
                    self.assertEqual(result['full_result']['action']['index'], 2)
                    self.assertEqual(summary['action']['index'], 2)
                    if mode == 'nodes':
                        self.assertGreater(summary['omissions']['nodes'], 0)
                        self.assertEqual(result['full_result']['many'][49][39], 2000)
                    if mode == 'large':
                        self.assertEqual(result['full_result']['large'], 'x'*2048)
                        self.assertEqual(summary['result_summary']['large']['bytes'], 2048)
                        self.assertGreater(summary['omissions']['string_bytes'], 0)
                    if mode == 'unicode':
                        self.assertEqual(result['full_result']['large'], '\u20ac'*2048)
                        self.assertEqual(summary['result_summary']['large']['prefix'], '\u20ac'*170)

if __name__ == '__main__':
    unittest.main()
