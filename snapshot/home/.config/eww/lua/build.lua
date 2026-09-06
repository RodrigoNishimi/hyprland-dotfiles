#!/usr/bin/env lua
-- ==================================================================
-- Gera bar.yuck e bar.scss a partir dos tokens.
--
--   lua ~/.config/eww/lua/build.lua
--
-- Roda sozinho depois de cada `theme set` (ver reload_apps em
-- ~/.local/bin/theme), que é quem reescreve lua/palette.lua.
-- ==================================================================
-- Onde este arquivo está, chamado de onde for: `lua build.lua`,
-- `lua lua/build.lua` ou pelo caminho absoluto.
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$")
if not here or here:sub(1, 1) ~= "/" then
    local cwd = os.getenv("PWD") or "."
    here = (here and here ~= "" and here ~= ".") and (cwd .. "/" .. here) or cwd
end
package.path = here .. "/?.lua;" .. package.path

local root = assert(here:match("^(.*)/[^/]*$"), "não achei a raiz do config do eww")

local config = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))

local outputs = {
    [root .. "/bar.yuck"]           = require("bar").generate(),
    [root .. "/bar.scss"]           = require("style").generate(),
    [config .. "/hypr/conf/rice.lua"] = require("hypr").generate(),
}

for path, content in pairs(outputs) do
    local fh = assert(io.open(path, "w"))
    fh:write(content)
    fh:close()
    print(("  %s (%d bytes)"):format(path:gsub("^" .. os.getenv("HOME"), "~"), #content))
end
