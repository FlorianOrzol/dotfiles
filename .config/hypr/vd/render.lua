-- ==============================================================================
-- @meta_name        : vd/render.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : Turns the engine state into readable text.
-- @desc_detailed    : Single place that decides how desktops and slots are
-- @desc_detailed    : written out, used by the on-screen notification and by
-- @desc_detailed    : the status file that external displays read.
--
-- @req_modules      : vd.config, vd.state, vd.query
-- @exports          : desktop_name, slot_line, desktop_line, slot_marks,
-- @exports          : list, status
--
-- @notes            : "S" marks a monitor sitting on its shared workspace; it
-- @notes            : follows no desktop switch while it does.
-- ==============================================================================

local config = require("vd.config")
local state  = require("vd.state")
local query  = require("vd.query")

local M = {}

-- ==============================================================================
-- --- User Configuration ---
-- Wording of the on-screen feedback.
-- ==============================================================================

-- Shown instead of the slot number when the slot is a shared one.
local NAME_SLOT_SHARED = "statisch"

-- Separator between the parts of a one-line message.
local SEPARATOR_LINE = "  ·  "

-- ==============================================================================
-- --- One-Line Feedback ---
-- ==============================================================================

-- --- desktop_name ---
-- @desc_short       : Renders "VD 12 gaming", or "VD 12" without a label.
-- @usage            : desktop_name(12)
-- @parameter        : id_vd | integer|nil | Virtual desktop number.
-- @returns          : string
-- ==============================================================================
function M.desktop_name(id_vd)
    -- Without a known desktop the caller still needs something printable.
    if not id_vd then
        return "VD -"
    end

    local name_label = state.get_label(id_vd)
    return "VD " .. id_vd .. (name_label and (" " .. name_label) or "")
end

-- --- slot_line ---
-- @desc_short       : Feedback line for a slot switch.
-- @usage            : slot_line(12, "main", 4)
-- @parameter        : id_vd     | integer|nil | Virtual desktop number.
-- @parameter        : name_role | string      | Role of the switched monitor.
-- @parameter        : number_ws | integer     | Slot that is now shown.
-- @returns          : string | "VD 12 gaming  ·  main  ·  WS 2"
-- ==============================================================================
function M.slot_line(id_vd, name_role, number_ws)
    -- Shared slots carry no number the user could relate to a desktop.
    local name_slot = config.is_shared_slot(number_ws)
        and NAME_SLOT_SHARED
        or tostring(number_ws)

    return M.desktop_name(id_vd) .. SEPARATOR_LINE .. name_role
        .. SEPARATOR_LINE .. "WS " .. name_slot
end

-- --- desktop_line ---
-- @desc_short       : Feedback line for a desktop switch.
-- @usage            : desktop_line(12, { "main" })
-- @parameter        : id_vd       | integer  | Virtual desktop number.
-- @parameter        : roles_stuck | string[] | Roles left on their shared slot.
-- @returns          : string | "VD 12 gaming  ·  statisch: main"
-- ==============================================================================
function M.desktop_line(id_vd, roles_stuck)
    local text = M.desktop_name(id_vd)

    -- Name the monitors that did not follow; otherwise the switch looks broken.
    if roles_stuck and #roles_stuck > 0 then
        text = text .. SEPARATOR_LINE .. NAME_SLOT_SHARED .. ": " .. table.concat(roles_stuck, ", ")
    end

    return text
end

-- ==============================================================================
-- --- Public API ---
-- ==============================================================================

-- --- slot_marks ---
-- @desc_short       : Renders the slot each role shows, or would show.
-- @usage            : slot_marks(12, false)
-- @parameter        : id_vd      | integer | Virtual desktop number.
-- @parameter        : is_current | boolean | true to read the live monitors.
-- @returns          : string | "main:2 left:1 center:S right:1"
-- ==============================================================================
function M.slot_marks(id_vd, is_current)
    local parts = {}

    for _, name_role in ipairs(config.ROLES) do
        local monitor = query.monitor_of_role(name_role)
        local mark

        -- For the visible desktop the monitors are the truth; "S" marks a
        -- shared workspace, which belongs to no desktop at all.
        if is_current and query.shows_shared(monitor) then
            mark = "S"
        elseif is_current and monitor and monitor.active_workspace then
            mark = tostring(config.slot_of_workspace(monitor.active_workspace.id) or "-")
        else
            mark = tostring(state.recall_slot(id_vd, name_role))
        end

        parts[#parts + 1] = name_role .. ":" .. mark
    end

    return table.concat(parts, " ")
end

-- --- list ---
-- @desc_short       : Renders all active desktops, one line each.
-- @usage            : list()
-- @returns          : string | "*12 gaming     main:2 left:1 center:S right:1"
-- ==============================================================================
function M.list()
    local lines      = {}
    local id_current = query.current_desktop()

    for _, id_vd in ipairs(query.active_desktops()) do
        local marker = (id_vd == id_current) and "*" or " "
        local name   = state.get_label(id_vd) or ""

        lines[#lines + 1] = string.format("%s%d %-10s %s",
            marker, id_vd, name, M.slot_marks(id_vd, id_vd == id_current))
    end

    return table.concat(lines, "\n")
end

-- --- status ---
-- @desc_short       : Renders the compact status block for external displays.
-- @usage            : status()
-- @returns          : string | headline, slot line, then one line per desktop.
-- ==============================================================================
function M.status()
    local id_current = query.current_desktop()

    -- Without a current desktop there is nothing meaningful to report.
    if not id_current then
        return "VD -\n"
    end

    local name_label = state.get_label(id_current)
    local headline   = "VD " .. id_current .. (name_label and (" " .. name_label) or "")

    return headline .. "\n"
        .. M.slot_marks(id_current, true) .. "\n"
        .. M.list() .. "\n"
end

return M
