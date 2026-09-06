-- conf.colors é gerado por `theme set`; sem ele, cinza neutro para o
-- Hyprland subir mesmo assim.
local loaded, M = pcall(require, "conf.colors")
if not loaded then
    M = setmetatable({}, { __index = function() return "0xff808080" end })
end

-- conf.rice é a geometria do "Hyprland Rice Kit" (seção 06), gerada por
-- ~/.config/eww/lua/build.lua a partir de lua/tokens.lua — a mesma fonte
-- que desenha a barra. Sem ele, os números que já estavam aqui.
local riced, R = pcall(require, "conf.rice")
if not riced then
    R = {
        gapsIn = 6, gapsOut = 14, borderSize = 2, rounding = 8,
        blur = { size = 8, passes = 3 },
        shadow = { range = 24, color = "0x99000000" },
        bar = { namespace = "gtk-layer-shell", ignoreAlpha = 0.0 },
    }
end

local selectionRule = hl.layer_rule({
    name    = "no-anim-for-selection",
    match   = { namespace = "selection" },
    no_anim = true,
})

-- Blur nas camadas do desktop. O ignore_alpha corta o fundo transparente
-- antes do blur: sem ele a barra ganha um halo leitoso na borda.
for _, layer in ipairs({
    { name = "blur-bar", namespace = R.bar.namespace }, -- barra do eww
    { name = "blur-rofi", namespace = "rofi" },
    { name = "blur-notifications", namespace = "notifications" }, -- mako
}) do
    hl.layer_rule({
        name         = layer.name,
        match        = { namespace = layer.namespace },
        blur         = true,
        ignore_alpha = R.bar.ignoreAlpha,
    })
end

hl.config({
    cursor = {
        sync_gsettings_theme = true,
        no_hardware_cursors = false,
    },

    general = {
        gaps_in = R.gapsIn,
        gaps_out = R.gapsOut,

        border_size = R.borderSize,

        col = {
            active_border = { colors = { M.accent, M.accentAlt }, angle = 45 },
            inactive_border = M.muted,
        },

        resize_on_border = true,

        -- Ligar exige atenção: https://wiki.hyprland.org/Configuring/Tearing/
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = R.rounding,

        active_opacity = 1.0,
        inactive_opacity = 0.94,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled = true,
            range = R.shadow.range,
            render_power = 3,
            color = R.shadow.color,
            color_inactive = "0x4d000000",
        },

        blur = {
            enabled = true,
            size = R.blur.size,
            passes = R.blur.passes,

            new_optimizations = true,
            ignore_opacity = true,
            xray = false,

            noise = 0.015,
            contrast = 1.05,
            brightness = 0.85,
            vibrancy = 0.18,
        }
    },

    dwindle = {
        preserve_split = true,
        smart_split = false,
    },

    group = {
        col = {
            border_active = { colors = { M.green, M.yellow }, angle = 45 },
            border_inactive = M.muted
        },

        groupbar = {
            enabled = false,
        }
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
        animate_manual_resizes = true,
    },

    animations = {
        enabled = true,
    },
})

-- ── Curvas ────────────────────────────────────────────────────────────────────
hl.curve("snap", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("overshoot", { type = "bezier", points = { { 0.16, 1.24 }, { 0.32, 1.0 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.curve("fluent_decel", { type = "bezier", points = { { 0, 0.2 }, { 0.4, 1 } } })
hl.curve("easeinoutsine", { type = "bezier", points = { { 0.37, 0 }, { 0.63, 1 } } })

-- Windows
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "overshoot", style = "popin 88%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "smooth", style = "slide" })

-- Fading
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "fadeLayersIn", enabled = false })

-- Bordas. O borderangle em loop gira o gradiente sem parar: é a assinatura do
-- tema, mas redesenha a tela continuamente. Num notebook na bateria,
-- `enabled = false` só nesta linha resolve.
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "smooth" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "smooth", style = "loop" })

-- Layers
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "overshoot", style = "popin 92%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "smooth", style = "popin 92%" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "snap", style = "slidefadevert 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "overshoot", style = "slidevert" })
