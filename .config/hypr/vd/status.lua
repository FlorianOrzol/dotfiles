-- ==============================================================================
-- @meta_name        : vd/status.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-10
--
-- @desc_short       : Publishes the engine state as a plain text file.
-- @desc_detailed    : Written whenever something changes, so a display such as
-- @desc_detailed    : conky, eww or a shell prompt only has to read a file
-- @desc_detailed    : instead of forking hyprctl and jq on a timer.
--
-- @req_modules      : vd.render
-- @exports          : FILE_STATUS, write
--
-- @notes            : Written to a temporary file and renamed afterwards, so a
-- @notes            : reader never catches a half-written file.
-- @notes            : The Lua io library is available inside the Hyprland config
-- @notes            : state — verified on 2026-08-10.
-- ==============================================================================

local render = require("vd.render")

local M = {}

-- ==============================================================================
-- --- User Configuration ---
-- ==============================================================================

-- Where the status text is published. Readers should watch this path.
M.FILE_STATUS = os.getenv("HOME") .. "/.cache/vd_status"

-- ==============================================================================
-- --- Module Internals ---
-- ==============================================================================

-- Last published text; used to skip writes that would change nothing.
local text_published = nil

-- ==============================================================================
-- --- Public API ---
-- ==============================================================================

-- --- write ---
-- @desc_short       : Publishes the current state, if it changed.
-- @usage            : write()
-- @returns          : boolean | true when the file was rewritten.
-- ==============================================================================
function M.write()
    local text = render.status()

    -- Workspace events fire in bursts during a desktop switch; only the last
    -- one actually changes the text.
    if text == text_published then
        return false
    end

    -- Derived on every call, never cached: the temporary file has to sit next
    -- to the target, otherwise the rename below crosses a filesystem and fails.
    local file_temp   = M.FILE_STATUS .. ".tmp"
    local file_handle = io.open(file_temp, "w")

    -- A missing directory is the likely cause; fail quietly rather than taking
    -- the keybind down with an error.
    if not file_handle then
        return false
    end

    file_handle:write(text)
    file_handle:close()

    -- Rename is atomic: a reader sees either the old or the new file, never
    -- a partial one.
    os.rename(file_temp, M.FILE_STATUS)

    text_published = text
    return true
end

return M
