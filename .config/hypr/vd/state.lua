-- ==============================================================================
-- @meta_name        : vd/state.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : In-memory runtime state of the virtual-desktop engine.
-- @desc_detailed    : Remembers the last used workspace slot per desktop and
-- @desc_detailed    : role, the label of every desktop and the desktop the user
-- @desc_detailed    : is currently on.
--
-- @req_modules      : vd.config
-- @exports          : remember_slot, recall_slot, set_label, get_label,
-- @exports          : known_desktops, forget_desktop, set_current, get_current,
-- @exports          : set_return, get_return
--
-- @notes            : State lives in the Hyprland process, so it dies with the
-- @notes            : session — exactly like the desktops it describes. The old
-- @notes            : bash implementation used files in /tmp for this.
-- ==============================================================================

local config = require("vd.config")

local M = {}

-- ==============================================================================
-- --- Module Internals ---
-- ==============================================================================

-- Last used workspace slot: SLOT_BY_DESKTOP[id_vd][name_role] = number_ws.
local SLOT_BY_DESKTOP = {}

-- Free-form label per desktop: LABEL_BY_DESKTOP[id_vd] = "gaming".
local LABEL_BY_DESKTOP = {}

-- Desktop the user is currently on; nil until the first switch happened.
local ID_CURRENT_DESKTOP = nil

-- Desktop to return to when leaving the hidden desktop again.
local ID_RETURN_DESKTOP = nil

-- ==============================================================================
-- --- Workspace Memory ---
-- ==============================================================================

-- --- remember_slot ---
-- @desc_short       : Stores which workspace slot a role last showed.
-- @usage            : remember_slot(11, "main", 3)
-- @parameter        : id_vd     | integer | Virtual desktop number.
-- @parameter        : name_role | string  | Role name.
-- @parameter        : number_ws | integer | Workspace slot (1..4).
-- ==============================================================================
function M.remember_slot(id_vd, name_role, number_ws)
    -- Shared slots belong to no desktop; remembering one would make a later
    -- switch land on the shared workspace instead of the desktop's own view.
    if config.is_shared_slot(number_ws) then
        return
    end

    -- Create the per-desktop table lazily on first use.
    if not SLOT_BY_DESKTOP[id_vd] then
        SLOT_BY_DESKTOP[id_vd] = {}
    end

    SLOT_BY_DESKTOP[id_vd][name_role] = number_ws
end

-- --- recall_slot ---
-- @desc_short       : Returns the slot a role last showed on a desktop.
-- @usage            : recall_slot(11, "main")
-- @parameter        : id_vd     | integer | Virtual desktop number.
-- @parameter        : name_role | string  | Role name.
-- @returns          : integer | Remembered slot, or 1 when nothing is stored.
-- ==============================================================================
function M.recall_slot(id_vd, name_role)
    local slots_of_desktop = SLOT_BY_DESKTOP[id_vd]

    -- Fall back to the first slot for desktops that were never visited.
    if not slots_of_desktop or not slots_of_desktop[name_role] then
        return 1
    end

    return slots_of_desktop[name_role]
end

-- ==============================================================================
-- --- Labels ---
-- ==============================================================================

-- --- set_label ---
-- @desc_short       : Attaches a free-form label to a virtual desktop.
-- @usage            : set_label(11, "gaming")
-- @parameter        : id_vd      | integer     | Virtual desktop number.
-- @parameter        : name_label | string|nil  | Label, or nil to clear it.
-- ==============================================================================
function M.set_label(id_vd, name_label)
    -- Treat an empty string like "no label" so callers can pass through input.
    if name_label == "" then
        name_label = nil
    end

    LABEL_BY_DESKTOP[id_vd] = name_label
end

-- --- get_label ---
-- @desc_short       : Returns the label of a virtual desktop.
-- @usage            : get_label(11)
-- @parameter        : id_vd | integer | Virtual desktop number.
-- @returns          : string|nil
-- ==============================================================================
function M.get_label(id_vd)
    return LABEL_BY_DESKTOP[id_vd]
end

-- ==============================================================================
-- --- Lifecycle ---
-- ==============================================================================

-- --- known_desktops ---
-- @desc_short       : Lists every desktop the engine currently holds state for.
-- @usage            : known_desktops()
-- @returns          : integer[] | Unsorted desktop numbers.
-- ==============================================================================
function M.known_desktops()
    local is_known = {}

    -- A desktop is known through its remembered slots or through its label.
    for id_vd in pairs(SLOT_BY_DESKTOP) do
        is_known[id_vd] = true
    end
    for id_vd in pairs(LABEL_BY_DESKTOP) do
        is_known[id_vd] = true
    end

    local ids_known = {}
    for id_vd in pairs(is_known) do
        ids_known[#ids_known + 1] = id_vd
    end

    return ids_known
end

-- --- forget_desktop ---
-- @desc_short       : Drops all state of a desktop that no longer exists.
-- @usage            : forget_desktop(11)
-- @parameter        : id_vd | integer | Virtual desktop number.
-- ==============================================================================
function M.forget_desktop(id_vd)
    SLOT_BY_DESKTOP[id_vd]  = nil
    LABEL_BY_DESKTOP[id_vd] = nil

    -- Never keep a pointer to a desktop that was just torn down.
    if ID_CURRENT_DESKTOP == id_vd then
        ID_CURRENT_DESKTOP = nil
    end
end

-- --- set_current ---
-- @desc_short       : Records the desktop the user is on.
-- @usage            : set_current(11)
-- @parameter        : id_vd | integer | Virtual desktop number.
-- ==============================================================================
function M.set_current(id_vd)
    -- Ignore anything outside the scheme so a stray event cannot corrupt state.
    if config.is_vd_id(id_vd) then
        ID_CURRENT_DESKTOP = id_vd
    end
end

-- --- get_current ---
-- @desc_short       : Returns the last recorded current desktop.
-- @usage            : get_current()
-- @returns          : integer|nil
-- ==============================================================================
function M.get_current()
    return ID_CURRENT_DESKTOP
end

-- --- set_return ---
-- @desc_short       : Stores the desktop to come back to from the hidden one.
-- @usage            : set_return(14)
-- @parameter        : id_vd | integer|nil | Desktop number.
-- ==============================================================================
function M.set_return(id_vd)
    -- Returning to the hidden desktop itself would trap the toggle.
    if config.is_vd_id(id_vd) and not config.is_hidden(id_vd) then
        ID_RETURN_DESKTOP = id_vd
    end
end

-- --- get_return ---
-- @desc_short       : Returns the desktop stored by set_return.
-- @usage            : get_return()
-- @returns          : integer|nil
-- ==============================================================================
function M.get_return()
    return ID_RETURN_DESKTOP
end

return M
