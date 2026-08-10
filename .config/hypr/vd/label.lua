-- ==============================================================================
-- @meta_name        : vd/label.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Turns virtual desktop labels into workspace display names.
-- @desc_detailed    : A desktop keeps its numeric identity; the label is only a
-- @desc_detailed    : display name written onto its workspaces, so status bars
-- @desc_detailed    : and window switchers show "12 gaming . main 1".
--
-- @req_modules      : vd.config, vd.state, vd.query, vd.dispatch
-- @exports          : display_name, apply, set
--
-- @notes            : Renaming never changes a workspace ID, so all ID
-- @notes            : arithmetic in vd.config keeps working unchanged.
-- ==============================================================================

local config   = require("vd.config")
local state    = require("vd.state")
local query    = require("vd.query")
local dispatch = require("vd.dispatch")

local M = {}

-- ==============================================================================
-- --- Module Internals ---
-- ==============================================================================

-- Separator between the desktop part and the monitor part of a display name.
local SEPARATOR = " · "

-- ==============================================================================
-- --- Public API ---
-- ==============================================================================

-- --- display_name ---
-- @desc_short       : Builds the display name of a single workspace.
-- @usage            : display_name(12, "main", 1) --> "12 gaming . main 1"
-- @parameter        : id_vd     | integer | Virtual desktop number.
-- @parameter        : name_role | string  | Role name.
-- @parameter        : number_ws | integer | Workspace slot.
-- @returns          : string
-- ==============================================================================
function M.display_name(id_vd, name_role, number_ws)
    local name_label = state.get_label(id_vd)
    local part_desktop = tostring(id_vd)

    -- Only labelled desktops carry their name in the workspace title.
    if name_label then
        part_desktop = part_desktop .. " " .. name_label
    end

    return part_desktop .. SEPARATOR .. name_role .. " " .. number_ws
end

-- --- apply ---
-- @desc_short       : Renames every existing workspace of a desktop.
-- @usage            : apply(12)
-- @parameter        : id_vd | integer | Virtual desktop number.
-- ==============================================================================
function M.apply(id_vd)
    for _, workspace in ipairs(query.workspaces_of_desktop(id_vd)) do
        local _, name_role, number_ws = config.decode(workspace.id)
        local name_wanted = M.display_name(id_vd, name_role, number_ws)

        -- Skip workspaces that already carry the correct name to avoid
        -- pointless dispatches and the events they would trigger.
        if workspace.name ~= name_wanted then
            dispatch.rename_workspace(workspace.id, name_wanted)
        end
    end
end

-- --- set ---
-- @desc_short       : Assigns a label to a desktop and refreshes its workspaces.
-- @usage            : set(12, "gaming")
-- @parameter        : id_vd      | integer    | Virtual desktop number.
-- @parameter        : name_label | string|nil | Label, or nil to remove it.
-- ==============================================================================
function M.set(id_vd, name_label)
    if not config.is_vd_id(id_vd) then
        return
    end

    state.set_label(id_vd, name_label)
    M.apply(id_vd)
end

return M
