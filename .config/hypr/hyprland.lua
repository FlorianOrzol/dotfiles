-- ==============================================================================
-- @usage            : loaded automatically by Hyprland (>= 0.56) at startup
--
-- @meta_name        : hyprland.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Entry point of the Hyprland configuration.
-- @desc_detailed    : Loads the configuration modules in a fixed order and the
-- @desc_detailed    : virtual-desktop engine below vd/. Nothing is configured
-- @desc_detailed    : here directly — this file only wires the modules together.
--
-- @req_modules      : conf.monitors, conf.look, conf.animations, conf.input,
-- @req_modules      : conf.rules, conf.binds, conf.autostart
--
-- @notes            : A Lua error during config load puts Hyprland into
-- @notes            : emergency mode, where only SUPER + Q remains bound. Every
-- @notes            : module is therefore loaded through pcall, and a failure is
-- @notes            : reported on screen instead of taking the session down.
-- @notes            : Presence of this file switches Hyprland from the legacy
-- @notes            : hyprland.conf to the Lua config manager. Rename it to fall
-- @notes            : back:  mv hyprland.lua hyprland.lua.off
-- ==============================================================================

-- ==============================================================================
-- --- Script Internals ---
-- ==============================================================================

-- Modules in load order: settings first, then rules, then binds and autostart.
local MODULES = {
    "conf.monitors",
    "conf.look",
    "conf.animations",
    "conf.input",
    "conf.rules",
    "conf.binds",
    "conf.autostart",
}

-- Collected load errors, reported after all modules have been tried.
local errors_load = {}

-- ==============================================================================
-- --- Load ---
-- ==============================================================================

for _, name_module in ipairs(MODULES) do
    -- Keep loading the remaining modules even if one of them fails, so a broken
    -- module never costs the whole keyboard.
    local ok_module, error_module = pcall(require, name_module)

    if not ok_module then
        errors_load[#errors_load + 1] = name_module .. ": " .. tostring(error_module)
        print("[config] failed to load " .. name_module .. ": " .. tostring(error_module))
    end
end

-- ==============================================================================
-- --- Report ---
-- ==============================================================================

if #errors_load > 0 then
    -- Emergency fallback so a terminal is always reachable after a bad edit.
    hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))

    hl.on("hyprland.start", function()
        hl.notification.create({
            text     = "hyprland config: " .. #errors_load .. " module(s) failed, see log",
            duration = 10000,
            color    = "rgba(ff4444ff)",
        })
    end)
end
