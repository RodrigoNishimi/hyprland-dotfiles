-- ==================================================================
-- Tokens do "Hyprland Rice Kit" — seção 06 (Tokens do tema /
-- Geometria e tipografia). Fonte única de verdade da barra: bar.lua
-- e style.lua não têm nenhum valor cru dentro deles.
-- ==================================================================
local M = {}

-- ── Paleta ────────────────────────────────────────────────────────
-- palette.lua é gerado por `theme set` (template eww-palette.lua.in),
-- do mesmo jeito que conf/colors.lua do Hyprland. Sem ele, cai no
-- tokyonight do kit para a barra subir mesmo assim.
local loaded, palette = pcall(require, "palette")
if not loaded then
    palette = {
        theme = "tokyonight", variant = "dark",
        base = "#1a1b26", surface = "#16161e", overlay = "#292e42",
        termBg = "#101014",
        highlightLow = "#16161e", highlightMed = "#292e42", highlightHigh = "#3b4261",
        muted = "#565f89", subtle = "#9aa5ce", text = "#c0caf5",
        red = "#f7768e", green = "#9ece6a", yellow = "#e0af68",
        blue = "#7aa2f7", magenta = "#bb9af7", cyan = "#7dcfff",
        accent = "#7aa2f7", accentAlt = "#bb9af7",
        success = "#9ece6a", warning = "#e0af68", error = "#f7768e", info = "#2ac3de",
    }
end
M.color = palette

-- #rrggbb + alfa -> rgba(r,g,b,a), que é o que o GTK entende.
function M.rgba(hex, alpha)
    local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
    assert(r, "cor fora do formato #rrggbb: " .. tostring(hex))
    return ("rgba(%d,%d,%d,%s)"):format(
        tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tostring(alpha))
end

-- #rrggbb -> 0xaarrggbb, que é o que o Hyprland entende.
function M.argb(hex, alpha)
    return ("0x%02x%s"):format(math.floor(alpha * 255 + 0.5), hex:sub(2))
end

-- ── Superfícies ───────────────────────────────────────────────────
-- O kit oferece três: Sólido (1.0 / blur 0), Translúcido (0.86 / 10px)
-- e Vidro fosco (0.72 / 18px). O blur de verdade não sai do GTK — quem
-- borra é o Hyprland, via layer_rule em conf/rice.lua.
M.surfaceMode = "glass"

local surfaces = {
    solid  = { alpha = 1.00, blur = 0 },
    veil   = { alpha = 0.86, blur = 10 },
    glass  = { alpha = 0.72, blur = 18 },
}
M.surfaceAlpha = surfaces[M.surfaceMode].alpha

M.surface = {
    island  = M.rgba(palette.base, M.surfaceAlpha),
    panel   = M.rgba(palette.base, 0.85),
    border  = M.rgba(palette.text, 0.08),
    chip    = M.rgba(palette.text, 0.09),
    divider = M.rgba(palette.text, 0.12),
    rule    = M.rgba(palette.text, 0.14),
    track   = M.rgba(palette.text, 0.10),
}

-- ── Geometria ─────────────────────────────────────────────────────
M.geometry = {
    barHeight   = 40,   -- altura da barra
    barMargin   = 14,   -- margem da barra
    radiusChip  = 14,   -- raio — chip / ilha
    radiusPanel = 22,   -- raio — card / painel
    radiusInner = 8,    -- pílulas dentro da ilha
    chipMin     = 24,   -- lado do chip de workspace
    chipMinWide = 34,   -- idem, no workspace ativo
    borderWidth = 1,    -- contorno da ilha
    gap = { xs = 5, sm = 8, md = 10, lg = 14, xl = 16, pad = 22 },
}

-- Ajustes que valem para o compositor, não para o GTK. conf/rice.lua
-- do Hyprland lê este bloco.
M.hyprland = {
    gapsIn      = 6,
    gapsOut     = 14,
    borderSize  = 2,             -- 2px · blue -> mauve
    rounding    = M.geometry.radiusChip,
    blur        = { size = 8, passes = 3 },
    shadow      = { range = 24, alpha = 0.55 },
    -- ignore_alpha em 0 corta só o que é totalmente transparente: os vãos
    -- entre as ilhas. Subir esse valor devolve o halo leitoso na borda.
    layerBlur   = { namespace = "gtk-layer-shell", ignoreAlpha = 0.0 },
}

-- ── Tipografia ────────────────────────────────────────────────────
M.font = {
    display = "Chakra Petch",              -- DISPLAY  · 300
    ui      = "JetBrainsMono Nerd Font",   -- UI/MONO  · 400
    icon    = "Material Symbols Rounded",  -- ÍCONES
    weight  = { display = 300, ui = 400, medium = 500, bold = 600 },
    size    = {
        iconLg = 18, iconMd = 17, iconSm = 15,
        clock  = 14, body = 13, label = 12, micro = 11,
    },
}

-- ── Ícones ────────────────────────────────────────────────────────
-- Codepoints do Material Symbols Rounded. As ligaduras por nome
-- ("wifi") dependem de o Pango ligar `liga` na fonte; codepoint
-- sempre resolve.
local function cp(hex) return utf8.char(tonumber(hex, 16)) end

M.icon = {
    stack            = cp("f609"),
    terminal         = cp("eb8e"),
    memory           = cp("e322"),
    memoryAlt        = cp("f7a3"),
    thermostat       = cp("e1ff"),
    bluetooth        = cp("e1a7"),
    bluetoothOn      = cp("e1a8"),
    bluetoothOff     = cp("e1a9"),
    wifi             = cp("e63e"),
    wifiOff          = cp("e648"),
    notifications    = cp("e7f4"),
    notificationsOff = cp("e7f6"),
    volumeUp         = cp("e050"),
    volumeDown       = cp("e04d"),
    volumeOff        = cp("e04f"),
    brightness       = cp("e1ad"),
    batteryCharging  = cp("e1a3"),
    batteryAlert     = cp("e19c"),
    battery          = {              -- do vazio ao cheio
        cp("ebdc"), cp("f09c"), cp("f09d"), cp("f09e"),
        cp("f09f"), cp("f0a0"), cp("f0a1"),
    },
    power            = cp("f8c7"),
    arch             = cp("f303"), -- Nerd Font: Arch Linux
    chevronLeft      = cp("e5cb"),
    chevronRight     = cp("e5cc"),
}

-- ── Papéis de cor da barra ────────────────────────────────────────
-- O kit nomeia o que cada acento significa; a barra segue isso.
M.role = {
    cpu   = palette.cyan,       -- cyan · cpu
    ram   = palette.magenta,    -- magenta · ram
    temp  = palette.peach or palette.warning, -- peach · aviso
    disk  = palette.info,       -- blue1 · disco
    ok    = palette.success,    -- green · ok
    warn  = palette.warning,    -- yellow · brilho
    crit  = palette.error,      -- red · crítico
    dim   = palette.highlightHigh,
}

return M
