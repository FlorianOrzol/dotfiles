-- ==============================================================================
-- @meta_name        : vd/desktop.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Switching, creating and cycling of virtual desktops.
-- @desc_detailed    : A virtual desktop is one workspace per role monitor shown
-- @desc_detailed    : at the same time. Switching restores the workspace slot
-- @desc_detailed    : every monitor showed the last time that desktop was used.
--
-- @req_modules      : vd.config, vd.state, vd.query, vd.dispatch, vd.label, vd.render
-- @exports          : switch, cycle, toggle_hidden, create, create_with_window,
-- @exports          : move_window_to, move_window_cycle
--
-- @notes            : A monitor that currently shows its shared workspace is
-- @notes            : skipped during a switch — the shared workspace is the same
-- @notes            : on every desktop, so that monitor simply keeps its view.
-- ==============================================================================

local config   = require("vd.config")
local state    = require("vd.state")
local query    = require("vd.query")
local dispatch = require("vd.dispatch")
local label    = require("vd.label")
local render   = require("vd.render")

local M = {}

-- Forward declaration; the helper is defined in the support section below.
local neighbour_desktop
local role_of_active_window

-- ==============================================================================
-- --- Switching ---
-- ==============================================================================

-- --- switch ---
-- @desc_short       : Shows a virtual desktop on all role monitors at once.
-- @usage            : switch(11) / switch(11, true)
-- @parameter        : id_vd        | integer | Virtual desktop number.
-- @parameter        : force_shared | boolean | true also pulls monitors off
-- @parameter        :              |         | their shared workspace.
-- @returns          : boolean | false when the number is outside the scheme.
-- ==============================================================================
function M.switch(id_vd, force_shared)
    if not config.is_vd_id(id_vd) then
        return false
    end

    -- Remember the focus so switching a desktop does not relocate the cursor.
    local monitor_focused = hl.get_active_monitor()
    local roles_on_shared = {}

    for _, name_role in ipairs(config.ROLES) do
        local monitor = query.monitor_of_role(name_role)

        -- Silently skip roles whose output is currently not connected, and
        -- leave monitors alone that currently show their shared workspace:
        -- that workspace is the same on every desktop, so it simply stays.
        if monitor and (force_shared or not query.shows_shared(monitor)) then
            local number_ws    = state.recall_slot(id_vd, name_role)
            local id_workspace = config.workspace_id(id_vd, name_role, number_ws)
            dispatch.show_workspace(monitor, id_workspace)
        elseif monitor then
            roles_on_shared[#roles_on_shared + 1] = name_role
        end
    end

    -- Always confirm the desktop, and name the monitors that stayed behind —
    -- otherwise it looks like the switch simply did not work on them.
    dispatch.notify_transient(render.desktop_line(id_vd, roles_on_shared))

    state.set_current(id_vd)

    -- Newly created workspaces start with a plain numeric name.
    label.apply(id_vd)

    dispatch.focus_monitor(monitor_focused)

    -- Published here as well: when every monitor stays on its shared workspace
    -- no workspace event fires, yet the current desktop did change.
    require("vd.status").write()

    return true
end

-- --- cycle ---
-- @desc_short       : Switches to the next or previous active desktop.
-- @usage            : cycle(1) / cycle(-1)
-- @parameter        : step | integer | 1 for forward, -1 for backward.
-- @returns          : boolean | false when there is nothing to cycle to.
-- ==============================================================================
function M.cycle(step)
    local id_target = neighbour_desktop(step)

    if not id_target then
        return false
    end

    return M.switch(id_target)
end

-- --- toggle_hidden ---
-- @desc_short       : Jumps to the hidden desktop, or back to where you came from.
-- @usage            : toggle_hidden()
-- @returns          : boolean | Result of the underlying switch.
-- ==============================================================================
function M.toggle_hidden()
    -- Standing on the hidden desktop means the keybind is the way back.
    if config.is_hidden(query.current_desktop()) then
        local id_return = state.get_return() or query.active_desktops()[1] or config.ID_VD_MIN
        return M.switch(id_return)
    end

    -- Remember where to return to before leaving the visible desktops.
    state.set_return(query.current_desktop())
    return M.switch(config.ID_VD_HIDDEN)
end

-- ==============================================================================
-- --- Creating ---
-- ==============================================================================

-- --- create ---
-- @desc_short       : Opens the lowest unused desktop, optionally with a label.
-- @usage            : create("gaming")
-- @parameter        : name_label | string|nil | Label for the new desktop.
-- @returns          : integer|nil | The new desktop number, or nil if all taken.
-- ==============================================================================
function M.create(name_label)
    local id_new = query.next_free_desktop()

    if not id_new then
        dispatch.notify("no free virtual desktop left")
        return nil
    end

    -- Store the label before switching so the first rename already carries it.
    -- The switch itself reports the new desktop, no extra message needed here.
    state.set_label(id_new, name_label)
    M.switch(id_new)

    return id_new
end

-- --- create_with_window ---
-- @desc_short       : Opens a new desktop and takes the active window along.
-- @usage            : create_with_window("gaming")
-- @parameter        : name_label | string|nil | Label for the new desktop.
-- @returns          : integer|nil | The new desktop number.
-- ==============================================================================
function M.create_with_window(name_label)
    local id_new = query.next_free_desktop()

    if not id_new then
        dispatch.notify("no free virtual desktop left")
        return nil
    end

    state.set_label(id_new, name_label)

    -- Move first: afterwards the window already lives on the target desktop,
    -- which keeps that desktop non-empty and therefore active.
    M.move_window_to(id_new)
    return id_new
end

-- ==============================================================================
-- --- Moving Windows Between Desktops ---
-- ==============================================================================

-- --- move_window_to ---
-- @desc_short       : Moves the active window to a desktop and follows it.
-- @usage            : move_window_to(12)
-- @parameter        : id_vd | integer | Target desktop number.
-- @returns          : boolean | false when the number is outside the scheme.
-- ==============================================================================
function M.move_window_to(id_vd)
    if not config.is_vd_id(id_vd) then
        return false
    end

    -- Keep the window on the monitor role it currently occupies.
    local name_role    = role_of_active_window()
    local number_ws    = state.recall_slot(id_vd, name_role)
    local id_workspace = config.workspace_id(id_vd, name_role, number_ws)

    dispatch.move_window_to_workspace(id_workspace)
    return M.switch(id_vd)
end

-- --- move_window_cycle ---
-- @desc_short       : Moves the active window to the next/previous desktop.
-- @usage            : move_window_cycle(1) / move_window_cycle(-1)
-- @parameter        : step | integer | 1 for forward, -1 for backward.
-- @returns          : boolean | false when there is nothing to cycle to.
-- ==============================================================================
function M.move_window_cycle(step)
    local id_target = neighbour_desktop(step)

    if not id_target then
        return false
    end

    return M.move_window_to(id_target)
end

-- ==============================================================================
-- --- Support Functions ---
-- ==============================================================================

-- --- neighbour_desktop ---
-- @desc_short       : Finds the next/previous entry in the active desktop ring.
-- @usage            : neighbour_desktop(1)
-- @parameter        : step | integer | Offset inside the sorted list of desktops.
-- @returns          : integer|nil | Desktop number, or nil when none exists.
-- ==============================================================================
function neighbour_desktop(step)
    local ids_active = query.active_desktops()

    if #ids_active == 0 then
        return nil
    end

    local id_current    = query.current_desktop()
    local index_current = 1

    -- Locate the current desktop; unknown desktops start the ring at its head.
    for index, id_vd in ipairs(ids_active) do
        if id_vd == id_current then
            index_current = index
            break
        end
    end

    -- Wrap around in both directions, using 0-based maths on 1-based indices.
    local index_target = ((index_current - 1 + step) % #ids_active) + 1
    return ids_active[index_target]
end

-- --- role_of_active_window ---
-- @desc_short       : Determines which role the active window currently sits on.
-- @usage            : role_of_active_window()
-- @returns          : string | Role name, defaulting to the first configured role.
-- ==============================================================================
function role_of_active_window()
    local window = hl.get_active_window()

    -- Prefer the workspace of the window itself, it survives focus changes.
    if window and window.workspace then
        local _, name_role = config.decode(window.workspace.id)
        if name_role then
            return name_role
        end
    end

    -- Otherwise use the focused monitor, and the primary role as last resort.
    return query.focused_role() or config.ROLES[1]
end

return M
