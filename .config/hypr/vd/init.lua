-- ==============================================================================
-- @meta_name        : vd/init.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 2.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : Public API of the virtual-desktop engine.
-- @desc_detailed    : Bundles the submodules into one flat table that keybinds
-- @desc_detailed    : and external scripts talk to. Exported globally as "VD",
-- @desc_detailed    : so shell scripts can drive it via:
-- @desc_detailed    :   hyprctl eval 'VD.create("gaming")'
--
-- @req_modules      : vd.config, vd.state, vd.query, vd.desktop, vd.workspace,
-- @req_modules      : vd.label, vd.events, vd.dispatch, vd.render, vd.status
-- @exports          : VD (global), M (module table, same content)
-- ==============================================================================

local config    = require("vd.config")
local state     = require("vd.state")
local query     = require("vd.query")
local desktop   = require("vd.desktop")
local workspace = require("vd.workspace")
local label     = require("vd.label")
local events    = require("vd.events")
local dispatch  = require("vd.dispatch")
local render    = require("vd.render")
local status    = require("vd.status")

-- ==============================================================================
-- --- Module Internals ---
-- ==============================================================================

-- How long the overview notification of VD.show stays on screen, in ms.
local TIMEOUT_SHOW = 4000

local M = {}

-- ==============================================================================
-- --- Desktop Actions ---
-- ==============================================================================

-- Show desktop <id_vd> on every role monitor.
M.switch = desktop.switch

-- Step through the ring of active desktops (1 = next, -1 = previous).
M.cycle = desktop.cycle

-- Jump to the hidden desktop, or back to the one you came from.
M.toggle_hidden = desktop.toggle_hidden

-- Open the lowest unused desktop, optionally labelled.
M.create = desktop.create

-- Open the lowest unused desktop and take the active window along.
M.create_with_window = desktop.create_with_window

-- Move the active window to desktop <id_vd> and follow it.
M.move_window_to = desktop.move_window_to

-- Move the active window to the next/previous active desktop and follow it.
M.move_window_cycle = desktop.move_window_cycle

-- ==============================================================================
-- --- Slot Actions (on the focused monitor) ---
-- ==============================================================================

-- Show slot <number_ws>; slots above COUNT_WS_PER_ROLE are the shared ones.
M.ws_switch = workspace.switch

-- Step through the slots of the focused monitor (1 = next, -1 = previous).
M.ws_cycle = workspace.cycle

-- Move the active window to slot <number_ws> and follow it.
M.ws_move_window_to = workspace.move_window_to

-- Move the active window one slot forward/backward and follow it.
M.ws_move_window_cycle = workspace.move_window_cycle

-- ==============================================================================
-- --- Introspection and Metadata ---
-- ==============================================================================

-- --- label ---
-- @desc_short       : Reads or writes the label of a desktop.
-- @usage            : label(12) / label(12, "gaming")
-- @parameter        : id_vd      | integer    | Virtual desktop number.
-- @parameter        : name_label | string|nil | Omit to read, pass to write.
-- @returns          : string|nil | The label after the call.
-- ==============================================================================
function M.label(id_vd, name_label)
    -- A second argument means "write"; its absence means "read".
    if name_label ~= nil then
        label.set(id_vd, name_label)
    end

    return state.get_label(id_vd)
end

-- --- current ---
-- @desc_short       : Returns the desktop currently on screen.
-- @usage            : current()
-- @returns          : integer|nil
-- ==============================================================================
function M.current()
    return query.current_desktop()
end

-- --- list ---
-- @desc_short       : Renders all active desktops, one line each.
-- @usage            : hyprctl eval 'return VD.list()'
-- @returns          : string | "*12 gaming  main:2 left:1 center:S right:1"
-- ==============================================================================
M.list = render.list

-- Path of the status file external displays read; see vd/status.lua.
M.FILE_STATUS = status.FILE_STATUS

-- --- show ---
-- @desc_short       : Puts the desktop list on screen as a notification.
-- @usage            : show()
-- @notes            : hyprctl eval always answers "ok" and never returns the
-- @notes            : value, so this is how the list actually becomes visible.
-- ==============================================================================
function M.show()
    local text = M.list()

    -- An empty list would produce an invisible notification.
    if text == "" then
        text = "no active virtual desktop"
    end

    dispatch.notify(text, TIMEOUT_SHOW)
end

-- ==============================================================================
-- --- Lifecycle ---
-- ==============================================================================

-- --- setup ---
-- @desc_short       : Registers the event handlers and opens the first desktop.
-- @usage            : setup()
-- ==============================================================================
function M.setup()
    events.register()

    -- Give the hidden desktop a name of its own; it is never listed anyway.
    label.set(config.ID_VD_HIDDEN, "hidden")

    -- Start on the lowest desktop number so the session always looks the same.
    -- Forced, because at this point the monitors may sit on whatever workspace
    -- Hyprland handed them, including a shared one.
    desktop.switch(config.ID_VD_MIN, true)

    -- Publish once, so a display started later already finds a valid file.
    status.write()
end

-- Exported globally so external scripts can reach the engine via hyprctl eval.
VD = M

return M
