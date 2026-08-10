-- ==============================================================================
-- @meta_name        : vd/workspace.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 2.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : Workspace switching on the focused monitor.
-- @desc_detailed    : Slots 1..COUNT_WS_PER_ROLE belong to the current virtual
-- @desc_detailed    : desktop. The slots above that are shared: they hold the
-- @desc_detailed    : same workspace no matter which desktop is active, and are
-- @desc_detailed    : therefore never remembered as a desktop's last view.
--
-- @req_modules      : vd.config, vd.state, vd.query, vd.dispatch, vd.label, vd.render
-- @exports          : switch, cycle, move_window_to, move_window_cycle
-- ==============================================================================

local config   = require("vd.config")
local state    = require("vd.state")
local query    = require("vd.query")
local dispatch = require("vd.dispatch")
local label    = require("vd.label")
local render   = require("vd.render")

local M = {}

-- Forward declarations; both helpers live in the support section below.
local resolve_slot
local slot_from_step

-- ==============================================================================
-- --- Switching ---
-- ==============================================================================

-- --- switch ---
-- @desc_short       : Shows the workspace of slot N on the focused monitor.
-- @usage            : switch(2)
-- @parameter        : number_ws | integer | Slot number, 1..count_slots().
-- @returns          : boolean | false when slot or monitor cannot be resolved.
-- ==============================================================================
function M.switch(number_ws)
    local id_workspace, name_role, id_vd, monitor = resolve_slot(number_ws)

    if not id_workspace then
        return false
    end

    -- Pressing the shared slot while it is already shown goes back to the
    -- desktop's own view. Without this a monitor parked on the shared
    -- workspace would silently stop following any desktop switch.
    if config.is_shared_slot(number_ws) and id_vd
        and monitor.active_workspace
        and monitor.active_workspace.id == id_workspace then
        -- recall_slot never returns a shared slot, so this cannot loop.
        return M.switch(state.recall_slot(id_vd, name_role))
    end

    dispatch.show_workspace(monitor, id_workspace)

    -- Store the slot so a later desktop switch restores this view. Shared slots
    -- are dropped inside remember_slot, they belong to no desktop.
    if id_vd then
        state.remember_slot(id_vd, name_role, number_ws)
        label.apply(id_vd)
    end

    -- Tell the user where they landed; replaces the previous popup so that
    -- scrolling through the slots does not stack them.
    dispatch.notify_transient(render.slot_line(id_vd, name_role, number_ws))

    return true
end

-- --- cycle ---
-- @desc_short       : Moves one slot forward or backward, wrapping around.
-- @usage            : cycle(1) / cycle(-1)
-- @parameter        : step | integer | 1 for forward, -1 for backward.
-- @returns          : boolean | false when the focused monitor has no role.
-- ==============================================================================
function M.cycle(step)
    local number_ws = slot_from_step(step)

    if not number_ws then
        return false
    end

    return M.switch(number_ws)
end

-- ==============================================================================
-- --- Moving Windows ---
-- ==============================================================================

-- --- move_window_to ---
-- @desc_short       : Moves the active window to slot N and follows it.
-- @usage            : move_window_to(3)
-- @parameter        : number_ws | integer | Slot number.
-- @returns          : boolean | false when slot or monitor cannot be resolved.
-- ==============================================================================
function M.move_window_to(number_ws)
    local id_workspace = resolve_slot(number_ws)

    if not id_workspace then
        return false
    end

    dispatch.move_window_to_workspace(id_workspace)
    return M.switch(number_ws)
end

-- --- move_window_cycle ---
-- @desc_short       : Moves the active window one slot forward or backward.
-- @usage            : move_window_cycle(1) / move_window_cycle(-1)
-- @parameter        : step | integer | 1 for forward, -1 for backward.
-- @returns          : boolean | false when the focused monitor has no role.
-- ==============================================================================
function M.move_window_cycle(step)
    local number_ws = slot_from_step(step)

    if not number_ws then
        return false
    end

    return M.move_window_to(number_ws)
end

-- ==============================================================================
-- --- Support Functions ---
-- ==============================================================================

-- --- resolve_slot ---
-- @desc_short       : Turns a slot number into the workspace it addresses.
-- @usage            : resolve_slot(4)
-- @parameter        : number_ws | integer | Slot number.
-- @returns          : integer, string, integer|nil, HL.Monitor | All nil on failure.
-- ==============================================================================
function resolve_slot(number_ws)
    local monitor   = hl.get_active_monitor()
    local name_role = query.role_of_monitor(monitor)

    -- An output without a role is not part of the scheme and stays untouched.
    if not name_role then
        return nil
    end

    local id_vd = query.current_desktop()

    -- Only desktop bound slots need to know which desktop is active.
    if not config.is_shared_slot(number_ws) and not id_vd then
        return nil
    end

    local id_workspace = config.slot_workspace_id(id_vd, name_role, number_ws)
    if not id_workspace then
        return nil
    end

    return id_workspace, name_role, id_vd, monitor
end

-- --- slot_from_step ---
-- @desc_short       : Computes the slot reached by stepping from the current one.
-- @usage            : slot_from_step(1)
-- @parameter        : step | integer | Offset, wrapped into 1..count_slots().
-- @returns          : integer|nil | Target slot, or nil without a usable monitor.
-- ==============================================================================
function slot_from_step(step)
    local monitor   = hl.get_active_monitor()
    local name_role = query.role_of_monitor(monitor)

    if not name_role then
        return nil
    end

    local number_current = 1

    -- Read the live slot instead of the stored one, in case both drifted apart.
    if monitor.active_workspace then
        number_current = config.slot_of_workspace(monitor.active_workspace.id) or 1
    end

    -- Wrapping runs over the desktop bound slots and the shared ones together.
    return ((number_current - 1 + step) % config.count_slots()) + 1
end

return M
