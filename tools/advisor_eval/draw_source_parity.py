"""Original draw orientation parity, using the Lua DLL; never runs the game."""
from pathlib import Path
import importlib.util
import tempfile
import zipfile
from discard_source_parity import function_source

ROOT=Path(__file__).resolve().parents[2]
INSTALL=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
def main():
    chunks=['CardArea={};Blind={};Card={};check_for_unlock=function()end']
    with zipfile.ZipFile(INSTALL/'Balatro.exe') as archive:
        for name,signature in [('blind.lua','function Blind:stay_flipped('),('cardarea.lua','function CardArea:emplace('),('card.lua','function Card:is_face(')]:
            chunks.append(function_source(archive.read(name).decode(),signature))
    chunks.append(Path(__file__).with_suffix('.lua').read_text())
    spec=importlib.util.spec_from_file_location('lua_tests',ROOT/'tests/run_lua_tests.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    with tempfile.TemporaryDirectory(prefix='advisor-draw-parity-') as directory:
        path=Path(directory)/'probe.lua';path.write_text('\n'.join(chunks))
        return 0 if mod.LuaLibrary(INSTALL/'lua51.dll').run(path) else 1
if __name__=='__main__':raise SystemExit(main())
