"""Manufactured input/inert module doubles only; never loads captured policies."""
from pathlib import Path
import ctypes
import json
import unittest
import compare_pack21 as worker
from lua_bytes import literal
from module_graph import module_setup

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def manufactured_result(index=1):
    return {'status': 'complete', 'input_unchanged': True, 'input_fingerprint': 'synthetic',
            'action': {'kind': 'choose', 'index': index}, 'score_calls': 10,
            'result': {'action': {'kind': 'choose', 'index': index}, 'evaluations': 10}}


class SpecTests(unittest.TestCase):
    def test_distinct_actions_are_reported_without_rejection(self):
        pair = worker.compare_pair(manufactured_result(), manufactured_result(2))
        self.assertFalse(pair['actions_equal'])
        self.assertFalse(pair['results_equal'])
        changed = manufactured_result(); changed['input_unchanged'] = False
        with self.assertRaises(ValueError):
            worker.compare_pair(manufactured_result(), changed)

    def test_fixed_caps_no_draft_execution(self):
        self.assertEqual(worker.ORDER, (('baseline', 12), ('candidate', 12)))
        self.assertEqual((worker.CAP, worker.TOTAL_CAP), (50000, 100000))
        with self.assertRaises(FileNotFoundError):
            worker.verify(HERE)

    def test_real_runtime_graph_derivation_has_all_new_edges(self):
        raw = (ROOT / 'tools/advisor_eval/runs/perkeo312_installed/policy/Brainstorm/Advisor/runtime.lua').read_bytes()
        setup, omitted = module_setup(raw)
        self.assertEqual(len(omitted), 5)
        self.assertIn(b'A.strategy.pack_survival = A.pack_survival', setup)
        self.assertIn(b'A.snapshot.perkeo_inventory = A.perkeo_inventory', setup)
        self.assertNotIn(b'function A.defaults', setup)
        self.assertNotIn(b"local nfs = require('nativefs')", setup)
        with self.assertRaises(ValueError):
            module_setup(raw.replace(b'\nfunction A.defaults()', b'\nfunction A.unknown()'))

    def test_inert_driver_full_graph_cap_error_and_mutation(self):
        # Same ordinary isolated Lua serializer/driver fixture mechanism as M20.
        lib = ctypes.CDLL('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
        lib.luaL_newstate.restype = ctypes.c_void_p
        lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        lib.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        lib.lua_tolstring.restype = ctypes.c_void_p
        lib.lua_close.argtypes = [ctypes.c_void_p]
        raw = (ROOT / 'tools/advisor_eval/runs/perkeo312_installed/policy/Brainstorm/Advisor/runtime.lua').read_bytes()
        setup, _ = module_setup(raw)
        driver = (HERE / 'driver.lua').read_bytes()
        for mode in ('normal', 'cap', 'mutate', 'throw', 'wire'):
            stub = b'''
local checks,raw_calls,decisions,clocks=0,0,0,0
local loaded={}
local env={PROFILE_INPUT={phase='pack',dollars=20,completionist_goal={counts={missing=150,complete=0,total=150,unknown=0}}},package={preload=setmetatable({},{__index=function()return function()end end})}}
env.PROBE_MONOTONIC_SECONDS=function()clocks=clocks+1;return clocks*0.125 end
local verifier=assert(loadstring(VERIFIER))()
env.require=function(name)
 if name=='probe_policy_wiring' then return verifier end
 if name=='probe_engine_contract' then return {trace_number=function(v)return tostring(v)end} end
 assert(name:match('^probe_policy_'),'Only inert policy doubles allowed')
 loaded[name]=loaded[name] or {};local m=loaded[name]
 if name=='probe_policy_snapshot' then m.fingerprint=function(s)return s.phase..':'..s.dollars end
 elseif name=='probe_policy_gold_goal' then m.suggest=function()error('Unexpected inert Gold suggestion')end
 elseif name=='probe_policy_scoring' then m.score=function()raw_calls=raw_calls+1;return {score=10}end
 elseif name=='probe_policy_decision' then m.run=function(s,a,options)
  decisions=decisions+1;assert(options==nil and a.execution==nil and a.retry_memory==nil)
  for _=1,(MODE=='cap' and 50001 or 10)do a.scoring.score(s,{1})end
  if MODE=='throw' then error('synthetic policy failure')end
  if MODE=='mutate' then s.dollars=21 end
  return {action={kind='choose',area='pack_cards',index=1},evaluations=10}
 end end
 return m
end
setmetatable(env,{__index=_G})
local chunk=assert(loadstring(SETUP..(MODE=='wire' and '\\nA.strategy.pack_survival=nil\\n' or '\\n')..DRIVER))
setfenv(chunk,env)
local okay,result=pcall(chunk)
if MODE=='wire' then assert(not okay and decisions==0);return 'wire_rejected' end
assert(okay,result);assert(decisions==1 and clocks==2)
assert(raw_calls==(MODE=='cap' and 50000 or 10))
return result
'''
            source = b'MODE=' + literal(mode) + b';SETUP=' + literal(setup) + b';DRIVER=' + literal(driver) + b';VERIFIER=' + literal((HERE / 'policy_wiring.lua').read_bytes()) + b'\n' + stub
            state = lib.luaL_newstate()
            self.assertTrue(state)
            try:
                lib.luaL_openlibs(state)
                status = lib.luaL_loadbuffer(state, source, len(source), b'@M21_inert_fixture')
                if not status:
                    status = lib.lua_pcall(state, 0, 1, 0)
                length = ctypes.c_size_t()
                pointer = lib.lua_tolstring(state, -1, ctypes.byref(length))
                value = ctypes.string_at(pointer, length.value).decode() if pointer else ''
                self.assertEqual(status, 0, value)
                if mode == 'wire':
                    self.assertEqual(value, 'wire_rejected')
                    continue
                result = json.loads(value)
                self.assertEqual(result['score_calls'], 50000 if mode == 'cap' else 10)
                self.assertEqual(result['status'], 'error' if mode in ('cap', 'throw') else 'complete')
                self.assertEqual(result['input_unchanged'], mode != 'mutate')
                self.assertFalse(result['source_execution'])
                self.assertFalse(result['action_dispatch'])
                self.assertFalse(result['selected_action_rescore'])
                if mode == 'cap':
                    self.assertIn('CAPTURED_SCORE_CAP:50000', result['error'])
            finally:
                lib.lua_close(state)


if __name__ == '__main__':
    unittest.main()
