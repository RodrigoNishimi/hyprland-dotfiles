-- Hotplug is debounced; the helper also serializes requests and avoids loops
-- when a profile deliberately disables an output.
local helper = 'python3 "$HOME/.config/hypr/scripts/desktop-tools.py"'
local pending
local function apply_monitors(force)
    -- --verify-config emits config.reloaded without a running event loop.
    if not hl.get_active_monitor() then return end
    if pending then pending:set_enabled(false) end
    pending = hl.timer(function()
        hl.exec_cmd(helper .. " monitors apply" .. (force and " --force" or ""))
    end, { timeout = 800, type = "oneshot" })
end

hl.on("monitor.added", function() apply_monitors(false) end)
hl.on("monitor.removed", function() apply_monitors(false) end)
hl.on("config.reloaded", function() apply_monitors(true) end)
hl.on("hyprland.start", function() apply_monitors(true) end)

for _, name in ipairs({ "terminal", "notes", "files" }) do
    hl.window_rule({
        name = "scratch-" .. name,
        match = { class = "^local\\.scratch\\." .. name .. "$" },
        workspace = "special:quick-" .. name .. " silent",
        float = true,
        size = { "monitor_w*0.8", "monitor_h*0.75" },
        center = true,
    })
end
