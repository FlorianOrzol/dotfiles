-- ==============================================================================
-- @meta_name        : conf/rules.lua
-- @meta_author      : Florian Orzol
-- @meta_version     : 1.0.0
-- @meta_date        : 2026-08-09
--
-- @desc_short       : Window rules and the shared workspaces of every monitor.
-- @desc_detailed    : The scratchpad rules replace the ones from the previous
-- @desc_detailed    : hyprland.conf, which used a "match:class ..." syntax that
-- @desc_detailed    : Hyprland does not know and therefore silently ignored.
--
-- @req_modules      : vd.config
-- ==============================================================================

local config = require("vd.config")

-- ==============================================================================
-- --- Shared Workspaces ---
-- One per monitor (or COUNT_WS_SHARED per monitor), pinned to their output and
-- persistent: they exist on every virtual desktop and must survive while empty.
-- Desktop bound workspaces get no rule at all — they have to vanish when empty,
-- because that is what retires a virtual desktop.
-- ==============================================================================

for _, name_role in ipairs(config.ROLES) do
    for index_shared = 1, config.COUNT_WS_SHARED do
        local id_workspace = config.shared_workspace_id(name_role, index_shared)

        -- Append the index only when there is more than one shared slot.
        local name_display = "shared · " .. name_role
        if config.COUNT_WS_SHARED > 1 then
            name_display = name_display .. " " .. index_shared
        end

        hl.workspace_rule({
            workspace    = tostring(id_workspace),
            monitor      = config.OUTPUT_BY_ROLE[name_role],
            persistent   = true,
            default_name = name_display,
        })

        -- Windows on a shared workspace carry a distinct border, so it is
        -- obvious at a glance that this monitor is not following the desktop.
        hl.window_rule({
            name  = "shared-border-" .. id_workspace,
            match = { workspace = tostring(id_workspace) },

            border_color = config.BORDER_SHARED_COLOR,
            border_size  = config.BORDER_SHARED_SIZE,
        })
    end
end

-- ==============================================================================
-- --- Window Rules ---
-- ==============================================================================

-- Apps should not be able to maximize themselves.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Known XWayland drag-and-drop workaround from the upstream example config.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Drop-down terminal started with --class scratchpad_terminal.
hl.window_rule({
    name  = "scratchpad-terminal",
    match = { class = "^(scratchpad_terminal)$" },

    float   = true,
    pin     = true,
    move    = "0 0",
    size    = "80% 60%",
    opacity = 0.8,
})
