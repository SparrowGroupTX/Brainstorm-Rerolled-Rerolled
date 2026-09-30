-- Extend the existing Game speed control; all event/timer behavior stays native.
local M = {}

function M.attach(env)
  local original = env.create_option_cycle
  if type(original) ~= 'function' then return false end
  local callback = 'brainstorm_change_gamespeed'
  env.create_option_cycle = function(args, ...)
    local g = env.G
    if type(args) ~= 'table' or args.opt_callback ~= 'change_gamespeed'
      or type(g) ~= 'table' or type(g.SETTINGS) ~= 'table'
      or type(g.FUNCS) ~= 'table' or type(g.save_settings) ~= 'function'
      or type(args.options) ~= 'table' then return original(args, ...) end
    local options, numeric, count, last, string_labels = {}, {}, 0, 0, false
    -- Refuse an unfamiliar control instead of remapping its callback semantics.
    for k in pairs(args.options) do
      count = count + 1
      if count > 64 or type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then
        return original(args, ...)
      end
    end
    for i = 1, count do
      local label = args.options[i]
      local value = (type(label) == 'number' or type(label) == 'string') and tonumber(label)
      if not value or value ~= value or value <= last or value == math.huge then
        return original(args, ...)
      end
      options[i], last = label, value
      string_labels = string_labels or type(label) == 'string'
    end
    if count == 0 then return original(args, ...) end
    for _, extra in ipairs({8, 16}) do
      local found = false
      for _, value in ipairs(options) do if tonumber(value) == extra then found = true end end
      if not found then options[#options + 1] = string_labels and tostring(extra) or extra end
    end
    table.sort(options, function(a, b) return tonumber(a) < tonumber(b) end)
    local current
    for i, value in ipairs(options) do
      numeric[i] = tonumber(value)
      if numeric[i] == g.SETTINGS.GAMESPEED then current = i end
    end
    -- Preserve an unfamiliar persisted speed without displaying a false value.
    if not current then return original(args, ...) end
    local copy = {}
    for k, value in pairs(args) do copy[k] = value end
    copy.options, copy.current_option, copy.opt_callback = options, current, callback
    g.FUNCS[callback] = function(selection)
      if env.G ~= g or type(selection) ~= 'table' or type(selection.cycle_config) ~= 'table' then return false end
      local index = selection.cycle_config.current_option
      if type(index) ~= 'number' or index % 1 ~= 0 or not options[index]
        or selection.to_val ~= options[index] then return false end
      g.SETTINGS.GAMESPEED = numeric[index]
      g:save_settings()
      return true
    end
    return original(copy, ...)
  end
  return true
end

return M
