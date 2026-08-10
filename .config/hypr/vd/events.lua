-- ==============================================================================
-- @meta_name        : vd/events.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Keeps the engine state in sync with the compositor.
-- @desc_detailed    : Subscribes to the Hyprland events that can change which
-- @desc_detailed    : workspace a monitor shows or which desktops still exist,
-- @desc_detailed    : so the state stays correct even when workspaces are
-- @desc_detailed    : changed by something other than these keybinds.
--
-- @req_modules      : vd.config, vd.state, vd.query
-- @exports          : register, restore_current_desktop
--
-- @notes            : The callbacks deliberately ignore their arguments and
-- @notes            : re-read the compositor instead — that keeps them correct
-- @notes            : regardless of how many values an event delivers.
-- ==============================================================================

local config = require("vd.config")
local state  = require("vd.state")
local query  = require("vd.query")

local M = {}

-- Forward declarations; both handlers live in the support section below.
local sync_slots
local drop_dead_desktops

-- ==============================================================================
-- --- Public API ---
-- ==============================================================================

-- --- register ---
-- @desc_short       : Installs all event subscriptions of the engine.
-- @usage            : register()
-- ==============================================================================
function M.register()
    -- Any workspace change on any monitor updates the remembered slots.
    hl.on("workspace.active", sync_slots)
    hl.on("window.move_to_workspace", sync_slots)

    -- Hyprland drops empty workspaces; a desktop can die with the last one.
    hl.on("workspace.removed", drop_dead_desktops)
    hl.on("window.destroy", drop_dead_desktops)

    -- A monitor that appears has to be put onto the current desktop.
    hl.on("monitor.added", M.restore_current_desktop)
    hl.on("monitor.layout_changed", M.restore_current_desktop)
end

-- --- restore_current_desktop ---
-- @desc_short       : Re-applies the current desktop to all role monitors.
-- @usage            : restore_current_desktop()
-- ==============================================================================
function M.restore_current_desktop()
    local id_current = query.current_desktop()

    -- Without a known desktop there is nothing sensible to restore.
    if not id_current then
        return
    end

    -- Loaded here rather than at the top: only this handler needs it, and it
    -- keeps the dependency direction of the engine one-way.
    require("vd.desktop").switch(id_current)
end

-- ==============================================================================
-- --- Support Functions ---
-- ==============================================================================

-- --- sync_slots ---
-- @desc_short       : Copies the visible workspace of every role into the state.
-- @usage            : sync_slots()
-- ==============================================================================
function sync_slots()
    -- Publish afterwards; the status text is built from the values below.
    local status = require("vd.status")

    for _, name_role in ipairs(config.ROLES) do
        local monitor = query.monitor_of_role(name_role)

        if monitor and monitor.active_workspace then
            local id_vd, name_decoded, number_ws = config.decode(monitor.active_workspace.id)

            -- Only workspaces of the VD scheme carry a slot worth remembering.
            if id_vd then
                state.remember_slot(id_vd, name_decoded, number_ws)
            end
        end
    end

    local id_current = query.current_desktop()
    if id_current then
        state.set_current(id_current)
    end

    status.write()
end

-- --- drop_dead_desktops ---
-- @desc_short       : Removes state of desktops that have no workspace left.
-- @usage            : drop_dead_desktops()
-- ==============================================================================
function drop_dead_desktops()
    local has_workspace = {}

    -- Collect the desktops the compositor still knows about.
    for _, workspace in ipairs(hl.get_workspaces()) do
        local id_vd = config.decode(workspace.id)
        if id_vd then
            has_workspace[id_vd] = true
        end
    end

    -- The desktop the user stands on stays alive even without workspaces: with
    -- every monitor parked on a shared slot its own workspaces run empty and
    -- Hyprland deletes them, yet that desktop is still the current one.
    local id_current = state.get_current()
    if id_current then
        has_workspace[id_current] = true
    end

    -- Everything the engine remembers beyond that is stale and gets dropped.
    for _, id_vd in ipairs(state.known_desktops()) do
        if not has_workspace[id_vd] then
            state.forget_desktop(id_vd)
        end
    end
end

return M
