-- ==================================================================
-- Folha de estilo da barra, emitida a partir dos tokens.
--
-- Duas restrições do GTK3 moldam o que dá para fazer aqui:
--   · não existe backdrop-filter — o vidro fosco do kit é o blur do
--     Hyprland, ligado por layer_rule em conf/rice.lua;
--   · `* { all: unset; font-family: ... }`, no topo de eww.scss, atinge
--     cada elemento direto, então herança de fonte/cor não funciona
--     dentro da barra e cada nó com texto precisa da regra dele.
-- ==================================================================
local T = require("tokens")

local M = {}

local function fmt(template, vars)
    return (template:gsub("%${([%w_]+)}", function(key)
        local v = vars[key]
        assert(v ~= nil, "token ausente no template: " .. key)
        return tostring(v)
    end))
end

-- Só comentários `//` no SCSS gerado: `/* */` sobrevive à compilação e,
-- com acento, faz o grass prefixar `@charset "UTF-8"`, que o eww recusa.
local SHEET = [[
// ==================================================================
// GERADO por lua/build.lua a partir de lua/tokens.lua + lua/style.lua.
// NÃO EDITE — rode `lua ~/.config/eww/lua/build.lua`.
//
// Paleta: ${themeName}. Superfície: ${surfaceMode}.
// ==================================================================

// Base da barra. Precisa vir antes das classes: mesma especificidade,
// então quem chega depois ganha.
.tn-bar, .tn-bar * {
  font-family: "${fontUi}";
  font-size: ${sizeLabel}px;
  font-weight: ${weightUi};
  color: ${subtle};
}

.tn-bar {
  background-color: transparent;
  padding: ${barMargin}px ${barMargin}px 0px ${barMargin}px;
}

.tn-cluster { background-color: transparent; }

// ── Ilha ─────────────────────────────────────────────────────────
.tn-island {
  min-height: ${islandInner}px;
  padding: 0px ${padIsland}px;
  border-radius: ${radiusChip}px;
  background-color: ${island};
  border: ${borderWidth}px solid ${border};
}

.tn-island-square { min-width: ${islandInner}px; padding: 0px; }
.tn-island-ws     { padding: 0px ${padWsRight}px; }
.tn-island-clock  { padding: 0px ${padClock}px; }
.tn-island-tray   { padding: 0px ${padTray}px; }

.tn-sep {
  min-width: 1px;
  min-height: 16px;
  background-color: ${divider};
}

// Eventbox é só área de clique: o GTK3 ignora min-width/min-height nele,
// então quem desenha é sempre uma box por dentro.
.tn-hit { background-color: transparent; }

// ── Ícones ───────────────────────────────────────────────────────
.tn-ico {
  font-family: "${fontIcon}";
  font-size: ${iconMd}px;
  color: ${subtle};
}
.tn-ico-sm { font-size: ${iconSm}px; }
.tn-ico-lg { font-size: ${iconLg}px; }
.tn-ico-arch {
  font-family: "JetBrainsMono Nerd Font";
  font-size: 20px;
  font-weight: 400;
  margin: 0px;
  padding: 0px 6px 0px 0px;
}

.tn-ico-accent { color: ${accent}; }
.tn-ico-subtle { color: ${subtle}; }
.tn-ico-muted  { color: ${muted}; }
.tn-ico-cpu    { color: ${cpu}; }
.tn-ico-ram    { color: ${ram}; }
.tn-ico-temp   { color: ${temp}; }
.tn-ico-ok     { color: ${ok}; }
.tn-ico-warn   { color: ${warn}; }
.tn-ico-crit   { color: ${crit}; }

// ── Workspaces ───────────────────────────────────────────────────
// Os chips saem de scripts/workspace.sh; aqui só o desenho.
.tn-ws { background-color: transparent; }

.tn-ws-chip {
  min-width: ${chipMin}px;
  min-height: ${chipMin}px;
  border-radius: ${radiusInner}px;
  transition: background-color 0.25s ease, color 0.25s ease;
}
.tn-ws-chip label { font-family: "${fontUi}"; font-size: ${sizeLabel}px; }

.tn-ws-free label     { color: ${dim}; }
.tn-hit:hover .tn-ws-free { background-color: ${chip}; }
.tn-ws-occupied       { background-color: ${chip}; }
.tn-ws-occupied label { color: ${subtle}; }

.tn-ws-active {
  min-width: ${chipMinWide}px;
  background-color: ${accent};
  box-shadow: 0px 0px 14px -1px ${accentGlow};
}
.tn-ws-active label { color: ${base}; font-weight: ${weightBold}; }

// ── Janela em foco ───────────────────────────────────────────────
.tn-window-title {
  font-family: "${fontUi}";
  font-size: ${sizeBody}px;
  color: ${subtle};
}

// ── Relógio ──────────────────────────────────────────────────────
.tn-clock-time {
  font-family: "${fontUi}";
  font-size: ${sizeClock}px;
  font-weight: ${weightMedium};
  color: ${text};
}
.tn-clock-date {
  font-family: "${fontUi}";
  font-size: ${sizeLabel}px;
  color: ${subtle};
}
.tn-island-clock { transition: background-color 0.25s ease; }
.tn-hit:hover .tn-island-clock { background-color: ${islandHover}; }

.tn-stat { background-color: transparent; }
.tn-stat-value {
  font-family: "${fontUi}";
  font-size: ${sizeLabel}px;
  color: ${subtle};
  transition: color 0.25s ease;
}
.tn-hit:hover .tn-stat-value { color: ${text}; }
.tn-hit:hover .tn-ico-subtle  { color: ${text}; }
.tn-hit:hover .tn-ico-muted   { color: ${subtle}; }


// ── Bandeja ──────────────────────────────────────────────────────
.tn-island-tray image { margin: 0px 4px; }

.tn-tray-toggle { transition: background-color 0.25s ease; }
.tn-hit:hover .tn-tray-toggle { background-color: ${islandHover}; }
.tn-hit:hover .tn-tray-toggle label { color: ${text}; }

.tn-island-notifications {
  transition: background-color 0.25s ease;
}
.tn-notifications-icon-only {
  min-width: ${islandInner}px;
  padding: 0px;
}
.tn-notifications-with-count { padding: 0px 12px; }
.tn-hit:hover .tn-island-notifications { background-color: ${islandHover}; }
.tn-notification-count {
  font-family: "${fontUi}";
  font-size: ${sizeLabel}px;
  font-weight: ${weightBold};
  color: ${accent};
  margin-left: 7px;
}

// ── Tipografia display ───────────────────────────────────────────
// O papel DISPLAY do kit (Chakra Petch 300) nos números grandes dos
// painéis da barra. Só a fonte: tamanho, cor e posição continuam
// vindo do eww.scss escrito à mão.
.time-hm, .time-ss, .username, .bat-percent {
  font-family: "${fontDisplay}";
  font-weight: ${weightDisplay};
}

// ── Energia / barra de usuário ───────────────────────────────────
.tn-power { transition: background-color 0.25s ease; }
.tn-hit:hover .tn-power { background-color: ${critWash}; }

// ── OSD ──────────────────────────────────────────────────────────
.tn-osd {
  min-height: 58px;
  padding: 0px 22px;
  border-radius: 30px;
  background-color: ${osdSurface};
  border: ${borderWidth}px solid ${border};
}
.tn-osd-level { min-width: 296px; }
.tn-osd-muted { min-width: 72px; }
.tn-osd-icon {
  font-family: "${fontIcon}";
  font-size: ${iconMd}px;
}
.tn-osd-icon-volume { color: ${accent}; }
.tn-osd-icon-brightness { color: ${warn}; }
.tn-osd-icon-muted { color: ${crit}; }
.tn-osd-meter { min-width: 214px; }
.tn-osd-progress trough {
  min-width: 214px;
  min-height: 6px;
  border-radius: 999px;
  background-color: ${track};
}
.tn-osd-progress progress { min-height: 6px; border-radius: 999px; }
.tn-osd-progress-volume progress { background-color: ${accent}; }
.tn-osd-progress-brightness progress { background-color: ${warn}; }
.tn-osd-value {
  min-width: 28px;
  font-family: "${fontUi}";
  font-size: ${sizeLabel}px;
  color: ${text};
}
]]

function M.generate()
    local c, g, f = T.color, T.geometry, T.font
    return fmt(SHEET, {
        themeName    = c.theme,
        surfaceMode  = T.surfaceMode,

        fontUi       = f.ui,
        fontIcon     = f.icon,
        fontDisplay  = f.display,
        weightUi     = f.weight.ui,
        weightDisplay = f.weight.display,
        weightMedium = f.weight.medium,
        weightBold   = f.weight.bold,
        sizeClock    = f.size.clock,
        sizeBody     = f.size.body,
        sizeLabel    = f.size.label,
        iconLg       = f.size.iconLg,
        iconMd       = f.size.iconMd,
        iconSm       = f.size.iconSm,

        barHeight    = g.barHeight,
        -- O GTK soma a borda por fora do min-height; o kit conta a
        -- ilha inteira em 40px, então a borda sai daqui.
        islandInner  = g.barHeight - 2 * g.borderWidth,
        barMargin    = g.barMargin,
        radiusChip   = g.radiusChip,
        radiusInner  = g.radiusInner,
        borderWidth  = g.borderWidth,
        chipMin      = g.chipMin,
        chipMinWide  = g.chipMinWide,
        padIsland    = g.gap.xl,
        padWsRight   = g.gap.sm,
        padClock     = g.gap.pad,
        padTray      = 12,

        base         = c.base,
        text         = c.text,
        subtle       = c.subtle,
        muted        = c.muted,
        accent       = c.accent,
        island       = T.surface.island,
        islandHover  = T.rgba(c.text, 0.06),
        border       = T.surface.border,
        divider      = T.surface.divider,
        chip         = T.surface.chip,
        accentGlow   = T.rgba(c.accent, 0.55),
        critWash     = T.rgba(T.role.crit, 0.16),
        osdSurface   = T.rgba(c.base, 0.94),
        track        = T.surface.track,
        dim          = T.role.dim,
        cpu          = T.role.cpu,
        ram          = T.role.ram,
        temp         = T.role.temp,
        ok           = T.role.ok,
        warn         = T.role.warn,
        crit         = T.role.crit,
    })
end

return M
