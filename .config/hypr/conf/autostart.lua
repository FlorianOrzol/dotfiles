-- ==============================================================================
-- @meta_name        : conf/autostart.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Everything that has to happen once the session is up.
-- @desc_detailed    : Replaces the exec-once lines of the previous
-- @desc_detailed    : hyprland.conf. The virtual-desktop engine is initialised
-- @desc_detailed    : here instead of by an external script.
--
-- @req_modules      : vd
-- ==============================================================================

local vd = require("vd")

-- ==============================================================================
-- --- User Configuration ---
-- ==============================================================================

-- Working directory and command of the Claude Code session started at login.
local PATH_CLAUDE_PROJECT = "/home/florian/Dokumente/manuals"
local CMD_CLAUDE          = "/home/florian/.local/bin/claude --remote-control manuals"

-- ==============================================================================
-- --- Startup Hook ---
-- ==============================================================================

hl.on("hyprland.start", function()
    -- Build the first virtual desktop before anything can open a window.
    vd.setup()

    -- Claude Code in the manuals directory, reachable via remote control.
	-- hl.exec_cmd("kitty --directory " .. PATH_CLAUDE_PROJECT .. " " .. CMD_CLAUDE)
end)
