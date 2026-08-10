-- ==============================================================================
-- @meta_name        : vd/config.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 2.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : Static configuration and ID arithmetic of the VD engine.
-- @desc_detailed    : Maps physical outputs to roles and converts between a
-- @desc_detailed    : virtual desktop / role / slot triple and the numeric
-- @desc_detailed    : Hyprland workspace ID.
--
-- @exports          : ROLES, OUTPUT_BY_ROLE, COUNT_WS_PER_ROLE, COUNT_WS_SHARED,
-- @exports          : ID_VD_MIN, ID_VD_MAX, ID_VD_HIDDEN, ID_SHARED_BASE,
-- @exports          : role_index, role_of_output, workspace_id,
-- @exports          : shared_workspace_id, slot_workspace_id, decode,
-- @exports          : slot_of_workspace, role_of_workspace, count_slots,
-- @exports          : is_vd_id, is_vd_workspace, is_shared_slot,
-- @exports          : is_shared_workspace, is_hidden
--
-- @notes            : Every monitor owns COUNT_WS_PER_ROLE workspaces that belong
-- @notes            : to one virtual desktop, followed by COUNT_WS_SHARED
-- @notes            : workspaces that are the same on every desktop.
-- @notes            : Workspace IDs stay numeric on purpose: Hyprland workspace
-- @notes            : IDs are integers, and only integers allow the cheap prefix
-- @notes            : arithmetic used to find "all workspaces of desktop NN".
-- ==============================================================================

local M = {}

-- ==============================================================================
-- --- User Configuration ---
-- Adjust these to match the physical monitor setup.
-- ==============================================================================

-- Monitor roles, ordered: the index defines the role digit of a workspace ID
-- (main = 0, left = 1, center = 2, right = 3).
M.ROLES = { "main", "left", "center", "right" }

-- Physical output name for every role.
M.OUTPUT_BY_ROLE = {
    main   = "DP-1",       -- 3840x1600 ultrawide, below the panel row
    left   = "HDMI-A-1",   -- 1920x1080, top left
    center = "HDMI-A-2",   -- 1920x1080, top center
    right  = "DP-2",       -- 1920x1080, top right
}

-- Workspaces per monitor that belong to one virtual desktop (slots 1..N).
M.COUNT_WS_PER_ROLE = 3

-- Workspaces per monitor that are shared by all desktops (slots N+1 ...).
M.COUNT_WS_SHARED = 1

-- Lowest and highest virtual desktop number; both must stay two digits.
M.ID_VD_MIN = 11
M.ID_VD_MAX = 98

-- Desktop reachable only by its own keybind: never cycled, never listed.
M.ID_VD_HIDDEN = 99

-- Border of windows sitting on a shared workspace. Deliberately far away from
-- the normal cyan/green border so a shared slot is recognisable at a glance.
M.BORDER_SHARED_COLOR = { colors = { "rgba(ffaa00ff)", "rgba(ff5500ff)" }, angle = 45 }

-- Border width on shared workspaces; wider than the default of 2.
M.BORDER_SHARED_SIZE = 4

-- First workspace ID of the shared block; it grows by role and shared slot.
-- Deliberately clear of 1..4, which Hyprland hands out to the monitors at
-- startup, and clear of the DDMW range, which begins at 1100.
M.ID_SHARED_BASE = 91

-- ==============================================================================
-- --- Module Internals ---
-- Derived lookup tables, built once at load time.
-- ==============================================================================

-- Reverse lookup role name -> position in M.ROLES (1-based).
local INDEX_BY_ROLE = {}
for index_role, name_role in ipairs(M.ROLES) do
    INDEX_BY_ROLE[name_role] = index_role
end

-- Reverse lookup output name -> role name.
local ROLE_BY_OUTPUT = {}
for name_role, name_output in pairs(M.OUTPUT_BY_ROLE) do
    ROLE_BY_OUTPUT[name_output] = name_role
end

-- Highest ID of the shared block, computed once for the range checks.
local ID_SHARED_MAX = M.ID_SHARED_BASE + (#M.ROLES * M.COUNT_WS_SHARED) - 1

-- ==============================================================================
-- --- Roles ---
-- ==============================================================================

-- --- role_index ---
-- @desc_short       : Returns the 1-based position of a role in M.ROLES.
-- @usage            : role_index("left")
-- @parameter        : name_role | string | Role name.
-- @returns          : integer|nil | Position, or nil for an unknown role.
-- ==============================================================================
function M.role_index(name_role)
    return INDEX_BY_ROLE[name_role]
end

-- --- role_of_output ---
-- @desc_short       : Returns the role a physical output plays.
-- @usage            : role_of_output("DP-1")
-- @parameter        : name_output | string | Hyprland output name.
-- @returns          : string|nil | Role name, or nil if the output has no role.
-- ==============================================================================
function M.role_of_output(name_output)
    return ROLE_BY_OUTPUT[name_output]
end

-- ==============================================================================
-- --- Slots ---
-- A slot is what the user presses: 1..COUNT_WS_PER_ROLE are desktop bound,
-- the following COUNT_WS_SHARED slots are shared across all desktops.
-- ==============================================================================

-- --- count_slots ---
-- @desc_short       : Total number of slots a monitor offers.
-- @usage            : count_slots()
-- @returns          : integer
-- ==============================================================================
function M.count_slots()
    return M.COUNT_WS_PER_ROLE + M.COUNT_WS_SHARED
end

-- --- is_shared_slot ---
-- @desc_short       : Tests whether a slot number addresses a shared workspace.
-- @usage            : is_shared_slot(4)
-- @parameter        : number_ws | integer | Slot number.
-- @returns          : boolean
-- ==============================================================================
function M.is_shared_slot(number_ws)
    return number_ws > M.COUNT_WS_PER_ROLE and number_ws <= M.count_slots()
end

-- --- slot_workspace_id ---
-- @desc_short       : Resolves a slot to its workspace ID, shared or not.
-- @usage            : slot_workspace_id(12, "left", 4)
-- @parameter        : id_vd     | integer | Desktop number; ignored for shared slots.
-- @parameter        : name_role | string  | Role name.
-- @parameter        : number_ws | integer | Slot number.
-- @returns          : integer|nil | Workspace ID, or nil if anything is invalid.
-- ==============================================================================
function M.slot_workspace_id(id_vd, name_role, number_ws)
    -- Shared slots exist once per monitor and know nothing about desktops.
    if M.is_shared_slot(number_ws) then
        return M.shared_workspace_id(name_role, number_ws - M.COUNT_WS_PER_ROLE)
    end

    return M.workspace_id(id_vd, name_role, number_ws)
end

-- ==============================================================================
-- --- Desktop Bound Workspaces (DDMW) ---
-- ==============================================================================

-- --- workspace_id ---
-- @desc_short       : Builds the numeric ID of a desktop bound workspace.
-- @usage            : workspace_id(11, "main", 1) --> 1101
-- @parameter        : id_vd     | integer | Virtual desktop number.
-- @parameter        : name_role | string  | Role name.
-- @parameter        : number_ws | integer | Slot 1..COUNT_WS_PER_ROLE.
-- @returns          : integer|nil | Workspace ID, or nil if any part is invalid.
-- ==============================================================================
function M.workspace_id(id_vd, name_role, number_ws)
    local index_role = INDEX_BY_ROLE[name_role]

    -- Reject anything that would produce an ID outside the DDMW layout.
    if not index_role or not M.is_vd_id(id_vd) then
        return nil
    end
    if number_ws < 1 or number_ws > M.COUNT_WS_PER_ROLE then
        return nil
    end

    -- DDMW: desktop * 100 + role digit * 10 + slot.
    return id_vd * 100 + (index_role - 1) * 10 + number_ws
end

-- --- decode ---
-- @desc_short       : Splits a desktop bound workspace ID into its parts.
-- @usage            : decode(1121) --> 11, "center", 1
-- @parameter        : id_workspace | integer | Numeric Hyprland workspace ID.
-- @returns          : integer, string, integer | Desktop, role, slot — or nil.
-- ==============================================================================
function M.decode(id_workspace)
    -- Guard against special workspaces, which carry negative IDs.
    if type(id_workspace) ~= "number" or id_workspace < 0 then
        return nil
    end

    local id_vd      = math.floor(id_workspace / 100)
    local digit_role = math.floor(id_workspace / 10) % 10
    local number_ws  = id_workspace % 10
    local name_role  = M.ROLES[digit_role + 1]

    -- Only IDs that map back onto a valid triple belong to the DDMW scheme.
    if not M.is_vd_id(id_vd) or not name_role then
        return nil
    end
    if number_ws < 1 or number_ws > M.COUNT_WS_PER_ROLE then
        return nil
    end

    return id_vd, name_role, number_ws
end

-- ==============================================================================
-- --- Shared Workspaces ---
-- ==============================================================================

-- --- shared_workspace_id ---
-- @desc_short       : Builds the ID of a shared workspace of one role.
-- @usage            : shared_workspace_id("left", 1)
-- @parameter        : name_role     | string  | Role name.
-- @parameter        : index_shared  | integer | 1..COUNT_WS_SHARED.
-- @returns          : integer|nil
-- ==============================================================================
function M.shared_workspace_id(name_role, index_shared)
    local index_role = INDEX_BY_ROLE[name_role]

    if not index_role or index_shared < 1 or index_shared > M.COUNT_WS_SHARED then
        return nil
    end

    -- One contiguous block, ordered by role and then by shared slot.
    return M.ID_SHARED_BASE + (index_role - 1) * M.COUNT_WS_SHARED + (index_shared - 1)
end

-- --- is_shared_workspace ---
-- @desc_short       : Tests whether a workspace ID belongs to the shared block.
-- @usage            : is_shared_workspace(3)
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- @returns          : boolean
-- ==============================================================================
function M.is_shared_workspace(id_workspace)
    return type(id_workspace) == "number"
        and id_workspace >= M.ID_SHARED_BASE
        and id_workspace <= ID_SHARED_MAX
end

-- ==============================================================================
-- --- Generic Lookups ---
-- ==============================================================================

-- --- role_of_workspace ---
-- @desc_short       : Returns the role a workspace belongs to, shared or not.
-- @usage            : role_of_workspace(1121)
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- @returns          : string|nil
-- ==============================================================================
function M.role_of_workspace(id_workspace)
    if M.is_shared_workspace(id_workspace) then
        local offset = id_workspace - M.ID_SHARED_BASE
        return M.ROLES[math.floor(offset / M.COUNT_WS_SHARED) + 1]
    end

    local _, name_role = M.decode(id_workspace)
    return name_role
end

-- --- slot_of_workspace ---
-- @desc_short       : Returns the slot number a workspace occupies.
-- @usage            : slot_of_workspace(3) --> 4   (shared slot of "center")
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- @returns          : integer|nil
-- ==============================================================================
function M.slot_of_workspace(id_workspace)
    if M.is_shared_workspace(id_workspace) then
        local offset = id_workspace - M.ID_SHARED_BASE
        return M.COUNT_WS_PER_ROLE + (offset % M.COUNT_WS_SHARED) + 1
    end

    local _, _, number_ws = M.decode(id_workspace)
    return number_ws
end

-- ==============================================================================
-- --- Desktop Numbers ---
-- ==============================================================================

-- --- is_vd_id ---
-- @desc_short       : Tests whether a number is a usable desktop number.
-- @usage            : is_vd_id(11)
-- @parameter        : id_vd | any | Value to test.
-- @returns          : boolean | true for the normal range and for the hidden one.
-- ==============================================================================
function M.is_vd_id(id_vd)
    if type(id_vd) ~= "number" or id_vd ~= math.floor(id_vd) then
        return false
    end

    -- The hidden desktop is a valid target, it is only kept out of listings.
    return (id_vd >= M.ID_VD_MIN and id_vd <= M.ID_VD_MAX) or id_vd == M.ID_VD_HIDDEN
end

-- --- is_hidden ---
-- @desc_short       : Tests whether a desktop number is the hidden desktop.
-- @usage            : is_hidden(99)
-- @parameter        : id_vd | any | Value to test.
-- @returns          : boolean
-- ==============================================================================
function M.is_hidden(id_vd)
    return id_vd == M.ID_VD_HIDDEN
end

-- --- is_vd_workspace ---
-- @desc_short       : Tests whether a workspace ID belongs to the DDMW scheme.
-- @usage            : is_vd_workspace(1101)
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- @returns          : boolean
-- ==============================================================================
function M.is_vd_workspace(id_workspace)
    return M.decode(id_workspace) ~= nil
end

return M
