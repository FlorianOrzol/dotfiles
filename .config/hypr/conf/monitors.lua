-- ==============================================================================
-- @meta_name        : conf/monitors.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Physical monitor layout.
-- @desc_detailed    : Positions form one row of three 1080p panels above a
-- @desc_detailed    : 3840x1600 ultrawide. The role each output plays for the
-- @desc_detailed    : virtual desktops is configured in vd/config.lua.
--
-- @notes            : All four outputs take part in the virtual desktops. Each
-- @notes            : of them additionally owns a shared workspace that stays
-- @notes            : the same on every desktop — see vd/config.lua.
-- ==============================================================================

-- Ultrawide below the panel row, primary work area (role: main).
hl.monitor({
    output   = "DP-1",
    mode     = "3840x1600",
    position = "0x1080",
    scale    = 1,
})

-- Top left panel (role: left).
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080",
    position = "0x0",
    scale    = 1,
})

-- Top center panel (role: center).
hl.monitor({
    output   = "HDMI-A-2",
    mode     = "1920x1080",
    position = "1920x0",
    scale    = 1,
})

-- Top right panel (role: right).
hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080",
    position = "3840x0",
    scale    = 1,
})

-- Catch-all so an unexpected output still comes up with sane settings.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
