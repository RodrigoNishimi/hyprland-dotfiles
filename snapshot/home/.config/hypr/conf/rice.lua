-- ARQUIVO GERADO por ~/.config/eww/lua/build.lua — NÃO EDITE.
-- Geometria do "Hyprland Rice Kit" (seção 06 — Geometria e tipografia).
-- Para mudar qualquer número aqui, mexa em ~/.config/eww/lua/tokens.lua
-- e rode `lua ~/.config/eww/lua/build.lua && hyprctl reload`.
return {
    gapsIn     = 6,
    gapsOut    = 14,
    borderSize = 2,
    rounding   = 14,

    blur   = { size = 8, passes = 3 },
    shadow = { range = 24, color = "0x8c000000" },

    -- A barra do eww sobe como layer `gtk-layer-shell`. O vidro fosco
    -- do kit não sai do GTK: quem borra o que está atrás das ilhas é o
    -- compositor, e ignore_alpha mantém os vãos entre elas limpos.
    bar = {
        height      = 40,
        margin      = 14,
        namespace   = "gtk-layer-shell",
        ignoreAlpha = 0.0,
    },

    font = {
        display = "Chakra Petch",
        ui      = "JetBrainsMono Nerd Font",
        icon    = "Material Symbols Rounded",
    },
}
