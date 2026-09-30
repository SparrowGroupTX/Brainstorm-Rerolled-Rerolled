"""Copy the current journal and apply a detached v2 storage integration."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def replace(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


text = (ROOT / 'Brainstorm/Advisor/player_journal.lua').read_text(encoding='utf-8')
text = replace(text, 'function M.public_snapshot(snapshot)',
               "function M.encode_frame(value)\n"
               "  local ok,result=pcall(function()return json(plain_copy(value))end)\n"
               "  if not ok then return nil,tostring(result)end\n"
               "  if #result>3145728 then return nil,'Archive frame exceeds its byte bound.'end\n"
               "  return result..'\\n'\n"
               "end\nfunction M.public_snapshot(snapshot)")
text = replace(text, 'if self.events>=M.MAX_EVENTS then', 'if not deps.archive and self.events>=M.MAX_EVENTS then')
text = replace(text, 'if self.bytes+#bytes>M.MAX_SESSION_BYTES then', 'if not deps.archive and self.bytes+#bytes>M.MAX_SESSION_BYTES then')
text = replace(text, '    local written,result,reason=pcall(deps.append,bytes,M.MAX_TOTAL_BYTES)',
               "    local written,result,reason\n"
               "    if deps.archive then written,result,reason=pcall(deps.archive.append,deps.archive,entry,bytes)\n"
               "    else written,result,reason=pcall(deps.append,bytes,M.MAX_TOTAL_BYTES)end")
text = replace(text, "    self.events=self.events+1;self.bytes=self.bytes+#bytes;self.status='Recording '..self.events..' events.'",
               "    self.events=self.events+1;self.bytes=self.bytes+#bytes\n"
               "    self.physical_bytes=deps.archive and deps.archive.physical_bytes or self.bytes\n"
               "    self.status='Recording '..self.events..' events; '..tostring(self.physical_bytes)..' stored bytes.'\n"
               "    if deps.archive and type(kind)=='string'and (kind:match('^checkpoint') or kind=='auto_run' and type(details)=='table'and details.event=='run_finished')then\n"
               "      deps.archive:rotate(kind)\n"
               "    end")
start = text.index('  local path,total\n')
end = text.index('  local function observe()\n', start)
text = text[:start] + '''  local archive
  if not deps.append then
    archive={}
    function archive:append(entry,bytes)
      if not self.inner then
        local module=assert(deps.archive_module or A.player_log_archive,'Observation archive module is unavailable.')
        local function hash(raw)
          if deps.hash then return deps.hash(raw)end
          assert(love and love.data and love.data.hash,'Observation hashing is unavailable.')
          return (love.data.hash('sha256',raw):gsub('.',function(c)return string.format('%02x',string.byte(c))end))
        end
        local compress,decompress
        if B.config.advisor.player_log_compression~=false then
          compress=deps.compress or function(raw)
            assert(love and love.data and love.data.compress,'Observation compression is unavailable.')
            return love.data.compress('string','zlib',raw,6)
          end
          decompress=deps.decompress or function(raw)return love.data.decompress('string','zlib',raw)end
        end
        self.inner=module.new({fs=fs,encode=M.encode,encode_frame=M.encode_frame,hash=hash,
          compress=compress,decompress=decompress,read_range=deps.read_range,limits=deps.archive_limits,
          session_name=deps.session_name,identity=function()
            local g=deps.game and deps.game()or G
            return g and g.GAME,g and g.PROFILES and g.PROFILES[(g.SETTINGS or {}).profile]
          end})
      end
      local okay,why=self.inner:append(entry,bytes)
      self.physical_bytes=self.inner.physical_bytes;return okay,why
    end
    function archive:rotate(reason)if self.inner then self.inner:rotate(reason)end end
  end
''' + text[end:]
text = replace(text, 'observe=deps.observe or observe,', 'observe=deps.observe or observe,archive=archive,')
text = replace(text, 'append=deps.append or append,', 'append=deps.append,')
with (HERE / 'player_journal.lua').open('x', encoding='utf-8', newline='\n') as out:
    out.write(text)
