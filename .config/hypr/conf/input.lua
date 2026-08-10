-- ==============================================================================
-- @meta_name        : conf/input.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Keyboard, pointer and per-device input settings.
-- @desc_detailed    : Port of the input / cursor / device blocks of the previous
-- @desc_detailed    : hyprland.conf.
-- ==============================================================================

hl.config({
    input = {
        kb_layout  = "de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        -- 0 keeps the raw device speed; range is -1.0 .. 1.0.
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_hardware_cursors = false,
    },
})

-- ==============================================================================
-- --- Environment ---
-- ==============================================================================

hl.env("XCURSOR_SIZE", "16")
hl.env("HYPRCURSOR_SIZE", "16")

-- ==============================================================================
-- --- Per-Device Settings ---
-- ==============================================================================

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
