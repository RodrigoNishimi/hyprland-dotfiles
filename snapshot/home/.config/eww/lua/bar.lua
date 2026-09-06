-- ==================================================================
-- A barra do "Hyprland Rice Kit" (seção 02 — ilhas flutuantes, 40px,
-- margem 14px) descrita em Lua e emitida como yuck.
--
-- Tudo que é dado (workspaces, wifi, bateria, volume, bluetooth,
-- coretemp) continua vindo das mesmas vars e scripts que a barra
-- antiga usava; aqui só muda a forma.
-- ==================================================================
local T = require("tokens")
local Y = require("yuck")

local node, raw, widget = Y.node, Y.raw, Y.widget
local ico, geo, gap = T.icon, T.geometry, T.geometry.gap

local M = {}

-- Cadeia ternária em yuck a partir de uma lista {condição, valor}.
-- O último par entra como `else`, com a condição ignorada.
local function ternary(branches)
    local parts = {}
    for i = 1, #branches - 1 do
        parts[#parts + 1] = ("%s ? %s"):format(branches[i][1], branches[i][2])
    end
    parts[#parts + 1] = branches[#branches][2]
    return table.concat(parts, " : ")
end

local function quoted(s) return '"' .. s .. '"' end

-- ── Peças ─────────────────────────────────────────────────────────

local function separator()
    return node("box", { "class", "tn-sep", "valign", "center" })
end

local function icon(glyph, class)
    return node("label", { "class", "tn-ico " .. class, "text", glyph })
end

-- O GTK3 não aplica min-width/min-height a um eventbox: ele não desenha
-- por gadget, então só o fundo e o raio chegam nele. Toda ilha clicável
-- vira, então, um eventbox de área de clique com uma box por dentro,
-- que é quem recebe as classes de desenho.
local function clickable(onclick, boxClass, extraAttrs, ...)
    local hit = { "class", "tn-hit", "cursor", "pointer", "timeout", "3s" }
    for _, v in ipairs(extraAttrs or {}) do hit[#hit + 1] = v end
    hit[#hit + 1] = "onclick"; hit[#hit + 1] = onclick
    return node("eventbox", hit, node("box", boxClass, ...))
end

-- ── Ilha: workspaces ──────────────────────────────────────────────
-- workspaces-output é montado por scripts/workspace.sh, que escuta o
-- socket2 do Hyprland. O script emite os chips já com as classes.

local function workspaces()
    return widget("tn-workspaces", {},
        node("box", { "class", "tn-island tn-island-ws", "orientation", "h",
                      "space-evenly", raw("false"), "spacing", raw(gap.sm) },
            node("literal", { "valign", "center", "content", raw("workspaces-output") })))
end

-- ── Ilha: janela em foco ──────────────────────────────────────────

local function window()
    return widget("tn-window", {},
        node("revealer", { "transition", "slideright", "duration", "250ms",
                           "reveal", raw('{tn_window != ""}') },
            node("box", { "class", "tn-island tn-island-window", "orientation", "h",
                          "space-evenly", raw("false"), "spacing", raw(gap.md) },
                icon(ico.terminal, "tn-ico-sm tn-ico-muted"),
                node("label", { "class", "tn-window-title", "limit-width", raw(42),
                                "tooltip", raw("tn_window"), "show-truncated", raw("true"), "text", raw("tn_window") }))))
end

-- ── Ilha: relógio ─────────────────────────────────────────────────

local function clock()
    return widget("tn-clock", {},
        clickable("./scripts/calendar.sh",
            { "class", "tn-island tn-island-clock", "orientation", "h",
              "space-evenly", raw("false"), "spacing", raw(gap.lg) }, nil,
            node("label", { "class", "tn-clock-time", "text", raw("tn_clock") }),
            separator(),
            node("label", { "class", "tn-clock-date", "text", raw("tn_date") })))
end

-- ── Ilha: cpu / ram / temperatura ─────────────────────────────────

local function stat()
    return widget("tn-stat", { "icon", "tone", "value" },
        node("box", { "class", "tn-stat", "orientation", "h",
                      "space-evenly", raw("false"), "spacing", raw(6) },
            node("label", { "class", raw('"tn-ico tn-ico-sm ${tone}"'), "text", raw("icon") }),
            node("label", { "class", "tn-stat-value", "text", raw("value") })))
end

local function sysinfo()
    return widget("tn-sysinfo", {},
        node("box", { "class", "tn-island", "orientation", "h",
                      "space-evenly", raw("false"), "spacing", raw(gap.lg) },
            node("tn-stat", { "icon", ico.memory,     "tone", "tn-ico-cpu",
                              "value", raw('"${round(EWW_CPU.avg,0)}%"') }),
            node("tn-stat", { "icon", ico.memoryAlt,  "tone", "tn-ico-ram",
                              "value", raw('"${round(EWW_RAM.used_mem_perc,0)}%"') }),
            node("tn-stat", { "icon", ico.thermostat, "tone", "tn-ico-temp",
                              "value", raw('"${coretemp.package}°"') })))
end

-- ── Ilha: bluetooth / wifi / volume ───────────────────────────────
-- Os três abrem os mesmos painéis de antes: o wifi tem o dele
-- (wifictl), bluetooth e volume moram na barra de usuário (usrctl).

local OPEN_USRCTL = "./scripts/usrctl.sh"
local OPEN_WIFI   = "./scripts/wifictl.sh"

local function connectivity()
    local btIcon = ternary({
        { "bluetooth.powered && bluetooth.count > 0", quoted(ico.bluetoothOn) },
        { "bluetooth.powered",                        quoted(ico.bluetooth) },
        { nil,                                        quoted(ico.bluetoothOff) },
    })
    local btTone = ternary({
        { "bluetooth.powered", quoted("tn-ico-accent") },
        { nil,                 quoted("tn-ico-muted") },
    })
    local wifiOn   = 'wifistatus.ssid != "Disconnected"'
    local wifiIcon = ternary({
        { wifiOn, quoted(ico.wifi) },
        { nil,    quoted(ico.wifiOff) },
    })
    local volIcon = ternary({
        { "tn_volmute",   quoted(ico.volumeOff) },
        { "get_vol < 40", quoted(ico.volumeDown) },
        { nil,            quoted(ico.volumeUp) },
    })

    return widget("tn-conn", {},
        node("box", { "class", "tn-island", "orientation", "h",
                      "space-evenly", raw("false"), "spacing", raw(gap.lg) },
            node("eventbox", { "timeout", "3s", "class", "tn-hit", "cursor", "pointer",
                               "tooltip", raw('"Bluetooth: ${bluetooth.label} — clique para ligar/desligar"'),
                               "onclick", "setsid -f ./scripts/bluetooth.sh toggle" },
                node("label", { "class", raw(('"tn-ico ${%s}"'):format(btTone)),
                                "text", raw("{" .. btIcon .. "}") })),
            node("eventbox", { "timeout", "3s", "class", "tn-hit", "cursor", "pointer",
                               "tooltip", raw('"${wifistatus.ssid}"'), "onclick", raw(quoted(OPEN_WIFI)) },
                node("box", { "orientation", "h", "space-evenly", raw("false"),
                              "spacing", raw(6) },
                    node("label", { "class", raw(('"tn-ico ${%s ? "tn-ico-subtle" : "tn-ico-muted"}"'):format(wifiOn)),
                                    "text", raw("{" .. wifiIcon .. "}") }),
                    node("label", { "class", "tn-stat-value", "limit-width", raw(7),
                                    "show-truncated", raw("false"),
                                    "text", raw(('{%s ? wifistatus.ssid : "off"}'):format(wifiOn)) }))),
            node("eventbox", { "timeout", "3s", "class", "tn-hit", "cursor", "pointer",
                               "onscroll", "[ {} = up ] && pamixer -i 2 || pamixer -d 2",
                               "tooltip", "Clique para mutar/desmutar; role para ajustar",
                               "onmiddleclick", OPEN_USRCTL,
                               "onclick", "pamixer -t" },
                node("box", { "orientation", "h", "space-evenly", raw("false"),
                              "spacing", raw(6) },
                    node("label", { "class", raw('"tn-ico ${tn_volmute ? "tn-ico-muted" : "tn-ico-subtle"}"'),
                                    "text", raw("{" .. volIcon .. "}") })))))
end

-- ── Ilha: bateria ─────────────────────────────────────────────────

local function battery()
    -- Os sete níveis do Material Symbols distribuídos na carga.
    local steps = { 95, 80, 60, 45, 30, 15 }
    local branches = { { "tn_bat.charging", quoted(ico.batteryCharging) } }
    for i, floor in ipairs(steps) do
        branches[#branches + 1] = {
            ("tn_bat.cap >= %d"):format(floor),
            quoted(ico.battery[#ico.battery - i + 1]),
        }
    end
    branches[#branches + 1] = { nil, quoted(ico.battery[1]) }

    local tone = ternary({
        { "tn_bat.charging",  quoted("tn-ico-ok") },
        { "tn_bat.cap <= 15", quoted("tn-ico-crit") },
        { "tn_bat.cap <= 30", quoted("tn-ico-warn") },
        { nil,                quoted("tn-ico-ok") },
    })

    return widget("tn-battery", {},
        node("box", { "class", "tn-island", "visible", raw("{tn_bat.present}"), "orientation", "h",
                      "space-evenly", raw("false"), "spacing", raw(gap.sm) },
            node("label", { "class", raw(('"tn-ico ${%s}"'):format(tone)),
                            "text", raw("{" .. ternary(branches) .. "}") }),
            node("label", { "class", "tn-stat-value", "text", raw('"${tn_bat.cap}%"') })))
end

-- ── Bandeja ───────────────────────────────────────────────────────
-- O kit não desenha bandeja; ela fica como ilha que se abre, para não
-- perder o que a barra antiga já mostrava.

local function tray()
    return widget("tn-tray", {},
        node("box", { "orientation", "h", "space-evenly", raw("false"),
                      "spacing", raw(gap.md) },
            node("revealer", { "transition", "slideleft", "duration", "250ms",
                               "reveal", raw("trayrev") },
                node("box", { "class", "tn-island tn-island-tray" },
                    node("systray", { "space-evenly", raw("true"), "icon-size", raw(16),
                                      "prepend-new", raw("true") }))),
            clickable(raw('"${trayrev ? "/usr/bin/eww update trayrev=false" : "/usr/bin/eww update trayrev=true"}"'),
                { "class", "tn-island tn-island-square tn-tray-toggle" }, nil,
                node("label", { "class", "tn-ico tn-ico-sm tn-ico-muted",
                                "text", raw(("{trayrev ? %s : %s}"):format(
                                    quoted(ico.chevronRight), quoted(ico.chevronLeft))) }))))
end

-- ── Notificações ─────────────────────────────────────────────────

local function notifications()
    return widget("tn-notifications", {},
        clickable(OPEN_USRCTL,
            { "class", raw('"tn-island tn-island-notifications ${notifications.count > 0 ? "tn-notifications-with-count" : "tn-notifications-icon-only"}"'),
              "space-evenly", raw("false") },
            { "tooltip", raw('"${notifications.dnd ? "Não perturbe ativo" : notifications.count > 0 ? "${notifications.count} notificações" : "Sem notificações"}"'),
              "onrightclick", "./scripts/notifications.sh toggle-dnd" },
            node("label", { "class", raw('"tn-ico ${notifications.dnd ? "tn-ico-muted" : "tn-ico-subtle"}"'),
                            "hexpand", raw("{notifications.count == 0}"),
                            "halign", "center", "xalign", raw(0.5),
                            "text", raw(("{notifications.dnd ? %s : %s}"):format(
                                quoted(ico.notificationsOff), quoted(ico.notifications))) }),
            node("revealer", { "transition", "slideright", "duration", "200ms",
                               "reveal", raw("{notifications.count > 0}") },
                node("label", { "class", "tn-notification-count",
                                "text", raw('"${notifications.count}"') }))))
end

-- ── Botão de energia ──────────────────────────────────────────────
-- panel.sh fecha os outros painéis antes de abrir a barra de usuário.

local function power()
    return widget("tn-power", {},
        clickable(OPEN_USRCTL,
            { "class", "tn-island tn-island-square tn-power" },
            { "tooltip", " barra de usuário " },
            node("label", { "class", "tn-ico tn-ico-lg tn-ico-arch tn-ico-accent",
                            "halign", "center", "valign", "center",
                            "xalign", raw(0.5), "yalign", raw(0.5), "text", ico.arch })))
end

-- ── OSD de volume / brilho ──────────────────────────────────────

local function osd()
    return widget("tn-osd", {},
        node("box", { "class", raw('"tn-osd ${osd_muted ? "tn-osd-muted" : "tn-osd-level"}"'),
                      "orientation", "h", "space-evenly", raw("false"),
                      "spacing", raw(gap.lg), "valign", "center" },
            node("label", { "class", raw('"tn-osd-icon ${osd_muted ? "tn-osd-icon-muted" : osd_kind == "brightness" ? "tn-osd-icon-brightness" : "tn-osd-icon-volume"}"'),
                            "text", raw(("{osd_muted ? %s : osd_kind == \"brightness\" ? %s : %s}"):format(
                                quoted(ico.volumeOff), quoted(ico.brightness), quoted(ico.volumeUp))) }),
            node("box", { "class", "tn-osd-meter", "visible", raw("{!osd_muted}"),
                          "orientation", "h", "space-evenly", raw("false"),
                          "valign", "center" },
                node("progress", { "class", raw('"tn-osd-progress ${osd_kind == "brightness" ? "tn-osd-progress-brightness" : "tn-osd-progress-volume"}"'),
                                   "value", raw("osd_value"), "valign", "center" })),
            node("label", { "class", "tn-osd-value", "text", raw("osd_label") })))
end

-- ── A barra ───────────────────────────────────────────────────────

local function root()
    local function cluster(align, spacing, ...)
        local attrs = { "class", "tn-cluster", "halign", align, "valign", "center",
                        "hexpand", raw("false"), "space-evenly", raw("false") }
        if spacing then
            attrs[#attrs + 1] = "spacing"; attrs[#attrs + 1] = raw(spacing)
        end
        return node("box", attrs, ...)
    end

    return widget("bar", {},
        node("centerbox", { "class", "tn-bar", "orientation", "h" },
            cluster("start", gap.md,
                node("tn-workspaces", {}),
                node("tn-window", {}),
                node("tn-notifications", {})),
            cluster("center", nil,
                node("tn-clock", {})),
            cluster("end", gap.md,
                node("tn-tray", {}),
                node("tn-sysinfo", {}),
                node("tn-conn", {}),
                node("tn-battery", {}),
                node("tn-power", {}))))
end

-- ── Fontes de dados novas ─────────────────────────────────────────

-- Estado inicial dos chips, antes de scripts/workspace.sh acordar.
local function initialWorkspaces()
    local chips = {}
    for i = 1, 6 do
        local cls = (i == 1) and "tn-ws-chip tn-ws-active" or "tn-ws-chip tn-ws-free"
        chips[#chips + 1] = ('(eventbox :onclick \\"./scripts/switch-workspace.sh %d\\" '
            .. ':cursor \\"pointer\\" :class \\"tn-hit\\" '
            .. '(box :valign \\"center\\" :class \\"%s\\" (label :yalign 0.5 :text \\"%d\\")))'):format(i, cls, i)
    end
    return '(box :class \\"tn-ws\\" :valign \\"center\\" :orientation \\"h\\" :spacing '
        .. gap.xs .. ' :space-evenly \\"false\\" ' .. table.concat(chips, " ") .. ')'
end

local function sources()
    return ([[
;; ── Fontes de dados da barra ──────────────────────────────────────
;; workspaces-output escuta scripts/workspace.sh; trayrev,
;; ctlrev, wifictlrev, wifistatus, bluetooth, coretemp e get_vol
;; continuam definidos em eww.yuck.

(defpoll tn_clock    :interval "5s"  :initial ""      "date +%%H:%%M")
(defpoll tn_date     :interval "60s" :initial ""      "./scripts/bardate.sh")
(defpoll tn_volmute  :interval "1s"  :initial "false" "./scripts/muted.sh")
(defpoll tn_bat      :interval "10s" :initial "{\"cap\":0,\"charging\":false,\"present\":false}"
                     "./scripts/batstate.sh")
(deflisten tn_window :initial ""     "./scripts/window.sh")

(deflisten workspaces-output :initial "%s" "./scripts/workspace.sh")

(defvar osd_kind "volume")
(defvar osd_value 0)
(defvar osd_muted false)
(defvar osd_label "0")
]]):format(initialWorkspaces())
end

local function osdWindow()
    return [[
(defwindow osd
    :monitor 0
    :namespace "eww-osd"
    :stacking "overlay"
    :focusable false
    :geometry (geometry :anchor "bottom center" :y "54px")
    (tn-osd))
]]
end

-- ── Janela ────────────────────────────────────────────────────────
-- A janela é só a moldura: fundo transparente, altura da ilha mais a
-- margem de cima. `exclusive` reserva exatamente isso, e o gaps_out
-- do Hyprland (conf/rice.lua) devolve a mesma margem embaixo.

local function window_()
    return ([[
(defwindow bar_widget
    :monitor 0
    :stacking "fg"
    :focusable false
    :exclusive true
    :geometry (geometry :anchor "top center" :width "100%%" :height "%dpx")
    (bar))
]]):format(geo.barMargin + geo.barHeight)
end


function M.generate()
    local out = {
        ";; ==================================================================",
        ";; GERADO por lua/build.lua a partir de lua/tokens.lua + lua/bar.lua.",
        ";; NÃO EDITE — rode `lua ~/.config/eww/lua/build.lua`.",
        ";;",
        ";; Barra do \"Hyprland Rice Kit\", seção 02: ilhas flutuantes de "
            .. geo.barHeight .. "px",
        ";; com margem de " .. geo.barMargin .. "px.",
        ";; ==================================================================",
        "",
        sources(),
        workspaces(), "",
        window(), "",
        clock(), "",
        stat(), "",
        sysinfo(), "",
        connectivity(), "",
        battery(), "",
        tray(), "",
        notifications(), "",
        power(), "",
        osd(), "",
        root(), "",
        window_(),
        osdWindow(),
    }
    return table.concat(out, "\n")
end

return M
