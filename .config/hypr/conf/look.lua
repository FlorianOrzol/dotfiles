-- ==============================================================================
-- @meta_name        : conf/look.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Appearance, layouts and general compositor behaviour.
-- @desc_detailed    : Carries over the look of the previous hyprland.conf and
-- @desc_detailed    : adds the bind options the virtual-desktop engine relies on.
--
-- @notes            : binds.window_direction_monitor_fallback replaces the old
-- @notes            : scripts/move_window_to_monitor_dir.sh helper: Hyprland
-- @notes            : itself pushes a window to the neighbouring monitor when it
-- @notes            : cannot move any further inside the current layout.
-- ==============================================================================

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status  = "master",
        orientation = "right",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },

    binds = {
        -- Lets a directional window move cross monitor borders on its own.
        window_direction_monitor_fallback = true,
    },
})

-- ==============================================================================
-- --- Group / Tab Appearance ---
-- Windows grouped with SUPER + G are drawn as browser-like tabs.
-- ==============================================================================

hl.config({
    group = {
        col = {
            border_active   = "rgba(89b4faff)",
            border_inactive = "rgba(313244ff)",
        },

        groupbar = {
            enabled       = true,
            font_family   = "JetBrains Mono",
            font_size     = 11,
            height        = 20,
            render_titles = true,
            gradients     = false,
            text_color    = "rgba(ffffffff)",

            col = {
                active   = "rgba(89b4faff)",
                inactive = "rgba(313244ff)",
            },
        },
    },
})
