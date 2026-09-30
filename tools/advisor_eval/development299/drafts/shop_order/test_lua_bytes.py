"""Ordinary synthetic serializer tests; no captured snapshots/source/game actions."""
from pathlib import Path
import ctypes
import unittest
from lua_bytes import literal, lua_value


class LuaBytesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
        cls.lib = ctypes.CDLL(str(path))
        cls.lib.luaL_newstate.restype = ctypes.c_void_p
        cls.lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        cls.lib.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        cls.lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        cls.lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        cls.lib.lua_tolstring.restype = ctypes.c_void_p
        cls.lib.lua_close.argtypes = [ctypes.c_void_p]

    def evaluate(self, source):
        state = self.lib.luaL_newstate()
        self.assertTrue(state)
        try:
            self.lib.luaL_openlibs(state)
            status = self.lib.luaL_loadbuffer(state, source, len(source), b'@ordinary_serializer_fixture')
            if not status:
                status = self.lib.lua_pcall(state, 0, 1, 0)
            size = ctypes.c_size_t()
            pointer = self.lib.lua_tolstring(state, -1, ctypes.byref(size))
            result = ctypes.string_at(pointer, size.value) if pointer else b''
            self.assertEqual(status, 0, result.decode(errors='replace'))
            return result
        finally:
            self.lib.lua_close(state)

    def test_every_byte_and_following_digits(self):
        data = b''.join(bytes((n,)) + b'123' for n in range(256))
        self.assertEqual(self.evaluate(b'return ' + literal(data)), data)

    def test_large_crlf_payload_has_no_concat_depth(self):
        data = (b'-- synthetic line "\\\x00 0123456789\r\n' * 4000) + b'final\rbare\nline'
        encoded = literal(data)
        self.assertNotIn(b'..', encoded)
        self.assertEqual(self.evaluate(b'return ' + encoded), data)

    def test_preloaded_module_preserves_exact_source_bytes(self):
        source = (b'-- synthetic source line\r\n' * 3000) + b'return "success"\r\n'
        wrapper = b'local raw=' + literal(source) + b';local fn=assert(loadstring(raw));assert(fn()=="success");return raw'
        self.assertEqual(self.evaluate(wrapper), source)

    def test_nested_data_strings_keep_newlines_and_utf8(self):
        text = ('synthetic \r\n \r \n "\\ 123 雪\x00' * 400)
        value = {'metadata': {'text': text, 'list': [1, True, None, {'last': '\r\n'}]}}
        source = b'local v=' + lua_value(value) + b';assert(v.metadata.list[1]==1 and v.metadata.list[2] and v.metadata.list[3]==nil);return v.metadata.text'
        self.assertEqual(self.evaluate(source), text.encode('utf-8'))

    def test_rejects_nonfinite_and_executable_values(self):
        for value in (float('nan'), float('inf'), -float('inf')):
            with self.assertRaises(ValueError):
                lua_value(value)
        with self.assertRaises(TypeError):
            lua_value(lambda: 1)


if __name__ == '__main__':
    unittest.main()
