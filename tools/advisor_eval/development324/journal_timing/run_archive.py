"""Existing fake-filesystem/archive decoder tests against the detached journal."""
from pathlib import Path
import importlib.util
import json
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
spec=importlib.util.spec_from_file_location('journal_timing_archive',ROOT/'tests/test_advisor_player_log_archive.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
old=b"J=dofile('Brainstorm/Advisor/player_journal.lua')"
assert module.SETUP.count(old)==1
module.SETUP=module.SETUP.replace(old,b"J=dofile('tools/advisor_eval/development324/journal_timing/player_journal.lua')")

def test_precise_journal_timestamps_and_compact_timing_roundtrip(self):
    self.lua.evaluate('''
      time=314159.125
      w=archive()
      local wrapped={append=function(_,event,raw)
        originals[event.sequence]=raw;return w:append(event,raw)
      end,rotate=function(_,reason)return w:rotate(reason)end}
      log=J.new({enabled=function()return true end,archive=wrapped,
        now=function()return '2026-09-15T08:30:00Z'end,clock=function()return time end,
        observe=function()return {snapshot={phase='hand',chips=125},advice={status='current'}}end})
      local seq=assert(log:before('play',{indices={1}}))
      time=time+0.03125;log:after(seq,true)
      time=time+0.09375;assert(log:timing('performance_summary',{metrics={['journal.append']={seconds=0.0078125,count=2}}}))
      time=time+0.125;assert(log:event('checkpoint_saved',{slot=2}))
      return 'done'
    ''')
    _,values=self.decoded()
    self.exact(values)
    records=[json.loads(raw) for raw,_ in values]
    self.assertEqual([r['sequence'] for r in records],[1,2,3,4])
    self.assertEqual([r['monotonic_seconds'] for r in records],
                     [314159.125,314159.15625,314159.25,314159.375])
    self.assertTrue(all(r['monotonic_status']=='available' for r in records))
    self.assertTrue(all(r['at']=='2026-09-15T08:30:00Z' for r in records))
    self.assertEqual(records[1]['details']['action_sequence'],1)
    self.assertEqual(records[2]['context'],{})
    self.assertEqual(records[2]['details']['metrics']['journal.append']['seconds'],0.0078125)
    self.assertEqual(records[3]['details']['slot'],2)

module.Archive.test_precise_journal_timestamps_and_compact_timing_roundtrip=test_precise_journal_timestamps_and_compact_timing_roundtrip
suite=unittest.defaultTestLoader.loadTestsFromTestCase(module.Archive)
result=unittest.TextTestRunner(verbosity=1).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
