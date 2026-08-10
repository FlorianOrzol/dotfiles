-- ==============================================================================
-- @meta_name        : conf/binds.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 2.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : All keyboard and mouse bindings.
-- @desc_detailed    : Keeps the layout of the previous hyprland.conf. Bindings
-- @desc_detailed    : that were defined twice there are resolved here:
-- @desc_detailed    :   SUPER + P        was exit AND pseudo  -> pseudo only
-- @desc_detailed    :   SUPER + SHIFT+Esc                     -> exit
-- @desc_detailed    :   SUPER + Tab      was group AND cycle  -> group only
-- @desc_detailed    :   SUPER + F        never fired (case)   -> maximize
--
-- @req_modules      : vd, vd.config
-- ==============================================================================

local vd     = require("vd")
local config = require("vd.config")

-- ==============================================================================
-- --- User Configuration ---
-- ==============================================================================

local MOD         = "SUPER"          -- Main modifier
local MOD_SHIFT   = "SUPER + SHIFT"  -- Same action, but taking the window along
local MOD_ALT     = "SUPER + ALT"    -- Program launchers and hardware controls

local CMD_TERMINAL     = "kitty"
local CMD_FILE_MANAGER = "dolphin"
local CMD_MENU         = "wofi --show drun"
local CMD_BROWSER      = "google-chrome-stable"

-- Highest virtual desktop reachable through the function-key row.
local COUNT_DESKTOP_KEYS = 12

-- Desktop number bound to F1; F2 gets the next one, and so on.
local ID_DESKTOP_FIRST_KEY = 11

-- ==============================================================================
-- --- Programs ---
-- ==============================================================================

hl.bind(MOD_ALT .. " + D", hl.dsp.exec_cmd(CMD_MENU))
hl.bind(MOD_ALT .. " + T", hl.dsp.exec_cmd(CMD_TERMINAL))
hl.bind(MOD_ALT .. " + E", hl.dsp.exec_cmd(CMD_FILE_MANAGER))
hl.bind(MOD_ALT .. " + G", hl.dsp.exec_cmd(CMD_BROWSER))

-- ==============================================================================
-- --- Window Management ---
-- ==============================================================================

hl.bind(MOD .. " + Escape",       hl.dsp.window.close())
hl.bind(MOD_SHIFT .. " + Escape", hl.dsp.exit())
hl.bind(MOD .. " + V",            hl.dsp.window.float({ action = "toggle" }))
hl.bind(MOD .. " + P",            hl.dsp.window.pseudo())
hl.bind(MOD .. " + plus",         hl.dsp.layout("togglesplit"))
hl.bind(MOD .. " + M",            hl.dsp.layout("cyclenext"))
hl.bind(MOD .. " + T",            hl.dsp.window.bring_to_top())
hl.bind(MOD .. " + F",            hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Grouping: turn the selection into browser-like tabs and walk through them.
hl.bind(MOD .. " + G",         hl.dsp.group.toggle())
hl.bind(MOD .. " + Tab",       hl.dsp.group.next())
hl.bind(MOD_SHIFT .. " + Tab", hl.dsp.group.prev())

-- Scratchpad.
hl.bind(MOD .. " + S",       hl.dsp.workspace.toggle_special("magic"))
hl.bind(MOD_SHIFT .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- ==============================================================================
-- --- Focus and Window Movement (vim keys) ---
-- Moving across a monitor border is handled by Hyprland itself, see
-- binds.window_direction_monitor_fallback in conf/look.lua.
-- ==============================================================================

local DIRECTION_BY_KEY = { h = "left", l = "right", k = "up", j = "down" }

for key_name, name_direction in pairs(DIRECTION_BY_KEY) do
    hl.bind(MOD .. " + " .. key_name,       hl.dsp.focus({ direction = name_direction }))
    hl.bind(MOD_SHIFT .. " + " .. key_name, hl.dsp.window.move({ direction = name_direction }))
end

-- ==============================================================================
-- --- Virtual Desktops ---
-- A desktop switch moves every role monitor at once. A monitor that currently
-- shows its shared workspace keeps showing it.
-- ==============================================================================

hl.bind(MOD .. " + space",       function() vd.create() end)
hl.bind(MOD_SHIFT .. " + space", function() vd.create_with_window() end)

hl.bind(MOD .. " + right",       function() vd.cycle(1) end)
hl.bind(MOD .. " + left",        function() vd.cycle(-1) end)
hl.bind(MOD_SHIFT .. " + right", function() vd.move_window_cycle(1) end)
hl.bind(MOD_SHIFT .. " + left",  function() vd.move_window_cycle(-1) end)

-- F1..F12 jump straight to desktop 11..22.
for index_key = 1, COUNT_DESKTOP_KEYS do
    local key_name = "F" .. index_key
    local id_vd    = ID_DESKTOP_FIRST_KEY + index_key - 1

    hl.bind(MOD .. " + " .. key_name,       function() vd.switch(id_vd) end)
    hl.bind(MOD_SHIFT .. " + " .. key_name, function() vd.move_window_to(id_vd) end)
end

-- The hidden desktop has no other way in or out: it is never cycled or listed.
hl.bind(MOD_ALT .. " + H", function() vd.toggle_hidden() end)

-- Overview on screen; there is no status bar and hyprctl eval returns no value.
hl.bind(MOD_ALT .. " + I", function() vd.show() end)

-- ==============================================================================
-- --- Slots On The Focused Monitor ---
-- Slots 1..3 belong to the current desktop, slot 4 is the shared one.
-- ==============================================================================

hl.bind(MOD .. " + up",         function() vd.ws_cycle(1) end)
hl.bind(MOD .. " + down",       function() vd.ws_cycle(-1) end)
hl.bind(MOD_SHIFT .. " + up",   function() vd.ws_move_window_cycle(1) end)
hl.bind(MOD_SHIFT .. " + down", function() vd.ws_move_window_cycle(-1) end)

-- Slots 1..COUNT_WS_PER_ROLE belong to the desktop, the rest are shared.
for number_ws = 1, config.count_slots() do
    hl.bind(MOD .. " + " .. number_ws,       function() vd.ws_switch(number_ws) end)
    hl.bind(MOD_SHIFT .. " + " .. number_ws, function() vd.ws_move_window_to(number_ws) end)
end

-- The mouse wheel stays inside the desktop instead of scrolling all workspaces.
hl.bind(MOD .. " + mouse_down", function() vd.ws_cycle(1) end)
hl.bind(MOD .. " + mouse_up",   function() vd.ws_cycle(-1) end)

-- ==============================================================================
-- --- Mouse ---
-- ==============================================================================

hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==============================================================================
-- --- Audio, Brightness and Media Keys ---
-- ==============================================================================

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"),                           { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"),                           { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Same controls without media keys, for keyboards that have none.
hl.bind(MOD_ALT .. " + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(MOD_ALT .. " + N", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind(MOD_ALT .. " + U", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind(MOD_ALT .. " + L", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind(MOD_ALT .. " + B", hl.dsp.exec_cmd("brightnessctl s 10%+"))
hl.bind(MOD_ALT .. " + V", hl.dsp.exec_cmd("brightnessctl s 10%-"))
