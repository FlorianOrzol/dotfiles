-- ==============================================================================
-- @meta_name        : vd/query.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Read-only questions about monitors and virtual desktops.
-- @desc_detailed    : All answers are derived from the live compositor state, so
-- @desc_detailed    : the engine never keeps a second, drifting copy of what
-- @desc_detailed    : Hyprland already knows.
--
-- @req_modules      : vd.config, vd.state
-- @exports          : monitor_of_role, role_of_monitor, focused_role,
-- @exports          : shows_shared, current_desktop, active_desktops,
-- @exports          : workspaces_of_desktop, next_free_desktop
--
-- @notes            : A desktop counts as active when at least one of its
-- @notes            : workspaces holds a window. The desktop the user is on is
-- @notes            : always active, even while it is still empty.
-- @notes            : The hidden desktop never shows up in any listing — it is
-- @notes            : reachable through its own keybind only.
-- ==============================================================================

local config = require("vd.config")
local state  = require("vd.state")

local M = {}

-- ==============================================================================
-- --- Monitors ---
-- ==============================================================================

-- --- monitor_of_role ---
-- @desc_short       : Resolves a role to the monitor object currently holding it.
-- @usage            : monitor_of_role("main")
-- @parameter        : name_role | string | Role name.
-- @returns          : HL.Monitor|nil | nil when the output is not connected.
-- ==============================================================================
function M.monitor_of_role(name_role)
    local name_output = config.OUTPUT_BY_ROLE[name_role]

    if not name_output then
        return nil
    end

    -- Resolved on every call so hot-plugged monitors are picked up immediately.
    return hl.get_monitor(name_output)
end

-- --- role_of_monitor ---
-- @desc_short       : Returns the role a monitor plays, if any.
-- @usage            : role_of_monitor(hl.get_active_monitor())
-- @parameter        : monitor | HL.Monitor|nil | Monitor object.
-- @returns          : string|nil | Role name, or nil for the info monitor.
-- ==============================================================================
function M.role_of_monitor(monitor)
    if not monitor then
        return nil
    end

    return config.role_of_output(monitor.name)
end

-- --- focused_role ---
-- @desc_short       : Returns the role of the currently focused monitor.
-- @usage            : focused_role()
-- @returns          : string|nil | nil when the info monitor is focused.
-- ==============================================================================
function M.focused_role()
    return M.role_of_monitor(hl.get_active_monitor())
end

-- --- shows_shared ---
-- @desc_short       : Tests whether a monitor currently shows a shared workspace.
-- @usage            : shows_shared(monitor)
-- @parameter        : monitor | HL.Monitor|nil | Monitor object.
-- @returns          : boolean
-- ==============================================================================
function M.shows_shared(monitor)
    if not monitor or not monitor.active_workspace then
        return false
    end

    return config.is_shared_workspace(monitor.active_workspace.id)
end

-- ==============================================================================
-- --- Desktops ---
-- ==============================================================================

-- --- current_desktop ---
-- @desc_short       : Determines which virtual desktop is on screen right now.
-- @usage            : current_desktop()
-- @returns          : integer|nil | Desktop number, or nil if none is set up.
-- ==============================================================================
function M.current_desktop()
    -- Preferred source: the workspace shown on the focused monitor.
    local workspace_active = hl.get_active_workspace()
    if workspace_active then
        local id_vd = config.decode(workspace_active.id)
        if id_vd then
            return id_vd
        end
    end

    -- The info monitor may be focused, so fall back to any role monitor.
    for _, name_role in ipairs(config.ROLES) do
        local monitor = M.monitor_of_role(name_role)
        if monitor and monitor.active_workspace then
            local id_vd = config.decode(monitor.active_workspace.id)
            if id_vd then
                return id_vd
            end
        end
    end

    -- Last resort: whatever the engine recorded during the previous switch.
    return state.get_current()
end

-- --- active_desktops ---
-- @desc_short       : Lists every desktop that holds at least one window.
-- @usage            : active_desktops()
-- @returns          : integer[] | Ascending desktop numbers, hidden one excluded.
-- ==============================================================================
function M.active_desktops()
    local is_active = {}

    -- A desktop stays alive as long as any of its workspaces holds a window.
    -- Shared workspaces decode to nil and therefore never keep a desktop alive.
    for _, workspace in ipairs(hl.get_workspaces()) do
        local id_vd = config.decode(workspace.id)
        if id_vd and workspace.windows > 0 then
            is_active[id_vd] = true
        end
    end

    -- Keep the desktop the user is on, even while it is still empty.
    local id_current = M.current_desktop()
    if id_current then
        is_active[id_current] = true
    end

    -- The hidden desktop stays out of every listing, even while standing on it.
    is_active[config.ID_VD_HIDDEN] = nil

    local ids_active = {}
    for id_vd in pairs(is_active) do
        ids_active[#ids_active + 1] = id_vd
    end

    -- Sorted output makes "next" and "previous" behave predictably.
    table.sort(ids_active)
    return ids_active
end

-- --- workspaces_of_desktop ---
-- @desc_short       : Collects the existing workspaces of one desktop.
-- @usage            : workspaces_of_desktop(11)
-- @parameter        : id_vd | integer | Virtual desktop number.
-- @returns          : HL.Workspace[] | Possibly empty list.
-- ==============================================================================
function M.workspaces_of_desktop(id_vd)
    local workspaces_found = {}

    for _, workspace in ipairs(hl.get_workspaces()) do
        -- Compare the decoded desktop rather than the raw ID prefix.
        if config.decode(workspace.id) == id_vd then
            workspaces_found[#workspaces_found + 1] = workspace
        end
    end

    return workspaces_found
end

-- --- next_free_desktop ---
-- @desc_short       : Returns the lowest desktop number that is not in use.
-- @usage            : next_free_desktop()
-- @returns          : integer|nil | nil when all desktop numbers are taken.
-- ==============================================================================
function M.next_free_desktop()
    local is_taken = {}

    -- Every active desktop blocks its number.
    for _, id_vd in ipairs(M.active_desktops()) do
        is_taken[id_vd] = true
    end

    for id_vd = config.ID_VD_MIN, config.ID_VD_MAX do
        if not is_taken[id_vd] then
            return id_vd
        end
    end

    return nil
end

return M
