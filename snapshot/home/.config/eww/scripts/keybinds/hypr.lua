-- Evaluate only the bindings module against inert dispatchers. Never run callbacks.
package.path = os.getenv('HOME') .. '/.config/hypr/?.lua;' .. package.path
local function value(v)
  if type(v) ~= 'table' then return tostring(v) end
  local out = {}
  for k, x in pairs(v) do out[#out+1] = k .. '=' .. value(x) end
  table.sort(out)
  return table.concat(out, ', ')
end
local function dsp(path)
  return setmetatable({}, {
    __index = function(_, k) return dsp(path .. '.' .. k) end,
    __call = function(_, arg) return path .. '(' .. (arg and value(arg) or '') .. ')' end,
  })
end
local submap = ''
hl = { dsp = dsp(''), define_submap = function(name, cb) submap = name; cb(); submap = '' end }
hl.bind = function(key, action)
  if type(action) == 'function' then
    local info = debug.getinfo(action, 'S')
    local lines, n = {}, 0
    for line in io.lines(info.source:sub(2)) do
      n = n + 1
      if n >= info.linedefined and n <= info.lastlinedefined then lines[#lines+1] = line end
    end
    action = table.concat(lines, ' ')
  end
  print(submap .. '\t' .. key .. '\t' .. tostring(action):gsub('[\t\n\r]', ' '))
end
require('conf.keybinds')
