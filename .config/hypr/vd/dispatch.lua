-- ==============================================================================
-- @meta_name        : vd/dispatch.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Thin wrappers around the Hyprland dispatchers used by the
-- @desc_short       : virtual-desktop engine.
-- @desc_detailed    : Every call that changes compositor state goes through this
-- @desc_detailed    : module, so the rest of the engine stays free of hl.* calls
-- @desc_detailed    : and API quirks are fixed in exactly one place.
--
-- @exports          : show_workspace, focus_monitor, focus_workspace,
-- @exports          : move_window_to_workspace, rename_workspace, notify
--
-- @notes            : show_workspace prefers HL.Monitor:set_workspace because it
-- @notes            : changes a monitor without stealing focus. That method is
-- @notes            : new in the Lua config manager, hence the guarded fallback.
-- ==============================================================================

local M = {}

-- ==============================================================================
-- --- Module Internals ---
-- ==============================================================================

-- Duration of engine notifications in milliseconds.
local TIMEOUT_NOTIFICATION = 1500

-- Duration of the transient switch feedback; shorter, it appears constantly.
local TIMEOUT_TRANSIENT = 1200

-- Handle of the last transient notification, so the next one can replace it.
local notification_transient = nil

-- ==============================================================================
-- --- Workspace and Monitor Switching ---
-- ==============================================================================

-- --- show_workspace ---
-- @desc_short       : Makes a workspace the active one on a specific monitor.
-- @usage            : show_workspace(monitor, 1101)
-- @parameter        : monitor      | HL.Monitor | Target monitor object.
-- @parameter        : id_workspace | integer    | Numeric workspace ID.
-- @returns          : boolean | true when the monitor was switched.
-- ==============================================================================
function M.show_workspace(monitor, id_workspace)
    if not monitor then
        return false
    end

    -- Preferred path: switch the monitor in place, leaving the focus untouched.
    pcall(function()
        monitor:set_workspace(id_workspace)
    end)

    -- Accept the result only if the monitor really shows the wanted workspace;
    -- that also covers builds where set_workspace ignores unknown IDs.
    local workspace_now = monitor.active_workspace
    if workspace_now and workspace_now.id == id_workspace then
        return true
    end

    -- Fallback: focus the monitor first, then the workspace, so a workspace
    -- that has to be created lands on the intended monitor.
    M.focus_monitor(monitor)
    M.focus_workspace(id_workspace)
    return true
end

-- --- focus_monitor ---
-- @desc_short       : Moves the input focus to a monitor.
-- @usage            : focus_monitor(monitor)
-- @parameter        : monitor | HL.Monitor | Target monitor object.
-- ==============================================================================
function M.focus_monitor(monitor)
    if not monitor then
        return
    end

    hl.dispatch(hl.dsp.focus({ monitor = monitor }))
end

-- --- focus_workspace ---
-- @desc_short       : Focuses a workspace on the currently focused monitor.
-- @usage            : focus_workspace(1101)
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- ==============================================================================
function M.focus_workspace(id_workspace)
    hl.dispatch(hl.dsp.focus({ workspace = id_workspace }))
end

-- ==============================================================================
-- --- Window and Naming Actions ---
-- ==============================================================================

-- --- move_window_to_workspace ---
-- @desc_short       : Moves the active window to a workspace, keeping focus.
-- @usage            : move_window_to_workspace(1101)
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- ==============================================================================
function M.move_window_to_workspace(id_workspace)
    -- Nothing to carry along when no window is focused.
    if not hl.get_active_window() then
        return
    end

    hl.dispatch(hl.dsp.window.move({ workspace = id_workspace }))
end

-- --- rename_workspace ---
-- @desc_short       : Sets the display name of an existing workspace.
-- @usage            : rename_workspace(1101, "11 gaming . main 1")
-- @parameter        : id_workspace | integer | Numeric workspace ID.
-- @parameter        : name_display | string  | New display name.
-- ==============================================================================
function M.rename_workspace(id_workspace, name_display)
    hl.dispatch(hl.dsp.workspace.rename({ workspace = id_workspace, name = name_display }))
end

-- --- notify ---
-- @desc_short       : Shows an on-screen message.
-- @usage            : notify("desktop 11 . gaming") / notify(text, 5000)
-- @parameter        : text     | string      | Message to display.
-- @parameter        : duration | integer|nil | Milliseconds; default 1500.
-- ==============================================================================
function M.notify(text, duration)
    -- On-screen output is the only channel that reaches the user: there is no
    -- status bar, and hyprctl eval answers "ok" instead of returning values.
    hl.notification.create({ text = text, duration = duration or TIMEOUT_NOTIFICATION })
end

-- --- notify_transient ---
-- @desc_short       : Shows a message that replaces the previous transient one.
-- @usage            : notify_transient("VD 12 . main . WS 2")
-- @parameter        : text | string | Message to display.
-- @notes            : Used for switch feedback. Scrolling through slots would
-- @notes            : otherwise stack a popup per wheel step.
-- ==============================================================================
function M.notify_transient(text)
    -- Take the previous popup down first; it may already have expired, which
    -- is why the call is guarded rather than assumed to succeed.
    if notification_transient then
        pcall(function()
            if notification_transient:is_alive() then
                notification_transient:dismiss()
            end
        end)
    end

    notification_transient = hl.notification.create({
        text     = text,
        duration = TIMEOUT_TRANSIENT,
    })
end

return M
