"""Pure Lua writer + fake filesystem + Python decoder/zlib roundtrips."""
import ctypes
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


Reader = load('archive_reader_tested', ROOT / 'tools/advisor_eval/read_player_log.py')
"""Exact byte-preserving Lua 5.1 literals without concatenation syntax depth.

No runtime, source, filesystem, or registration access occurs on import.
"""
import math


def literal(raw):
    raw = raw.encode('utf-8') if isinstance(raw, str) else raw
    if not isinstance(raw, bytes):
        raise TypeError('Lua literal requires text or bytes')
    pieces = [b'"']
    for value in raw:
        if value < 32 or value == 127 or value in (34, 92):
            # Always use three decimal digits so a following ASCII digit cannot
            # become part of the escape. CR and LF stay distinct original bytes.
            pieces.append(('\\%03d' % value).encode('ascii'))
        else:
            pieces.append(bytes((value,)))
    pieces.append(b'"')
    return b''.join(pieces)


def lua_value(value):
    if value is None:
        return b'nil'
    if type(value) is bool:
        return b'true' if value else b'false'
    if type(value) in (int, float):
        if not math.isfinite(value):
            raise ValueError('Nonfinite Lua input')
        return str(value).encode('ascii')
    if isinstance(value, str):
        return literal(value)
    if isinstance(value, list):
        return b'{' + b','.join(lua_value(item) for item in value) + b'}'
    if isinstance(value, dict):
        return b'{' + b','.join(b'[ ' + lua_value(key) + b' ]=' + lua_value(item)
                                for key, item in sorted(value.items())) + b'}'
    raise TypeError('Unsupported Lua input')

class LuaBytes:
    lua_value = staticmethod(lua_value)

Runtime = load('archive_fixture_runtime', ROOT / 'tests/run_lua_tests.py')


SETUP = b'''
A=dofile('Brainstorm/Advisor/player_log_archive.lua')
J=dofile('Brainstorm/Advisor/player_journal.lua')
files={};dirs={};originals={};writes=0;identity={};profile={};fault=nil
fs={}
function fs.getInfo(path)
  if dirs[path]then return{type='directory'}end
  if files[path]then return{type='file',size=#files[path]}end
end
function fs.createDirectory(path)dirs[path]=true;return true end
function fs.getDirectoryItems(path)
  local names={};for name in pairs(files)do
    if name:sub(1,#path+1)==path..'/'then names[#names+1]=name:sub(#path+2)end
  end;table.sort(names);return names
end
function fs.append(path,bytes)
  writes=writes+1
  if fault=='partial'then files[path]=(files[path]or'')..bytes:sub(1,9);return nil,'synthetic partial write'end
  if fault=='corrupt'then bytes='X'..bytes:sub(2)end
    files[path]=(files[path]or'')..bytes;return true
end
function fs.remove(path)if files[path]==nil then return nil,'missing'end;files[path]=nil;return true end
function read_range(path,offset,size)
  if fault=='readback'then return 'bad'end
  return files[path]:sub(offset+1,offset+size)
end
function archive(options)
  options=options or{}
  return A.new({fs=fs,encode=J.encode,encode_frame=J.encode_frame,hash=HOST_HASH,
    compress=not options.raw and HOST_COMPRESS or nil,decompress=HOST_DECOMPRESS,
    read_range=read_range,limits=options.limits,scope=options.scope,session_name=function()return 'fixed'end,
    identity=function()return identity,profile end})
end
function emit(writer,seq,snapshot,advice)
  local event={schema=1,sequence=seq,kind='action_requested',at='fixed',
    context={snapshot=snapshot,advice={status='current',lines={advice or 'current advice'},action={kind='discard',indices={1,2}}}},
    details={action_sequence=seq,source='auto_run'}}
  local raw=assert(J.encode(event));originals[seq]=raw
  return writer:append(event,raw)
end
function dump()
  for path,bytes in pairs(files)do HOST_SINK(path,bytes)end
  for seq,raw in pairs(originals)do HOST_SINK('original:'..seq,raw)end
  return 'dumped'
end
'''


class Lua:
    def __init__(self):
        self.lib = Runtime.LuaLibrary(Runtime.BALATRO_DLL).library
        self.lib.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        self.lib.luaL_loadstring.restype = ctypes.c_int
        self.lib.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.lib.lua_pushlstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
        self.lib.lua_pushlstring.restype = None
        self.lib.lua_pushcclosure.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
        self.lib.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
        self.state = self.lib.luaL_newstate()
        self.lib.luaL_openlibs(self.state)
        self.outputs = {}
        self.callbacks = []
        self.register('HOST_HASH', lambda args: hashlib.sha256(args[0]).hexdigest().encode())
        self.register('HOST_COMPRESS', lambda args: zlib.compress(args[0], 6))
        self.register('HOST_DECOMPRESS', lambda args: zlib.decompress(args[0]))
        self.register('HOST_SINK', self.sink)
        self.evaluate(SETUP + b"return 'ready'")

    def string(self, state, index):
        length = ctypes.c_size_t()
        ptr = self.lib.lua_tolstring(state, index, ctypes.byref(length))
        return ctypes.string_at(ptr, length.value) if ptr else b''

    def sink(self, args):
        self.outputs[args[0].decode()] = args[1]
        return b'written'

    def register(self, name, callback):
        @ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
        def invoke(state):
            try:
                result = callback([self.string(state, 1), self.string(state, 2)])
            except Exception as error:
                result = ('HOST_ERROR:' + str(error)).encode()
            self.lib.lua_pushlstring(state, result, len(result))
            return 1
        self.callbacks.append(invoke)
        self.lib.lua_pushcclosure(self.state, invoke, 0)
        self.lib.lua_setfield(self.state, -10002, name.encode())

    def evaluate(self, code):
        if isinstance(code, str):
            code = code.encode('utf-8')
        status = self.lib.luaL_loadstring(self.state, code)
        if status == 0:
            status = self.lib.lua_pcall(self.state, 0, 1, 0)
        result = self.string(self.state, -1)
        self.lib.lua_settop(self.state, 0)
        if status:
            raise AssertionError(result.decode('utf-8', 'replace'))
        return result

    def close(self):
        self.lib.lua_close(self.state)


class Archive(unittest.TestCase):
    def setUp(self):
        self.lua = Lua()

    def tearDown(self):
        self.lua.close()

    def decoded(self):
        self.lua.evaluate('return dump()')
        segments = sorted((name, raw) for name, raw in self.lua.outputs.items() if name.endswith('.brj'))
        values = []
        for name, raw in segments:
            values.extend(Reader.records(io.BytesIO(raw)))
        return segments, values

    def exact(self, values):
        for raw, meta in values:
            self.assertEqual(raw, self.lua.outputs['original:' + str(meta['sequence'])])

    def test_compressed_roundtrip_changed_advice_and_segment_independence(self):
        self.lua.evaluate("w=archive({limits={MAX_SEGMENT_EVENTS=2}});s={phase='hand',cards={string.rep('card',2000)}};assert(emit(w,1,s));assert(emit(w,2,s,'changed advice'));assert(emit(w,3,s));return 'done'")
        segments, values = self.decoded()
        self.assertEqual(len(segments), 2)
        self.exact(values)
        self.assertEqual([x[1]['sequence'] for x in values], [1, 2, 3])
        self.assertIn(b'changed advice', values[1][0])
        self.assertTrue(all(raw.startswith(b'BRJ2\tzlib\t') for _, raw in segments))
        self.assertEqual(values[2][1]['previous_frame_sha256'], values[1][1]['frame_sha256'])
        self.assertEqual(list(Reader.records(io.BytesIO(segments[1][1])))[0][0], values[2][0])

    def test_actual_game_and_profile_replacements_rotate_without_rewriting(self):
        self.lua.evaluate("w=archive();s={phase='shop'};assert(emit(w,1,s));identity={};assert(emit(w,2,s));profile={};assert(emit(w,3,s));w:rotate('checkpoint');assert(emit(w,4,s));return 'done'")
        segments, values = self.decoded()
        self.assertEqual(len(segments), 4)
        self.exact(values)

    def test_raw_frames_and_byte_rotation(self):
        self.lua.evaluate("w=archive({raw=true,limits={MAX_SEGMENT_BYTES=4096}});s={phase='hand',text=string.rep('x',1700)};assert(emit(w,1,s));assert(emit(w,2,s));s.text=string.rep('y',1700);assert(emit(w,3,s));return 'done'")
        segments, values = self.decoded()
        self.assertGreaterEqual(len(segments), 2)
        self.assertTrue(all(len(raw) <= 4096 for _, raw in segments))
        self.assertTrue(all(raw.startswith(b'BRJ2\traw\t') for _, raw in segments))
        self.exact(values)

    def test_old_logs_count_against_unchanged_total_and_file_limit(self):
        result = self.lua.evaluate("dirs.advisor_player_log_v1=true;files['advisor_player_log_v1/session-old.jsonl']=string.rep('L',1000);w=archive({limits={MAX_TOTAL_BYTES=1050}});local ok,why=emit(w,1,{x=1});assert(not ok and why:find('Total observation',1,true));assert(writes==0 and #files['advisor_player_log_v1/session-old.jsonl']==1000);return 'done'")
        self.assertEqual(result, b'done')
        self.lua.evaluate("w=archive({limits={MAX_FILES=1}});local ok,why=emit(w,1,{x=1});assert(not ok and why:find('file-count',1,true));assert(writes==0);return 'done'")

    def test_auto_and_manual_have_independent_ten_gib_catalogs_and_clear_scope(self):
        self.lua.evaluate('''
            dirs.advisor_player_log_v1=true;dirs.advisor_manual_log_v1=true
            files['advisor_player_log_v1/session-old.jsonl']='auto-old'
            files['advisor_manual_log_v1/unknown.partial']='manual-keep'
            local original_info=fs.getInfo
            fs.getInfo=function(path)
                if path=='advisor_player_log_v1/session-old.jsonl' and files[path] then return {type='file',size=10737418000}end
                return original_info(path)
            end
            m=archive({scope='manual'});assert(emit(m,1,{actor='human'}))
            assert(m.path:match('^advisor_manual_log_v1/'))
            local ok,why=m:prepare_collection({clear_existing=true})
            assert(not ok and why:find('cannot be cleared',1,true))
            assert(files[m.path] and files['advisor_manual_log_v1/unknown.partial']=='manual-keep')
            w=archive();assert(not emit(w,1,{x=1}))
            assert(w:prepare_collection({clear_existing=true}))
            assert(files[m.path] and files['advisor_manual_log_v1/unknown.partial']=='manual-keep')
            assert(not files['advisor_player_log_v1/session-old.jsonl'])
            assert(not pcall(archive,{scope='other'}))
            return 'done'
        ''')

    def test_partial_append_preserves_valid_prefix_and_stops(self):
        self.lua.evaluate("w=archive();assert(emit(w,1,{x=1}));fault='partial';assert(not emit(w,2,{x=2}));fault=nil;assert(not emit(w,3,{x=3}));assert(writes==2 and w.events==1);return dump()")
        raw = next(v for k, v in self.lua.outputs.items() if k.endswith('.brj'))
        iterator = Reader.records(io.BytesIO(raw))
        self.assertEqual(next(iterator)[0], self.lua.outputs['original:1'])
        with self.assertRaises(Reader.ArchiveError):
            next(iterator)

    def test_authorized_gib_allowance_counts_legacy_metadata_without_large_allocation(self):
        self.lua.evaluate('''
            dirs.advisor_player_log_v1=true
            files['advisor_player_log_v1/old.jsonl']='retained'
            local original_info=fs.getInfo
            fs.getInfo=function(path)
                if path=='advisor_player_log_v1/old.jsonl' then return {type='file',size=134217728} end
                return original_info(path)
            end
            w=archive();assert(emit(w,1,{x=1}))
            assert(w.physical_bytes==134217728+#files[w.path])
            assert(w.physical_bytes<1073741824 and writes==1)
            assert(files['advisor_player_log_v1/old.jsonl']=='retained')
            return 'done'
        ''')

    def test_ten_gib_limit_still_blocks_before_append_including_unknown_log_names(self):
        result = self.lua.evaluate('''
            dirs.advisor_player_log_v1=true;dirs.advisor_player_log_v2=true
            files['advisor_player_log_v1/old.jsonl']='old'
            files['advisor_player_log_v2/unknown.partial']='tail'
            local original_info=fs.getInfo
            fs.getInfo=function(path)
                if path=='advisor_player_log_v1/old.jsonl' then return {type='file',size=5368709120} end
                if path=='advisor_player_log_v2/unknown.partial' then return {type='file',size=5368709020} end
                return original_info(path)
            end
            w=archive();local ok,why=emit(w,1,{x=1})
            assert(not ok and why:find('Total observation byte limit',1,true))
            assert(writes==0 and files['advisor_player_log_v1/old.jsonl']=='old')
            assert(files['advisor_player_log_v2/unknown.partial']=='tail')
            assert(not pcall(archive,{limits={MAX_TOTAL_BYTES=10737418241}}))
            return 'done'
        ''')
        self.assertEqual(result, b'done')

    def test_corruption_and_readback_failure_stop_without_discarding_bytes(self):
        self.lua.evaluate("w=archive();fault='corrupt';assert(not emit(w,1,{x=1}));assert(w.error and writes==1 and w.events==0);return dump()")
        raw = next(v for k, v in self.lua.outputs.items() if k.endswith('.brj'))
        with self.assertRaises(Reader.ArchiveError):
            list(Reader.records(io.BytesIO(raw)))
        self.lua.evaluate("fault='readback';w=archive();assert(not emit(w,1,{x=2}));assert(writes==2 and w.events==0);return 'done'")

    def test_restart_uses_new_file_and_references_never_cross_segments(self):
        self.lua.evaluate("w=archive();assert(emit(w,1,{x=1}));oldpath=w.path;oldbytes=files[oldpath];w=archive();assert(emit(w,1,{x=1}));assert(files[oldpath]==oldbytes and w.path~=oldpath);return dump()")
        segments = [(k, v) for k, v in self.lua.outputs.items() if k.endswith('.brj')]
        self.assertEqual(len(segments), 2)
        self.assertTrue(all(len(list(Reader.records(io.BytesIO(raw)))) == 1 for _, raw in segments))

    def test_session_bound_does_not_reset_on_rotation(self):
        self.lua.evaluate("w=archive({limits={MAX_SESSION_EVENTS=3,MAX_SEGMENT_EVENTS=1}});for i=1,3 do assert(emit(w,i,{x=i}))end;assert(not emit(w,4,{x=4}));assert(w.events==3 and writes==3);return 'done'")

    def test_compression_roundtrip_failure_and_external_append_detected(self):
        self.lua.evaluate("w=A.new({fs=fs,encode=J.encode,encode_frame=J.encode_frame,hash=HOST_HASH,compress=function()return 'bad'end,decompress=function()return 'different'end,read_range=read_range});assert(not emit(w,1,{x=1}));assert(writes==0);return 'done'")
        self.lua.evaluate("w=archive();assert(emit(w,1,{x=1}));files[w.path]=files[w.path]..'outside';assert(not emit(w,2,{x=2}));assert(writes==1);return 'done'")

    def test_redaction_precedes_lossless_storage(self):
        self.lua.evaluate("w=archive();s=J.public_snapshot({hand={{id='a',rank=13,face_down=true}},deck={{id='b',rank=14,face_down=true}},playing_cards={{id='a',rank=13},{id='b',rank=14,face_down=true},{id='c',rank=10}}});assert(emit(w,1,s));return 'done'")
        _, values = self.decoded()
        self.exact(values)
        snapshot = json.loads(values[0][0])['context']['snapshot']
        self.assertNotIn('rank', snapshot['hand'][0])
        self.assertNotIn('rank', snapshot['deck'][0])
        self.assertEqual(snapshot['playing_cards'][2]['rank'], 10)

    def test_large_utf8_chunk_boundaries_reconstruct_exact_original_json(self):
        value = {'phase': 'hand', 'strings': ['é漢🙂' * 18000, 'é漢🙂' * 18000, 'é漢🙂' * 18000]}
        self.lua.evaluate(b'w=archive();assert(emit(w,1,' + LuaBytes.lua_value(value) + b'));return "done"')
        _, values = self.decoded()
        self.exact(values)
        self.assertEqual(json.loads(values[0][0])['context']['snapshot'], value)

    def test_v1_reader_retains_exact_original_bytes(self):
        raw = b'{"schema":1,"sequence":1,"kind":"old","context":{}}\n'
        self.assertEqual(list(Reader.records(io.BytesIO(raw)))[0][0], raw)
        with self.assertRaises(Reader.ArchiveError):
            list(Reader.records(io.BytesIO(raw[:-1])))

    def test_reader_detects_changed_hash_missing_reference_and_zlib_bomb(self):
        self.lua.evaluate("w=archive();s={text=string.rep('x',2000)};assert(emit(w,1,s));assert(emit(w,2,s));return dump()")
        raw = next(v for k, v in self.lua.outputs.items() if k.endswith('.brj'))
        with self.assertRaises(Reader.ArchiveError):
            list(Reader.records(io.BytesIO(raw[:-2] + b'X\n')))
        head, rest = raw.split(b'\n', 1)
        stored = int(head.split(b'\t')[2])
        second = rest[stored + 1:]
        with self.assertRaisesRegex(Reader.ArchiveError, 'Missing same-segment'):
            list(Reader.records(io.BytesIO(second)))
        payload = zlib.compress(b'x' * (Reader.MAX_FRAME + 1))
        header = b'BRJ2\tzlib\t%d\t%d\t1\t%s\t%s\n' % (len(payload), Reader.MAX_FRAME, b'0' * 64, b'0' * 64)
        with self.assertRaises(Reader.ArchiveError):
            list(Reader.records(io.BytesIO(header + payload + b'\n')))

    def test_actual_journal_attach_linkage_rotation_and_disabled_no_storage(self):
        self.lua.evaluate("""
          local g={GAME={round=1,pseudorandom={seed='SYNTH'},stake=8},PROFILES={[1]={}},SETTINGS={profile=1},
            STATE=1,STATES={},STATE_COMPLETE=true,CONTROLLER={locks={}},FUNCS={}}
          local advisor={snapshot={capture=function()return{phase='hand',dollars=5}end,fingerprint=function()return 'fresh'end},
            published_key='fresh',published_game=g.GAME,result={action={kind='discard'}},display={title='Keep growing'},lines={'Recorded advice'}}
          local b={VERSION='synthetic',config={advisor={player_logging=false}}}
          local log=J.attach(advisor,b,{game=function()return g end,fs=fs,archive_module=A,hash=HOST_HASH,
            compress=HOST_COMPRESS,decompress=HOST_DECOMPRESS,read_range=read_range,now=function()return 'fixed'end,
            session_name=function()return 'attached'end})
          assert(not log:event('disabled')and writes==0 and next(files)==nil)
          b.config.advisor.player_logging=true
          local seq=log:before('advisor_execute',{action={kind='discard'}});assert(seq==1)
          log:after(seq,true);log:update(g)
          assert(log:event('checkpoint_save_requested',{slot=1}))
          assert(log:event('continuation',{}));assert(log.events==5 and log.physical_bytes>0 and not log.error)
          return dump()
        """)
        segments = sorted((k, v) for k, v in self.lua.outputs.items() if k.endswith('.brj'))
        self.assertEqual(len(segments), 2)
        records = [json.loads(raw) for _, segment in segments for raw, _ in Reader.records(io.BytesIO(segment))]
        self.assertEqual(records[0]['context']['advice']['lines'], ['Recorded advice'])
        self.assertEqual(records[1]['details']['action_sequence'], records[0]['sequence'])
        self.assertEqual(records[2]['kind'], 'state_after_actions')
        self.assertEqual(records[3]['details']['slot'], 1)

    def test_direct_non_snapshot_events_keep_exact_bytes(self):
        self.lua.evaluate("w=archive();assert(emit(w,1,nil));assert(emit(w,2,nil,'different'));return 'done'")
        _, values = self.decoded()
        self.exact(values)


if __name__ == '__main__':
    unittest.main()
