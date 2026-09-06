-- ==================================================================
-- A fatia do kit que é do compositor, não do GTK: gaps, raio, borda,
-- blur e sombra. Sai como conf/rice.lua para o Hyprland — mesmo
-- arranjo de conf/colors.lua, que `theme set` gera.
-- ==================================================================
local T = require("tokens")

local M = {}

local TEMPLATE = [[
-- ARQUIVO GERADO por ~/.config/eww/lua/build.lua — NÃO EDITE.
-- Geometria do "Hyprland Rice Kit" (seção 06 — Geometria e tipografia).
-- Para mudar qualquer número aqui, mexa em ~/.config/eww/lua/tokens.lua
-- e rode `lua ~/.config/eww/lua/build.lua && hyprctl reload`.
return {
    gapsIn     = %d,
    gapsOut    = %d,
    borderSize = %d,
    rounding   = %d,

    blur   = { size = %d, passes = %d },
    shadow = { range = %d, color = "%s" },

    -- A barra do eww sobe como layer `%s`. O vidro fosco
    -- do kit não sai do GTK: quem borra o que está atrás das ilhas é o
    -- compositor, e ignore_alpha mantém os vãos entre elas limpos.
    bar = {
        height      = %d,
        margin      = %d,
        namespace   = "%s",
        ignoreAlpha = %s,
    },

    font = {
        display = "%s",
        ui      = "%s",
        icon    = "%s",
    },
}
]]

function M.generate()
    local h, g, f = T.hyprland, T.geometry, T.font
    return TEMPLATE:format(
        h.gapsIn, h.gapsOut, h.borderSize, h.rounding,
        h.blur.size, h.blur.passes,
        h.shadow.range, T.argb("#000000", h.shadow.alpha),
        h.layerBlur.namespace,
        g.barHeight, g.barMargin, h.layerBlur.namespace, h.layerBlur.ignoreAlpha,
        f.display, f.ui, f.icon)
end

return M
