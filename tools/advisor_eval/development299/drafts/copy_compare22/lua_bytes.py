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
